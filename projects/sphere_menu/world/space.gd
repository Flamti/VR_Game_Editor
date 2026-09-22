extends RefCounted

## Пространство XR: сброс к тому, что выдаёт система шлема (просьба владельца после сессии 13).
##
## Что значит «системное»:
##   - режим игровой зоны — stage (пол шлема, начало — центр зоны, как настроила система);
##   - положение и курс — заново от текущей позы головы (`XRServer.center_on_hmd`), то есть без
##     наших накопленных сдвигов;
##   - высота глаз — измеряется заново (world/eye_measure.gd), а не берётся из профиля.
##
## Quest НЕ отдаёт приложению рост человека — только высоту шлема над полом, поэтому «системная
## высота» это и есть измеренная высота глаз (ADR-0010, решение владельца 2026-09-20).
##
## Вызовы XR живут в подменяемых Callable: сброс проверяется настольно, без шлема.

## Что сделал сброс — строка для журнала.
signal reset_done(detail: String)

var recenter: Callable = func() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
var set_play_area: Callable = func(mode: int) -> bool:
	var xr := XRServer.primary_interface
	return xr != null and xr.set_play_area_mode(mode)
var play_area_mode: Callable = func() -> int:
	var xr := XRServer.primary_interface
	return int(xr.get_play_area_mode()) if xr != null else -1
## Фальсификатор «sitting»: зона с полом при запуске не запрашивается — остаётся та, что отдала
## система. Сессия 32: пришла «сидячая» (режим 2), высота головы в ней считается от точки старта, а
## не от пола, и человек оказывался глазами на уровне земли — «спавнюсь ниже пола».
var falsify_no_floor := false

## Фальсификатор «noreset»: сброс не трогает ни положение, ни режим зоны — только пишет в журнал.
var falsify_no_reset := false

var last_detail := ""


## Зона, у которой есть ПОЛ: без неё высота головы отсчитывается не от земли. Порядок проб —
## от лучшего к худшему: stage (пол и центр зоны, как настроила система), затем roomscale
## (пол, центр — точка старта). Возвращает режим, который получился.
##
## Спрашивается при каждом запуске, а не однажды: режим зоны принадлежит системе шлема, она может
## отдать сидячую после пересборки границы, и приложение обязано это заметить.
func ensure_floor() -> int:
	if falsify_no_floor:
		return int(play_area_mode.call())
	for mode in [XRInterface.XR_PLAY_AREA_STAGE, XRInterface.XR_PLAY_AREA_ROOMSCALE]:
		set_play_area.call(mode)
		if has_floor(int(play_area_mode.call())):
			break
	return int(play_area_mode.call())


## Дождаться, пока запрошенная зона ПРИМЕНИТСЯ. Смена асинхронна: `set_play_area_mode` лишь
## помечает пространство «грязным» (`openxr_api.cpp:1590`), а новое создаётся на следующем кадре.
## Чтение сразу после запроса возвращает старый режим и превращает успех в ложный отказ — ровно то
## же, что с частотой кадров (ловушка 11). Возвращает режим, который получился.
func ensure_floor_wait(host: Node, frames := 30) -> int:
	var got := ensure_floor()
	for _i in frames:
		if has_floor(got):
			break
		await host.get_tree().process_frame
		got = int(play_area_mode.call())
	return got


## Есть ли у режима зоны пол, то есть отсчитывается ли высота головы от земли.
static func has_floor(mode: int) -> bool:
	return mode == XRInterface.XR_PLAY_AREA_STAGE or mode == XRInterface.XR_PLAY_AREA_ROOMSCALE


## Сбросить пространство. on_measure — запуск замера высоты глаз (profile/profile_ui.gd).
func reset(on_measure: Callable = Callable()) -> String:
	var mode_before: int = play_area_mode.call()
	var staged := false
	if not falsify_no_reset:
		staged = bool(set_play_area.call(XRInterface.XR_PLAY_AREA_STAGE))
		recenter.call()
	var mode_after: int = play_area_mode.call()
	if on_measure.is_valid():
		on_measure.call()
	last_detail = "режим зоны %d → %d (stage %s), положение сброшено %s, высота глаз измеряется" % [
			mode_before, mode_after, staged, not falsify_no_reset]
	reset_done.emit(last_detail)
	return last_detail
