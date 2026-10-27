extends Control

## The circular key badge inside the interaction card.
##
## Legacy markup is a 39x39 `.interact-key` with two stacked SVG circles rotated
## -90 degrees: `ring-track` (full circle, #5c705b, stroke 3) and `hold-ring`
## (#efc275, stroke 3, dasharray 132 / dashoffset 132 so it starts empty and is
## filled as the key is held).  A draw-time arc reproduces it without the SVG.

const SIZE := 39.0
const STROKE := 3.0
const TRACK := Color("5c705b")
const HOLD := Color("efc275")
const FG := Color("fff5dc")
const FONT_NAMES := [
	"DM Sans", "Segoe UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif",
]

var progress := 0.0

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	_label = Label.new()
	_label.text = "F"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", FG)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := SIZE * 0.5 - STROKE * 0.5
	draw_arc(center, radius, 0.0, TAU, 64, TRACK, STROKE, true)
	if progress > 0.0:
		# Rotated -90 degrees in CSS so the fill grows from the top, clockwise.
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, HOLD, STROKE, true)
