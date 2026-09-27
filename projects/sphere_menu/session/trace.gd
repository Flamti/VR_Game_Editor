extends RefCounted

## Трасса движений: последние секунды на такт физики — поза головы и контроллеров В ORIGIN, кнопки
## и стики, тело и origin. Сбрасывается в файл по метке, при возврате в старт, при рывке сторожа, и
## воспроизводится на столе (`tests/replay.gd`) настоящими `locomotion` и `player_body`.
##
## Зачем. Столовый стенд перевала угадал позу — рука на 0.55 м выше глаз — и дал ложный зелёный: на
## шлеме рука была на ~0.95 м выше (сессия 35), и узнал я это только из косвенных чисел журнала.
## Трасса снимает угадывание: стенд идёт по записи настоящего человека.
##
## Позы — ЛОКАЛЬНЫЕ (в origin): так их двигает человек, и так их отдаёт рантайм. Мировые получаются
## при воспроизведении сами, из тела, которое двигает воспроизводимый код. Тело и origin пишутся
## тоже — не как вход, а как свидетель: с ними сверяется воспроизведение.
##
## Чистые функции на значениях: запись — массивы чисел, файл — текст. Проверяется настольно.

## Колонки строки. Порядок — формат файла: сменился — сменить и `VERSION`.
const FIELDS := ["t",
		"hx", "hy", "hz", "hqx", "hqy", "hqz", "hqw",
		"lx", "ly", "lz", "lqx", "lqy", "lqz", "lqw",
		"rx", "ry", "rz", "rqx", "rqy", "rqz", "rqw",
		"lgrip", "rgrip", "ltrig", "rtrig", "lax", "lby", "rax", "rby",
		"lsx", "lsy", "rsx", "rsy",
		"bx", "by", "bz", "byaw", "bvx", "bvy", "bvz", "ox", "oy", "oz", "oyaw", "seq", "bphys", "lphys"]
## 2 — колонка `seq`: номер последнего переноса тела (`PlayerBody.transfer_seq`). Переносы, которые
## делает `main.gd` (посадка в старт, возврат, подъём зоны), воспроизведение не повторяет — по смене
## номера оно пересаживает тело в записанное место (первая настоящая трасса разошлась на 8.46 м с
## первого такта: в ней была посадка в старт).
## 3 — `bphys`, `lphys`: идут ли такты тела и перемещения. До старта тело заморожено, и
## воспроизведение, гонявшее его физику всегда, «догоняло» голову на 0.83 м ещё до посадки.
## 4 — `oyaw`: курс origin. Посадка в старт поворачивает origin (`main.gd:_center_player_on`), и
## без него голова в мире при воспроизведении оказывалась не там — расхождение 0.57 м.
## 5 — `bvx…bvz`: скорость тела. Тело в такте k движется со скоростью, заданной перемещением в
## такте k − 1; без неё воспроизведение стартовало с нуля и шло на такт позади записи всю трассу
## (на падении — с растущим расхождением, 0.215 м на первой трассе со шлема).
const VERSION := 5
## Сколько секунд держит буфер.
const KEEP_S := 20.0

## Фальсификатор «tracelossy» (tests/run_tests.gd): числа пишутся с двумя знаками — поза теряет
## миллиметры, и воспроизведение расходится с записью.
static var falsify_lossy := false
## Фальсификатор «tracering»: кольцо читается с нулевой ячейки, а не со старейшей — в файле
## середина записи идёт раньше начала.
static var falsify_ring := false

## Кольцо: `_next` — куда писать следующий ряд. `pop_front` сдвигал бы все 1200 рядов каждый такт.
var _rows: Array[PackedFloat64Array] = []
var _cap := 1200
var _next := 0
var _t := 0.0


func _init(ticks_per_second: int = 60) -> void:
	_cap = int(KEEP_S * ticks_per_second)


## Такт: всё, что нужно воспроизведению, одним рядом. `buttons` — {имя из FIELDS: bool},
## `sticks` — {"left": Vector2, "right": Vector2}.
func record(dt: float, head: Transform3D, left: Transform3D, right: Transform3D, buttons: Dictionary,
		sticks: Dictionary, body: Transform3D, origin_local: Transform3D, seq: int = 0,
		body_on: bool = true, loco_on: bool = true, body_v: Vector3 = Vector3.ZERO) -> void:
	_t += dt
	var row := PackedFloat64Array()
	row.append(_t)
	for xf in [head, left, right]:
		var q: Quaternion = (xf as Transform3D).basis.get_rotation_quaternion()
		row.append_array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w])
	for b in ["lgrip", "rgrip", "ltrig", "rtrig", "lax", "lby", "rax", "rby"]:
		row.append(1.0 if bool(buttons.get(b, false)) else 0.0)
	var ls: Vector2 = sticks.get("left", Vector2.ZERO)
	var rs: Vector2 = sticks.get("right", Vector2.ZERO)
	row.append_array([ls.x, ls.y, rs.x, rs.y])
	row.append_array([body.origin.x, body.origin.y, body.origin.z, rad_to_deg(body.basis.get_euler().y),
			body_v.x, body_v.y, body_v.z,
			origin_local.origin.x, origin_local.origin.y, origin_local.origin.z,
			rad_to_deg(origin_local.basis.get_euler().y), float(seq), 1.0 if body_on else 0.0,
			1.0 if loco_on else 0.0])
	if _rows.size() < _cap:
		_rows.append(row)
	else:
		_rows[_next] = row
	_next = (_next + 1) % _cap


func size() -> int:
	return _rows.size()


## Файл: строка метаданных (JSON), строка колонок, ряды. `meta` — что нужно воспроизведению сверх
## рядов: загруженные файлы уровня, настройки перемещения, частота физики, причина сброса.
func to_text(meta: Dictionary) -> String:
	var m := meta.duplicate()
	m["version"] = VERSION
	var lines: Array[String] = ["# trace\t" + JSON.stringify(m), "# " + "\t".join(FIELDS)]
	var fmt := "%.2f" if falsify_lossy else "%.5f"
	# От старого к новому: после заполнения кольца старейший — тот, что будет перезаписан следующим.
	var start := _next if _rows.size() == _cap and not falsify_ring else 0
	for i in _rows.size():
		var row: PackedFloat64Array = _rows[(start + i) % _rows.size()]
		var cells: Array[String] = []
		for v in row:
			cells.append(fmt % v)
		lines.append("\t".join(cells))
	return "\n".join(lines) + "\n"


## Разобрать файл. {ok, error, meta, rows: Array[Dictionary]} — ряд как {колонка: число}.
static func parse(text: String) -> Dictionary:
	var lines := text.split("\n", false)
	if lines.size() < 2 or not lines[0].begins_with("# trace\t"):
		return {"ok": false, "error": "не трасса", "meta": {}, "rows": []}
	var meta: Variant = JSON.parse_string(lines[0].substr(len("# trace\t")))
	if not meta is Dictionary:
		return {"ok": false, "error": "метаданные не JSON", "meta": {}, "rows": []}
	var names := lines[1].substr(2).split("\t")
	var rows: Array[Dictionary] = []
	for i in range(2, lines.size()):
		var cells := lines[i].split("\t")
		if cells.size() != names.size():
			return {"ok": false, "error": "строка %d: %d колонок из %d" % [i + 1, cells.size(), names.size()],
					"meta": meta, "rows": rows}
		var row := {}
		for k in names.size():
			row[names[k]] = cells[k].to_float()
		rows.append(row)
	return {"ok": true, "error": "", "meta": meta, "rows": rows}


## Поза из ряда: `who` — "h", "l" или "r".
static func xf(row: Dictionary, who: String) -> Transform3D:
	var q := Quaternion(float(row[who + "qx"]), float(row[who + "qy"]), float(row[who + "qz"]),
			float(row[who + "qw"])).normalized()
	return Transform3D(Basis(q), Vector3(float(row[who + "x"]), float(row[who + "y"]), float(row[who + "z"])))
