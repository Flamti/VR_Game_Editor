extends RefCounted
class_name ProbeHwStat

## Аппаратные счётчики GPU и CPU через sysfs.
##
## Зачем: гипотезы «GPU разогнался на 120 Гц» и «начался троттлинг» до сих пор
## проверялись косвенно — через время кадра. Клок читается напрямую, и это
## превращает догадку в число.
##
## Пути проверены на устройстве до написания прибора: `gpuclk` читается из
## `adb shell`, лестница частот — 10 ступеней 690…285 МГц, `/sys/class/thermal/`
## закрыт правами. Температур не будет, и притворяться, что они есть, нельзя.
##
## **На Android изнутри приложения это НЕ работает, и причина установлена.**
## Godot отдаёт `ACCESS_FILESYSTEM` классу `FileAccessFilesystemJAndroid`
## (`platform/android/os_android.cpp:121`) — то есть абсолютные пути идут через
## Java-слой, а не через `FileAccessUnix`. `/sys/...` так не открыть в принципе,
## сколько бы прав ни было.
##
## Отдельная ошибка, которую стоит помнить: доказательством доступности прежде
## считалось `adb shell run-as <пакет> cat ...`. Это НЕ доказательство —
## `run-as` работает в домене `runas_app`, а приложение в своём; проверено
## через `/proc/self/attr/current`. Домен приложения так и остался непроверен.
##
## Рабочий путь на сегодня — сэмплировать клок с хоста параллельно прогону
## (`tools/gpu_sampler.sh`) и сводить по времени. Прибор при этом обязан честно
## показывать UNKNOWN, а не молчать.

# preload, а не опора на class_name: глобальный кэш классов может быть ещё не
# построен на первом импорте (та же причина, что в probe_main.gd).
const ProbeReport := preload("res://probe_report.gd")

const KGSL := "/sys/class/kgsl/kgsl-3d0/"
const P_CLOCK := KGSL + "gpuclk"
const P_STATS := KGSL + "gpu_clock_stats"
const P_AVAILABLE := KGSL + "gpu_available_frequencies"
const P_BUSY := KGSL + "gpu_busy_percentage"
const P_MODEL := KGSL + "gpu_model"
const P_CPU0 := "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"

## Заведомо несуществующий путь под тем же каталогом. Фальсификатор: если
## чтение отсюда вернёт не «не прочитать», прибор не различает отсутствие
## данных и данные, и всем остальным его числам верить нельзя (§2.3).
const P_NOWHERE := KGSL + "vrge_no_such_counter"


## Возвращает содержимое файла или null. Именно null, а не "" — пустой файл и
## недоступный файл это разные вещи.
static func read_text(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var t := f.get_as_text()
	f.close()
	return t


static func read_int(path: String) -> int:
	var t = read_text(path)
	if t == null:
		return -1
	var s := String(t).strip_edges()
	return s.to_int() if s.is_valid_int() else -1


## Мгновенная частота GPU в Гц; -1 — «спросить не удалось».
static func gpu_clock_hz() -> int:
	return read_int(P_CLOCK)


static func cpu0_khz() -> int:
	return read_int(P_CPU0)


static func gpu_model() -> String:
	var t = read_text(P_MODEL)
	return "неизвестно" if t == null else String(t).strip_edges()


## Загруженность GPU в процентах; NAN — не прочитать. Формат файла — "5 %".
static func gpu_busy_percent() -> float:
	var t = read_text(P_BUSY)
	if t == null:
		return NAN
	var s := String(t).strip_edges().replace("%", "").strip_edges()
	return s.to_float() if s.is_valid_float() else NAN


## Лестница доступных частот GPU, Гц, в том порядке, в каком её даёт ядро.
## Порядок важен: им индексируется gpu_clock_stats.
static func available_hz() -> PackedInt64Array:
	var out := PackedInt64Array()
	var t = read_text(P_AVAILABLE)
	if t == null:
		return out
	for tok in String(t).strip_edges().split(" ", false):
		var s := tok.strip_edges()
		if s.is_valid_int():
			out.append(s.to_int())
	return out


## Резиденция по ступеням частоты: по счётчику на каждую частоту из лестницы.
##
## Единица измерения ядром НЕ документирована и с устройства не спрашивается.
## Поэтому наружу отдаются не абсолютные значения, а ДОЛИ окна — они от единицы
## не зависят. Времяподобность самой шкалы проверяет is_time_like() ниже.
static func clock_stats() -> PackedInt64Array:
	var out := PackedInt64Array()
	var t = read_text(P_STATS)
	if t == null:
		return out
	for tok in String(t).strip_edges().split(" ", false):
		var s := tok.strip_edges()
		if s.is_valid_int():
			out.append(s.to_int())
	return out


## Разность двух снимков резиденции. Отрицательные значения (переполнение или
## сброс счётчика) обнуляются, но их наличие возвращается флагом.
static func residency_delta(before: PackedInt64Array, after: PackedInt64Array) -> Dictionary:
	var d := {"delta": PackedInt64Array(), "sum": 0, "negative": false, "ok": false}
	if before.is_empty() or before.size() != after.size():
		return d
	var delta := PackedInt64Array()
	var total := 0
	for i in before.size():
		var v: int = after[i] - before[i]
		if v < 0:
			d["negative"] = true
			v = 0
		delta.append(v)
		total += v
	d["delta"] = delta
	d["sum"] = total
	d["ok"] = true
	return d


## Времяподобна ли шкала счётчика: сумма дельт, делённая на стенное время окна,
## обязана быть похожа на один из обычных множителей (1/мс, мкс/с, нс/с).
##
## Без этой проверки доли окна были бы враньём: если счётчик считает ПЕРЕХОДЫ,
## а не время, «85% окна на 690 МГц» не значит ничего.
static func time_like_factor(sum_delta: int, wall_ms: float) -> Dictionary:
	var out := {"per_ms": NAN, "unit": "неизвестна", "plausible": false}
	if wall_ms <= 0.0 or sum_delta <= 0:
		return out
	var per_ms := float(sum_delta) / wall_ms
	out["per_ms"] = per_ms
	# Допуск втрое: DVFS опрашивается не непрерывно, точного совпадения не ждём.
	for cand in [[1.0, "мс"], [1000.0, "мкс"], [1000000.0, "нс"]]:
		var f: float = cand[0]
		if per_ms > f / 3.0 and per_ms < f * 3.0:
			out["unit"] = cand[1]
			out["plausible"] = true
			break
	return out


## Доли окна по ступеням, в процентах. Возвращает массив той же длины, что
## лестница частот. Осмысленно только при plausible == true.
static func residency_share(delta: PackedInt64Array, total: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if total <= 0:
		return out
	for v in delta:
		out.append(float(v) / float(total) * 100.0)
	return out


## Средневзвешенная частота за окно, Гц. Одно число вместо десяти — им удобно
## сравнивать ступени матрицы. NAN, если шкала не времяподобна.
static func weighted_hz(delta: PackedInt64Array, hz: PackedInt64Array, total: int) -> float:
	if total <= 0 or delta.size() != hz.size() or delta.is_empty():
		return NAN
	var acc := 0.0
	for i in delta.size():
		acc += float(hz[i]) * float(delta[i])
	return acc / float(total)


## Строка «сколько времени на каких частотах» — только заметные ступени.
static func residency_brief(delta: PackedInt64Array, hz: PackedInt64Array, total: int) -> String:
	var share := residency_share(delta, total)
	if share.is_empty() or share.size() != hz.size():
		return "резиденция недоступна"
	var parts: Array[String] = []
	for i in share.size():
		if share[i] >= 1.0:
			parts.append("%d МГц %.0f%%" % [int(hz[i] / 1000000), share[i]])
	return ", ".join(parts) if not parts.is_empty() else "ни одна ступень не набрала 1%"


func expected_checks() -> int:
	# доступность 1, контроль лестницы 1, длины совпали 1, фальсификатор 1
	return 4


## Статические проверки прибора: делаются один раз, до измерений. Проверка
## живости счётчика требует нагрузки и живёт в фазе матрицы.
func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- H. Аппаратные счётчики ---")

	var clock := gpu_clock_hz()
	var readable := clock > 0
	if readable:
		r.pass_("sysfs: GPU %s, клок %d МГц, CPU0 %d МГц, загрузка %s" % [
				gpu_model(), clock / 1000000, cpu0_khz() / 1000,
				("%.0f%%" % gpu_busy_percent()) if not is_nan(gpu_busy_percent()) else "неизвестна"])
	else:
		# Не отказ железа, а слепота прибора: разделять обязательно.
		r.unkn("sysfs: %s не открыть. На Android абсолютные пути идут через Java-слой (os_android.cpp:121), а не через FileAccessUnix — клок берётся с хоста, tools/gpu_sampler.sh" % P_CLOCK)

	var hz := available_hz()
	if hz.is_empty():
		r.unkn("лестница частот GPU: не прочитать")
	else:
		var mhz: Array[String] = []
		for v in hz:
			mhz.append(str(int(v / 1000000)))
		r.pass_("лестница частот GPU: %d ступеней — %s МГц" % [hz.size(), ", ".join(mhz)])

	var st := clock_stats()
	if st.is_empty() or hz.is_empty():
		r.unkn("резиденция частот: сверить длину не с чем")
	elif st.size() == hz.size():
		r.pass_("резиденция частот: %d счётчиков на %d ступеней — сходится" % [st.size(), hz.size()])
	else:
		# Если длины разошлись, индексация счётчиков частотами неверна, и всё
		# построенное на ней — тоже. Это отказ, а не мелочь.
		r.fail("резиденция частот: %d счётчиков против %d ступеней — индексация неверна, доли считать нельзя" % [
				st.size(), hz.size()])

	# Фальсификатор без положительного контроля бессмысленен: если НИЧЕГО не
	# читается, «несуществующий путь не прочитался» выполняется само собой и
	# слепой прибор выглядит исправным. Поэтому исход привязан к контролю.
	var nowhere_null := read_text(P_NOWHERE) == null
	if not readable:
		r.unkn("фальсификатор sysfs: не с чем сравнивать — не читается ни один путь, включая заведомо существующий")
	elif nowhere_null:
		r.pass_("фальсификатор sysfs: существующий счётчик читается, несуществующий → «не прочитать» — прибор различает")
	else:
		r.fail("фальсификатор sysfs: несуществующий счётчик ЧТО-ТО вернул — прибор не различает отсутствие данных")
