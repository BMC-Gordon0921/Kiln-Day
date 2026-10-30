class_name WorldLabels
extends Control

## Floating station plaques, the Godot counterpart of the legacy `#station-labels`
## layer (legacy/web-demo/src/main.js + style.css `.station-label`).  The chips are
## 2D controls projected from the 3D anchors every frame, exactly like the DOM
## version, so they keep a constant pixel size while the world orbits underneath.

const CHIP_BG := Color("fff9ea")
const CHIP_BG_ACTIVE := Color("fdf6e4")
const CHIP_TEXT := Color("585748")
const CHIP_TEXT_ACTIVE := Color("44483c")
const NUM_BG := Color("e9e6d8")
const NUM_BG_ACTIVE := Color("f0bd6c")
const NUM_TEXT := Color("797969")
const NUM_TEXT_ACTIVE := Color("3c3a2c")
const MUTED := Color("8c8d7b")
const NEAR_OUTLINE := Color("e1ab65")
const FONT_NAMES := [
	"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
]

var active_index := -1
var next_visible := true
var avoid_rect := Rect2()
var view_origin := Vector2.ZERO
var local_scale := 1.0


## The plaques live under the scaled UI root, so camera pixels need converting
## to that local space (and back for the prompt overlap test).
func set_view(origin: Vector2, factor: float) -> void:
	view_origin = origin
	local_scale = maxf(factor, 0.001)

var _world: SiteWorld
var _chips: Array[Dictionary] = []
var _font: SystemFont
var _next_tag: PanelContainer
var _next_label: Label
var _next_arrow: Control


func setup(world: SiteWorld) -> void:
	_world = world
	_build()


func _build() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(FONT_NAMES)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in SiteLayout.STATIONS.size():
		var entry: Dictionary = SiteLayout.STATIONS[i]
		var chip := PanelContainer.new()
		chip.name = "StationLabel_%s" % entry["id"]
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", _chip_style(false))
		add_child(chip)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)

		var num := Label.new()
		num.text = str(i + 1)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.custom_minimum_size = Vector2(21, 21)
		num.add_theme_font_override("font", _font)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_color", NUM_TEXT)
		num.add_theme_stylebox_override("normal", _num_style(false))
		row.add_child(num)

		var title := Label.new()
		title.text = str(entry["name"])
		title.add_theme_font_override("font", _font)
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", CHIP_TEXT)
		row.add_child(title)

		var level := Label.new()
		level.text = "Lv.1"
		level.add_theme_font_override("font", _font)
		level.add_theme_font_size_override("font_size", 13)
		level.add_theme_color_override("font_color", MUTED)
		row.add_child(level)

		_chips.append({
			"node": chip, "num": num, "title": title, "level": level,
			"anchor": Vector3(entry["x"], float(entry["label_y"]) + SiteWorld.SITE_LIFT, entry["z"]),
		})

	_build_next_tag()


## Legacy main.js draws a cream callout plus a chunky orange arrow above the
## station the player should visit next (`#next-hint`).  Rebuild it as 2D
## controls that follow the active plaque every frame.
func _build_next_tag() -> void:
	_next_tag = PanelContainer.new()
	_next_tag.name = "NextStation"
	_next_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.976, 0.914, 0.94)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("e2b478")
	style.shadow_color = Color(0.55, 0.36, 0.16, 0.14)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	_next_tag.add_theme_stylebox_override("panel", style)
	add_child(_next_tag)
	_next_label = Label.new()
	_next_label.add_theme_font_override("font", _font)
	_next_label.add_theme_font_size_override("font_size", 13)
	_next_label.add_theme_color_override("font_color", Color("9c6534"))
	_next_tag.add_child(_next_label)

	_next_arrow = Control.new()
	_next_arrow.name = "NextArrow"
	_next_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_arrow.custom_minimum_size = Vector2(34, 40)
	_next_arrow.draw.connect(_draw_arrow)
	add_child(_next_arrow)


func _draw_arrow() -> void:
	var color := Color("f0a24e")
	var w := _next_arrow.size.x
	var shaft := Rect2(w * 0.5 - 5.0, 0.0, 10.0, 26.0)
	_next_arrow.draw_rect(shaft, color)
	var tip := PackedVector2Array([
		Vector2(w * 0.5 - 15.0, 23.0),
		Vector2(w * 0.5 + 15.0, 23.0),
		Vector2(w * 0.5, 40.0),
	])
	_next_arrow.draw_colored_polygon(tip, color)


func set_avoid_rect(rect: Rect2) -> void:
	avoid_rect = rect


func set_next_visible(value: bool) -> void:
	next_visible = value
	_apply_next_visibility()


func _apply_next_visibility() -> void:
	var show := next_visible and active_index >= 0 and active_index < _chips.size()
	if _next_tag != null:
		_next_tag.visible = show
	if _next_arrow != null:
		_next_arrow.visible = show


func set_active(index: int) -> void:
	if index == active_index:
		return
	for i in _chips.size():
		var active := i == index
		var chip: PanelContainer = _chips[i]["node"]
		chip.add_theme_stylebox_override("panel", _chip_style(active))
		var num: Label = _chips[i]["num"]
		num.add_theme_stylebox_override("normal", _num_style(active))
		num.add_theme_color_override("font_color", NUM_TEXT_ACTIVE if active else NUM_TEXT)
		var title: Label = _chips[i]["title"]
		title.add_theme_color_override("font_color", CHIP_TEXT_ACTIVE if active else CHIP_TEXT)
		var level: Label = _chips[i]["level"]
		level.add_theme_color_override("font_color", MUTED)
	active_index = index
	if index >= 0 and index < _chips.size():
		var entry: Dictionary = SiteLayout.STATIONS[index]
		_next_label.text = "下一站 · %s" % str(entry["name"])
	_apply_next_visibility()


func _process(_delta: float) -> void:
	if _world == null or _world.camera == null:
		return
	var camera := _world.camera
	var placed: Array[Rect2] = []
	for chip_data in _chips:
		var chip: PanelContainer = chip_data["node"]
		var anchor: Vector3 = chip_data["anchor"]
		if camera.is_position_behind(anchor):
			chip.visible = false
			continue
		var screen := camera.unproject_position(anchor) + view_origin
		var size := chip.get_combined_minimum_size()
		chip.size = size
		# The DOM version translates the plaque so its bottom edge sits on the anchor.
		chip.position = ((screen - Vector2(size.x * 0.5, size.y)) / local_scale).round()
		# chip.position is local to the scaled UI root; avoid_rect is global screen.
		var chip_rect := Rect2(chip.position * local_scale + view_origin, size * local_scale)
		chip.visible = avoid_rect.size == Vector2.ZERO or not avoid_rect.intersects(chip_rect)
		# Nudge plaques that would overlap a neighbour so dense clusters stay readable.
		if chip.visible:
			var rect := Rect2(chip.position, size)
			for other in placed:
				if rect.intersects(other):
					rect.position.y = other.end.y + 2.0
			chip.position = rect.position
			placed.append(rect)
	if active_index >= 0 and active_index < _chips.size():
		var active_chip: PanelContainer = _chips[active_index]["node"]
		var tag_size := _next_tag.get_combined_minimum_size()
		_next_tag.size = tag_size
		var center_x := active_chip.position.x + active_chip.size.x * 0.5
		_next_tag.position = Vector2(
			round(center_x - tag_size.x * 0.5),
			round(active_chip.position.y - tag_size.y - 8.0))
		_next_arrow.position = Vector2(
			round(center_x - _next_arrow.size.x * 0.5),
			round(_next_tag.position.y - 36.0))
		_next_arrow.queue_redraw()


func _chip_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_BG_ACTIVE if active else CHIP_BG
	style.set_corner_radius_all(8)
	style.content_margin_left = 7
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.35) if not active else Color(0, 0, 0, 0)
	style.shadow_color = Color(0.28, 0.24, 0.16, 0.12)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style


func _num_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NUM_BG_ACTIVE if active else NUM_BG
	style.set_corner_radius_all(4)
	style.content_margin_left = 0
	style.content_margin_right = 0
	return style
