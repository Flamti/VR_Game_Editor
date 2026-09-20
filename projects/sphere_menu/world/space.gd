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
## Фальсификатор «noreset»: сброс не трогает ни положение, ни режим зоны — только пишет в журнал.
var falsify_no_reset := false

var last_detail := ""


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
