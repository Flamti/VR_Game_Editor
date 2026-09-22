extends SceneTree

## Осмотр уровня КАРТИНКОЙ: сцена строится из данных и снимается двумя видами — с высоты глаз из
## точки старта и сверху. Арифметика связности (`world/level_check.gd`) не видит композиции: улица
## может быть связна и при этом выглядеть коридором из кубов.
##
## Запуск (нужен дисплей и Vulkan, НЕ --headless — в headless кадры не рисуются):
##   godot/bin/godot.linuxbsd.editor.x86_64 --path projects/sphere_menu --rendering-method mobile \
##       --script res://tests/render_level.gd [-- --out=/путь --level=res://...json]
##
## Проверка — не «файл записан», а «в кадре есть сцена»: доля непустых пикселей. Пустой мир даёт
## ровный фон, и без этой доли снимок серого неба сошёл бы за уровень (так уже было с проверкой
## скриншота меню, фальсификатор «noworld»).

const LevelLoader := preload("res://world/level_loader.gd")
const WorldEnv := preload("res://world/environment.gd")

## Ниже этой доли отличных от фона пикселей считаем, что сцены в кадре нет.
const MIN_LIT := 0.02

var _frame := 0
var _out := "/tmp/vrge_level"
var _level := "res://world/levels/start_location.json"
## Второй файл поверх первого: так видно, что подгружаемый интерьер стоит ВНУТРИ своего дома.
var _also := ""
var _cams: Array[Camera3D] = []
var _shots: Array[String] = []
var _spawn := Transform3D()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--level="):
			_level = a.get_slice("=", 1)
		elif a.begins_with("--also="):
			_also = a.get_slice("=", 1)
	var root := get_root()
	# Всё вешается на узел сцены: корень — это Window, и Node3D-узлы в него не ставятся.
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnv.new()
	env.setup(world)
	var res := LevelLoader.parse(FileAccess.get_file_as_string(_level))
	if not res["ok"]:
		print("ОТКАЗ: уровень не читается: %s" % res["error"])
		quit(1)
		return
	var built := LevelLoader.build(world, res["data"])
	_spawn = built["spawn"]
	if _also != "":
		var res2 := LevelLoader.parse(FileAccess.get_file_as_string(_also))
		if not res2["ok"]:
			print("ОТКАЗ: %s не читается: %s" % [_also, res2["error"]])
			quit(1)
			return
		var b2 := LevelLoader.build(world, res2["data"])
		print("поверх: %d узлов из %s" % [(b2["nodes"] as Array).size(), _also.get_file()])
	print("уровень: %d узлов, %d материалов" % [(built["nodes"] as Array).size(), built["colors"]])

	# Вид человека: из точки старта, на высоте глаз, вдоль взгляда точки старта.
	var eye := Camera3D.new()
	eye.fov = 75.0
	eye.position = _spawn.origin + Vector3(0, 1.6, 0)
	eye.rotation = Vector3(0, _spawn.basis.get_euler().y, 0)
	eye.far = 200.0
	world.add_child(eye)
	# Вид сверху: вся улица целиком, чтобы видеть планировку.
	var top := Camera3D.new()
	top.position = Vector3(0, 46, -12)
	top.rotation = Vector3(-PI / 2.0, 0, 0)
	top.far = 300.0
	world.add_child(top)
	# Вид с середины улицы вдоль неё: узость видна только отсюда.
	var street := Camera3D.new()
	street.fov = 80.0
	street.position = Vector3(0, 1.6, -6.0)
	street.rotation = Vector3(-0.06, PI, 0)
	street.far = 200.0
	world.add_child(street)
	# Вид внутрь жилого дома: интерьер подгружается отдельным файлом, и стоять он должен ВНУТРИ.
	var room := Camera3D.new()
	room.fov = 80.0
	room.position = Vector3(-4.2, 1.6, -6.0)
	room.rotation = Vector3(0, PI / 2.0, 0)
	room.far = 60.0
	world.add_child(room)
	# Вид на стену лазанья: зацепы обязаны ТОРЧАТЬ из стены, иначе браться не за что (сессия 29 —
	# бруски стояли заподлицо, и лазанья не случилось ни разу).
	var climb := Camera3D.new()
	climb.fov = 70.0
	climb.position = Vector3(-0.6, 1.7, -28.0)
	climb.rotation = Vector3(0, PI / 2.0, 0)
	climb.far = 60.0
	world.add_child(climb)
	_cams = [eye, top, street, room, climb]
	_shots = ["eye", "top", "street", "room", "climb"]
	eye.current = true


func _process(_delta: float) -> bool:
	_frame += 1
	# Кадр на камеру, плюс пара кадров на прогрев: первый кадр после смены камеры приходит пустым.
	var idx := (_frame - 3) / 2
	if _frame < 3 or idx >= _cams.size():
		if idx >= _cams.size():
			quit()
		return false
	if (_frame - 3) % 2 == 0:
		for i in _cams.size():
			_cams[i].current = i == idx
		return false
	var img := get_root().get_texture().get_image()
	var path := "%s_%s.png" % [_out, _shots[idx]]
	img.save_png(path)
	print("%s: %dx%d, непустых %.1f%%" % [path, img.get_width(), img.get_height(),
			_lit_share(img) * 100.0])
	return false


## Доля пикселей, отличающихся от самого частого цвета кадра (фон неба).
func _lit_share(img: Image) -> float:
	var counts := {}
	var step := 4
	var total := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var key := img.get_pixel(x, y).to_rgba32() >> 11
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
	var top := 0
	for k in counts:
		top = maxi(top, int(counts[k]))
	return 1.0 - float(top) / maxf(1.0, float(total))
