extends RefCounted
class_name ProbeStats

## Статистика по серии замеров.
##
## Печатает И среднее, И пик: одиночный выброс и ровный расход дают одинаковое
## среднее, но называют РАЗНЫХ виновников (PRACTICES §3.3).

var samples: Array[float] = []


func add(v: float) -> void:
	samples.append(v)


func count() -> int:
	return samples.size()


func mean() -> float:
	if samples.is_empty():
		return NAN
	var s := 0.0
	for v in samples:
		s += v
	return s / samples.size()


func percentile(p: float) -> float:
	if samples.is_empty():
		return NAN
	var sorted := samples.duplicate()
	sorted.sort()
	var idx := int(round((sorted.size() - 1) * clampf(p, 0.0, 1.0)))
	return sorted[idx]


func median() -> float:
	return percentile(0.5)


func maximum() -> float:
	if samples.is_empty():
		return NAN
	return samples.max()


func minimum() -> float:
	if samples.is_empty():
		return NAN
	return samples.min()


## Одной строкой: и сумма, и пик.
func brief(unit: String = "мс") -> String:
	if samples.is_empty():
		return "нет выборок"
	return "n=%d  сред=%.3f  мед=%.3f  p95=%.3f  макс=%.3f %s" % [
		count(), mean(), median(), percentile(0.95), maximum(), unit,
	]
