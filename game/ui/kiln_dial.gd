class_name KilnDial
extends Control
## Circular heat gauge for the kiln sheet: a 270° track, the drifting perfect
## and good bands, and a needle showing the current heat.

const TRACK := Color("e9e1cf")
const GOOD := Color("e9b471")
const PERFECT := Color("d4642c")
const NEEDLE := Color("b0603c")

var run: KilnRun

var _value: Label
var _state: Label


func _ready() -> void:
	custom_minimum_size = Vector2(240, 220)
	_value = Label.new()
	_value.add_theme_font_size_override("font_size", 30)
	_value.add_theme_color_override("font_color", Color("3a4239"))
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_value.offset_left = -60
	_value.offset_right = 60
	_value.offset_top = -44
	_value.offset_bottom = 0
	add_child(_value)
	_state = Label.new()
	_state.add_theme_font_size_override("font_size", 12)
	_state.add_theme_color_override("font_color", Color("5c6154"))
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_state.offset_left = -60
	_state.offset_right = 60
	_state.offset_top = 0
	_state.offset_bottom = 24
	add_child(_state)


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if run == null:
		return
	_value.text = "%d%%" % roundi(run.heat * 100.0)
	if run.finished():
		_state.text = "烧制完成"
	elif run.heat > 0.0:
		_state.text = "完美" if run.in_perfect() else ("良好" if run.in_good() else "偏高" if run.heat > 0.6 else "升温中")
	else:
		_state.text = "等待烧制"


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 16.0
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	draw_arc(center, radius, start, start + sweep, 72, TRACK, 16.0, true)
	if run == null:
		return
	var band := Workshop.fire_band(run.level)
	var mid := run.band_center()
	_band(center, radius, start, sweep, mid - float(band["good"]), mid + float(band["good"]), GOOD)
	_band(center, radius, start, sweep, mid - float(band["perfect"]), mid + float(band["perfect"]), PERFECT)
	var a := start + sweep * clampf(run.heat, 0.0, 1.0)
	var tip := center + Vector2(cos(a), sin(a)) * (radius - 14.0)
	var tail := center + Vector2(cos(a), sin(a)) * (radius * 0.64)
	draw_line(tail, tip, NEEDLE, 4.0, true)
	draw_circle(tail, 5.0, NEEDLE)


func _band(center: Vector2, radius: float, start: float, sweep: float,
		lo: float, hi: float, color: Color) -> void:
	var a0 := start + sweep * clampf(lo, 0.0, 1.0)
	var a1 := start + sweep * clampf(hi, 0.0, 1.0)
	if a1 <= a0:
		return
	draw_arc(center, radius, a0, a1, 48, color, 16.0, true)
