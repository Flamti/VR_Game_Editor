extends RefCounted
class_name ProbeReport

## Общий механизм отчёта для всех фаз прибора.
##
## Существует, чтобы пол по числу исполненных проверок и правила вердикта жили
## в ОДНОМ месте. Скопированные в каждую фазу счётчики разошлись бы — одну
## обновят, вторую забудут (PRACTICES §1.8).
##
## Три исхода, а не два (PRACTICES §3.2):
##   PASS     проверка исполнилась и утверждение верно;
##   FAIL     проверка исполнилась и утверждение неверно — это ФАКТ о железе;
##   UNKNOWN  спросить было негде. Это НЕ отказ и НЕ успех.

var passed: int = 0
var failed: int = 0
var unknown: int = 0
var lines: Array[String] = []


func pass_(text: String) -> void:
	passed += 1
	_emit("  PASS  %s" % text)


func fail(text: String) -> void:
	failed += 1
	_emit("  FAIL  %s" % text)


func unkn(text: String) -> void:
	unknown += 1
	_emit("  ????  %s" % text)


## Строка отчёта без влияния на счётчики: заголовки, числа, контекст.
func note(text: String) -> void:
	_emit(text)


func executed() -> int:
	return passed + failed + unknown


func _emit(text: String) -> void:
	lines.append(text)
	# Печатаем сразу, а не в конце: если прогон прервётся на двенадцатой минуте,
	# одиннадцать минут данных должны остаться в логе.
	print(text)
