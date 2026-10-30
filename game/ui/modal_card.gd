class_name ModalCard
extends Control
## Paper card used by the map, help and workbench-upgrade sheets so they match
## the station panels instead of looking like an OS dialog.

signal closed

const TEXT := Color("3a4239")
const MUTED := Color("858678")
const PAPER := Color("faf6eb")
const BORDER := Color("dcdacb")

var _kicker: Label
var _title: Label
var _body: VBoxContainer
var _dim: ColorRect
var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0.16, 0.17, 0.14, 0.38)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.custom_minimum_size = Vector2(760, 560)
	_card.offset_left = -380
	_card.offset_right = 380
	_card.offset_top = -280
	_card.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.965, 0.925, 0.98)
	style.set_corner_radius_all(14)
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_kicker = Label.new()
	_kicker.add_theme_font_size_override("font_size", 12)
	_kicker.add_theme_color_override("font_color", MUTED)
	titles.add_child(_kicker)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", TEXT)
	titles.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.custom_minimum_size = Vector2(40, 40)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", MUTED)
	close.pressed.connect(close_card)
	head.add_child(close)
	var rule := ColorRect.new()
	rule.color = BORDER
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)


func open(kicker: String, title: String) -> void:
	_kicker.text = kicker
	_title.text = title
	for child in _body.get_children():
		child.queue_free()
	visible = true


func body() -> VBoxContainer:
	return _body


func line(text: String, size := 13, color := MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func close_card() -> void:
	visible = false
	closed.emit()
