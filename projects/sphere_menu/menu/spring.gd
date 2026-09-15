extends RefCounted

## Критически демпфированная пружина — детент к центру ячейки (docs/design/sphere-menu.md §2).
##
## Критическое демпфирование — самое быстрое приближение без перелёта: ячейка
## доезжает и не качается. Шаг точный (аналитическое решение), а не Эйлер:
## иначе поведение зависело бы от частоты кадров, а у нас их две (ADR-0007).

## Жёсткость, 1/с. Больше — быстрее доводка.
var omega := 14.0
var value := 0.0
var velocity := 0.0


func step(target: float, dt: float) -> float:
	var x := value - target
	var e := exp(-omega * dt)
	var new_x := (x + (velocity + omega * x) * dt) * e
	velocity = (velocity - omega * (velocity + omega * x) * dt) * e
	value = target + new_x
	return value
