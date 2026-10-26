class_name KilnRun
extends RefCounted
## 一次 12 秒烧窑：按住加温、松手降温，把热度压在一条缓慢漂移的火候带里。
##
## 数值与 `legacy/web-demo/src/workshop.js` 的 fireDrift / fireBand 完全同源，
## 漂移曲线已由 goldens 对拍过（tests/cases/test_workshop.gd）。

var duration := Workshop.FIRE_DURATION
var level := 1
var heat := Workshop.FIRE_START_HEAT
var elapsed := 0.0
var seconds := {"perfect": 0.0, "good": 0.0, "fair": 0.0}
var stoking := false

var _drift: Callable
var _band: Dictionary


func _init(seed_value := 1, p_level := 1) -> void:
	level = p_level
	_drift = Workshop.create_fire_drift(seed_value)
	_band = Workshop.fire_band(p_level)


func band_center() -> float:
	return float(_drift.call(elapsed))


## 当前热度离带心多远。界面用它决定颜色。
func deviation() -> float:
	return absf(heat - band_center())


func in_perfect() -> bool:
	return deviation() <= float(_band["perfect"])


func in_good() -> bool:
	return deviation() <= float(_band["good"])


func progress() -> float:
	return clampf(elapsed / duration, 0.0, 1.0)


func finished() -> bool:
	return elapsed >= duration


## 推进一帧。stoking=true 表示玩家正按住加温。
func tick(delta: float) -> void:
	if finished():
		return
	var step := minf(delta, duration - elapsed)
	heat += (Workshop.FIRE_HEAT_RATE if stoking else -Workshop.FIRE_COOL_RATE) * step
	heat = clampf(heat, 0.0, 1.0)
	if in_perfect():
		seconds["perfect"] += step
	elif in_good():
		seconds["good"] += step
	else:
		seconds["fair"] += step
	elapsed += step


func grade() -> String:
	if not finished():
		return "plain"
	return Workshop.fire_grade(seconds)
