extends RefCounted

## Свет и окружение сцены (этап Ф3). До этого сцена была пуста: в сессии 13 владелец не видел
## кнопок на моделях контроллеров, потому что их нечем было осветить.
##
## Один направленный свет и мягкий ambient — это самое дешёвое, что делает модели читаемыми на
## мобильном рендере. Тени выключены: их цена не измерена, а для чтения кнопок они не нужны.
## Свечение (glow) — по настройке: на мобильном рендере оно стоит заполнения экрана.

const Settings := preload("res://menu/settings.gd")

## Яркость направленного света и ambient по режимам настройки «Освещение».
const LEVELS := {
	"dim": {"light": 0.6, "ambient": 0.25, "sky": Color(0.10, 0.11, 0.14)},
	"studio": {"light": 1.1, "ambient": 0.45, "sky": Color(0.16, 0.18, 0.22)},
	"bright": {"light": 1.7, "ambient": 0.7, "sky": Color(0.24, 0.27, 0.32)},
}
## Наклон света: сверху и чуть сбоку — так на кнопках контроллера есть и свет, и тень.
const LIGHT_ANGLES := Vector3(-55.0, -35.0, 0.0)

var world: WorldEnvironment
var light: DirectionalLight3D
## Фальсификатор «nolight»: свет гаснет — сцена снова тёмная, как в сессии 13.
var falsify_dark := false


func setup(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	parent.add_child(world)
	light = DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = LIGHT_ANGLES
	light.shadow_enabled = false
	parent.add_child(light)


func apply(settings: Settings) -> void:
	var level: Dictionary = LEVELS[settings.get_value("space_light")]
	light.light_energy = 0.0 if falsify_dark else float(level["light"])
	var env := world.environment
	env.ambient_light_energy = 0.0 if falsify_dark else float(level["ambient"])
	env.background_color = level["sky"]
	env.glow_enabled = bool(settings.get_value("space_glow"))
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1


## Сводка для журнала и проверок.
func brief() -> String:
	return "свет %.2f, ambient %.2f, свечение %s" % [light.light_energy,
			world.environment.ambient_light_energy, world.environment.glow_enabled]
