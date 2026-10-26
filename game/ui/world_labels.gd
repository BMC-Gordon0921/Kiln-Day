class_name WorldLabels
extends Control

## Floating station plaques, the Godot counterpart of the legacy `#station-labels`
## layer (legacy/web-demo/src/main.js + style.css `.station-label`).  The chips are
## 2D controls projected from the 3D anchors every frame, exactly like the DOM
## version, so they keep a constant pixel size while the world orbits underneath.

const CHIP_BG := Color("fff9ea")
const CHIP_BG_ACTIVE := Color("3d563f")
const CHIP_TEXT := Color("585748")
const CHIP_TEXT_ACTIVE := Color("fffce8")
const NUM_BG := Color("e9e6d8")
const NUM_BG_ACTIVE := Color("f0c272")
const NUM_TEXT := Color("797969")
const NUM_TEXT_ACTIVE := Color("354b38")
const MUTED := Color("8c8d7b")
const NEAR_OUTLINE := Color("e1ab65")
const FONT_NAMES := [
	"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
]

var active_index := -1

var _world: SiteWorld
var _chips: Array[Dictionary] = []
var _font: SystemFont


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
		num.custom_minimum_size = Vector2(17, 17)
		num.add_theme_font_override("font", _font)
		num.add_theme_font_size_override("font_size", 12)
		num.add_theme_color_override("font_color", NUM_TEXT)
		num.add_theme_stylebox_override("normal", _num_style(false))
		row.add_child(num)

		var title := Label.new()
		title.text = str(entry["name"])
		title.add_theme_font_override("font", _font)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", CHIP_TEXT)
		row.add_child(title)

		var level := Label.new()
		level.text = "Lv.1"
		level.add_theme_font_override("font", _font)
		level.add_theme_font_size_override("font_size", 12)
		level.add_theme_color_override("font_color", MUTED)
		row.add_child(level)

		_chips.append({
			"node": chip, "num": num, "title": title, "level": level,
			"anchor": Vector3(entry["x"], float(entry["label_y"]) + SiteWorld.SITE_LIFT, entry["z"]),
		})


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
		level.add_theme_color_override("font_color",
				Color("c8d2bc") if active else MUTED)
	active_index = index


func _process(_delta: float) -> void:
	if _world == null or _world.camera == null:
		return
	var camera := _world.camera
	for chip_data in _chips:
		var chip: PanelContainer = chip_data["node"]
		var anchor: Vector3 = chip_data["anchor"]
		if camera.is_position_behind(anchor):
			chip.visible = false
			continue
		chip.visible = true
		var screen := camera.unproject_position(anchor)
		var size := chip.get_combined_minimum_size()
		chip.size = size
		# The DOM version translates the plaque so its bottom edge sits on the anchor.
		chip.position = (screen - Vector2(size.x * 0.5, size.y)).round()


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
