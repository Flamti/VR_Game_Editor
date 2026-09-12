extends RefCounted
class_name ProbeBudget

## Бюджет кадра как ФУНКЦИЯ от частоты, а не константа (ADR-0006).
##
## До ADR-0006 бюджет был записан числом 13.89 мс — по частоте 72 Гц, которую
## Godot берёт по умолчанию. Но устройство предлагает [72, 80, 90, 120] Гц, и
## решение владельца — просить максимум и жить на том, что дала ОС. Значит
## константы быть не может: 120 → 8.33, 90 → 11.11, 80 → 12.50, 72 → 13.89 мс.
##
## Отдельный файл, чтобы это вычисление существовало в ОДНОМ месте: три копии
## разошлись бы (PRACTICES §1.8). До этого файла свои `_refresh_rate()` и
## `_budget_ms()` были у probe_drawcalls.gd и у probe_sustained.gd.

## Допуск сравнения частот. Строгое равенство float здесь неуместно: числа
## приходят от рантайма, и 119.99 против 120.0 не должно читаться как отказ.
const HZ_EPS := 0.5

## Сколько ждать, пока запрос частоты доедет. Смена асинхронна (см. ниже),
## а по истечении срока прибор обязан доложить факт, а не ждать вечно.
const REQUEST_TIMEOUT_MS := 3000.0

## Сколько ждать готовности сессии перед запросом. Пока сессия не поднялась,
## xrGetDisplayRefreshRateFB возвращает 0, и запрашивать бессмысленно.
const READY_TIMEOUT_MS := 5000.0


static func ms_for_hz(hz: float) -> float:
	return (1000.0 / hz) if hz > 1.0 else NAN


static func same_hz(a: float, b: float) -> bool:
	return absf(a - b) < HZ_EPS


static func iface() -> XRInterface:
	return XRServer.find_interface("OpenXR")


static func current_hz() -> float:
	var i := iface()
	if i != null and i.has_method("get_display_refresh_rate"):
		return i.get_display_refresh_rate()
	return 0.0


## Бюджет на текущей частоте. Единственный способ узнать бюджет в приборе.
static func current_ms() -> float:
	return ms_for_hz(current_hz())


## Есть ли вообще API частот. Нужен отдельно от available_hz(): пустой список
## и отсутствующий API — разные вещи, и путать их нельзя (PRACTICES §3.2).
static func has_rate_api() -> bool:
	var i := iface()
	return i != null and i.has_method("get_available_display_refresh_rates")


static func available_hz() -> Array:
	if not has_rate_api():
		return []
	return iface().get_available_display_refresh_rates()


static func max_available_hz() -> float:
	var best := 0.0
	for v in available_hz():
		best = maxf(best, float(v))
	return best


## Запрос максимальной доступной частоты (ADR-0006).
##
## КОРУТИНА, и это не украшение. `set_display_refresh_rate()` — это
## `xrRequestDisplayRefreshRateFB`, то есть ЗАПРОС: рантайм применяет его
## асинхронно и сообщает событием, которое Godot превращает в сигнал
## `refresh_rate_changed` (openxr_interface.cpp:1470). Чтение частоты сразу
## после запроса вернёт СТАРОЕ значение, и прибор доложил бы «запрошено 120,
## получено 72» на полностью успешном запросе. Именно так и была написана
## первая редакция этого файла.
##
## Возвращает ЗАПРОШЕННОЕ и ПОЛУЧЕННОЕ раздельно: если ОС не дала запрошенное,
## это обязано быть видно, а не выглядеть как «работаем на 120» (§1.4).
## Поле `outcome` — три исхода, а не два:
##   "ok"          получено запрошенное (в том числе «уже были на нём»);
##   "denied"      спросили, рантайм не дал — ФАКТ о платформе;
##   "unavailable" спросить было негде — НЕ отказ и НЕ успех.
static func request_max(host: Node) -> Dictionary:
	var d := {
		"before": 0.0,
		"requested": 0.0,
		"got": 0.0,
		"outcome": "unavailable",
		"waited_ms": 0.0,
		"reason": "",
	}

	var i := iface()
	if i == null:
		d["reason"] = "интерфейс OpenXR не найден"
		return d
	if not has_rate_api() or not i.has_method("set_display_refresh_rate"):
		d["reason"] = "XR_FB_display_refresh_rate недоступен: частотой управлять нечем"
		return d

	# Готовность сессии. Пока рантайм не отдаёт частоту, запрос уйдёт в никуда,
	# и получился бы ложный отказ — прибор обвинил бы платформу в том, что
	# спросили слишком рано. Ждём именно тем же вызовом, каким потом читаем.
	var t_ready := Time.get_ticks_msec()
	while current_hz() <= 1.0:
		if float(Time.get_ticks_msec() - t_ready) >= READY_TIMEOUT_MS:
			d["reason"] = "сессия не отдала частоту за %.0f мс" % READY_TIMEOUT_MS
			return d
		await host.get_tree().process_frame

	var before := current_hz()
	var want := max_available_hz()
	d["before"] = before
	d["got"] = before
	d["requested"] = want

	if want <= 1.0:
		d["reason"] = "список доступных частот пуст — запрашивать нечего"
		return d

	if same_hz(want, before):
		d["outcome"] = "ok"
		d["reason"] = "уже на максимуме, запрос не потребовался"
		return d

	i.set_display_refresh_rate(want)

	var t0 := Time.get_ticks_msec()
	var got := before
	while true:
		await host.get_tree().process_frame
		got = current_hz()
		d["waited_ms"] = float(Time.get_ticks_msec() - t0)
		if same_hz(got, want) or d["waited_ms"] >= REQUEST_TIMEOUT_MS:
			break

	d["got"] = got
	if same_hz(got, want):
		d["outcome"] = "ok"
	else:
		d["outcome"] = "denied"
		d["reason"] = "рантайм не дал запрошенное за %.0f мс" % d["waited_ms"]
	return d
