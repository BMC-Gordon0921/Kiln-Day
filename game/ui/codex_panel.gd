class_name CodexPanel
extends Control

## 瓷器图鉴：四格藏品。已收录的显示器型、名字与顾客，未收录的留剪影。
## 数据来自 catalog + SaveGame 的 codex.discovered，面板只负责展示。

signal closed

const TEXT := Color("3a4239")
const MUTED := Color("858678")
const PAPER := Color("faf6eb")
const PAPER_SOFT := Color("f3edda")
const BORDER := Color("dcdacb")
const GREEN := Color("374e3c")
const GREEN_SOFT := Color("e0e5d3")
const GOLD := Color("bd8a3d")

const CARD_SIZE := Vector2(1040, 660)
const PRESET_PATH := "res://assets/reference/preset-%d.png"

var _dim: ColorRect
var _card: PanelContainer
var _count_label: Label
var _grid: HBoxContainer
var _detail: VBoxContainer
var _font_body: Font
var _font_title: Font
var _items: Array = []
var _discovered: Array = []
var _selected := 0


func _ready() -> void:
	name = "CodexPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_fonts()
	_build_card()


func _build_fonts() -> void:
	_font_body = _load_font("res://assets/fonts/DMSans-Variable.ttf")
	_font_title = _load_font("res://assets/fonts/Fraunces-Variable.ttf")


func _load_font(path: String) -> Font:
	var file := FontFile.new()
	file.load_dynamic_font(path)
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray([
		"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC",
	])
	file.fallbacks = [cjk]
	return file


func open(items: Array, discovered: Array) -> void:
	_items = items
	_discovered = discovered
	_selected = clampi(_selected, 0, maxi(items.size() - 1, 0))
	_rebuild()
	visible = true
	move_to_front()


func close_panel() -> void:
	visible = false
	closed.emit()


func _build_card() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.13, 0.12, 0.08, 0.38)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.18, 0.15, 0.10, 0.22)
	style.shadow_size = 28
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 26
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_card.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("四方瓷韵 · 图鉴", 11, MUTED, true))
	titles.add_child(_label("我的瓷器藏品", 32, TEXT, false, _font_title))
	_count_label = _label("0 / 4", 13, MUTED, false)
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_count_label)

	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(32, 32)
	close.add_theme_font_size_override("font_size", 15)
	close.add_theme_color_override("font_color", MUTED)
	close.pressed.connect(close_panel)
	header.add_child(close)

	var rule := ColorRect.new()
	rule.color = BORDER
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(top_gap)

	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 14)
	column.add_child(_grid)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 5)
	column.add_child(_detail)


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var found := 0
	for i in maxi(_items.size(), 4):
		var item: Dictionary = _items[i] if i < _items.size() else {}
		var has := not item.is_empty() and _discovered.has(str(item.get("id", "")))
		if has:
			found += 1
		_grid.add_child(_slot(i, item, has))
	_count_label.text = "%d / %d" % [found, maxi(_items.size(), 4)]
	_rebuild_detail()


func _slot(index: int, item: Dictionary, has: bool) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(214, 300)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_SOFT if index != _selected else Color("f8f0da")
	style.border_color = GOLD if index == _selected else BORDER
	style.set_border_width_all(2 if index == _selected else 1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	slot.add_theme_stylebox_override("panel", style)
	slot.gui_input.connect(_on_slot_input.bind(index))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(column)

	var art_holder := PanelContainer.new()
	art_holder.custom_minimum_size = Vector2(0, 168)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("efe8d5")
	art_style.set_corner_radius_all(8)
	art_holder.add_theme_stylebox_override("panel", art_style)
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art_holder)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if index < 3:
		art.texture = load(PRESET_PATH % index)
	else:
		art.texture = load("res://assets/textures/decals/01-blue-floral.png")
	if not has:
		art.modulate = Color(0.22, 0.21, 0.18, 0.88)
	art_holder.add_child(art)

	if not has:
		var overlay := CenterContainer.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(overlay)
		overlay.add_child(_label("？", 46, Color(0.96, 0.92, 0.82, 0.92), false, _font_title))

	var name_label := _label(str(item.get("name", "")) if has else "尚未收录", 17, TEXT if has else MUTED, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var meta := "第 %d 件 · %s" % [index + 1, str(item.get("customer", "")) if has else "继续接单"]
	var meta_label := _label(meta, 11, MUTED, false)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(meta_label)

	return slot


func _rebuild_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	if _items.is_empty():
		return
	var item: Dictionary = _items[clampi(_selected, 0, _items.size() - 1)]
	var has := _discovered.has(str(item.get("id", "")))
	_detail.add_child(_label("藏品档案", 11, MUTED, true))
	if not has:
		_detail.add_child(_label("这一格还空着：完成一单就能把它收进来。", 15, TEXT, true))
		return
	_detail.add_child(_label("%s · 顾客 %s" % [item.get("name", ""), item.get("customer", "")], 15, TEXT, true))
	_detail.add_child(_label("器型要求：" + str(item.get("task", "")), 12, MUTED, false))
	_detail.add_child(_label("要点：" + str(item.get("hint", "")), 12, MUTED, false))


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected = index
		_rebuild()


func _label(text: String, size: int, color: Color, bold := false, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font != null else _font_body)
	label.add_theme_font_size_override("font_size", roundi(size * 1.08))
	label.add_theme_color_override("font_color", color)
	if bold:
		var variation := FontVariation.new()
		variation.base_font = label.get_theme_font("font")
		variation.variation_opentype = {"wght": 640}
		label.add_theme_font_override("font", variation)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
