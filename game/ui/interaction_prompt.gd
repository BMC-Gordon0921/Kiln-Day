class_name InteractionPrompt
extends Control

## The floating "press F" card above the player, the Godot counterpart of the
## legacy `#interaction` element (style.css).  It is positioned every frame from
## the projected player position, exactly like main.js:322-323:
##
##     left = clamp(screen_x + 128, 125, wrap_width - 125)
##     top  = max(4, screen_y - 76)
##
## Vertical alignment is top-anchored (the legacy transform is translate(-50%,0)),
## so only the horizontal half-width offset is applied here.

const BG := Color("324636")
const FG := Color("fff5dc")
const SUB := Color("bdcdb5")
const TRACK := Color("5c705b")
const HOLD := Color("efc275")
const FONT_NAMES := [
	"DM Sans", "Segoe UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif",
]

const MESSAGES := {
	"clay": "领取完整瓷泥",
	"wheel": "推压瓷泥，调整形状",
	"carve": "用刻刀去除多余瓷泥",
	"paint": "选择颜色，亲手绘制",
	"kiln": "烧制瓷器 · 按住空格鼓风",
	"serve": "提交作品并评分",
}

## Replacement labels once the campaign state is wired in (Step 5).  Keys mirror
## the branches of stationMessage() in main.js:293.
const MESSAGES_STATEFUL := {
	"paint_fired": "烧成后补绘青花",
	"kiln_running": "继续烧制瓷器",
	"kiln_result": "查看火候结果",
	"serve_locked": "购买贴画与制作成品",
}

var _panel: PanelContainer
var _key: Control
var _title: Label
var _sub: Label
var _font: SystemFont


func _ready() -> void:
	_build()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(FONT_NAMES)

	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG.r, BG.g, BG.b, 0.94)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.157, 0.2, 0.125, 0.19)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 5)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_key = preload("res://ui/interact_key.gd").new()
	_key.custom_minimum_size = Vector2(39, 39)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_key)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	_title = Label.new()
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", FG)
	column.add_child(_title)

	_sub = Label.new()
	_sub.add_theme_font_override("font", _font)
	_sub.add_theme_font_size_override("font_size", 12)
	_sub.add_theme_color_override("font_color", SUB)
	_sub.add_theme_constant_override("line_spacing", 4)
	column.add_child(_sub)

	visible = false


## `state` carries the few flags stationMessage() branches on:
## {"fired": bool, "kiln": bool, "kiln_result": bool, "can_work": bool}.
func show_for(station_id: String, allowed: bool, state: Dictionary = {}) -> void:
	if _panel == null:
		_build()
	_title.text = _message(station_id, state)
	_sub.text = "按 F 开始操作" if allowed else "🔒 请先完成前置步骤"
	# Legacy sub line is letter-spaced; Godot has no tracking, so pad it out.
	visible = true


func _message(station_id: String, state: Dictionary) -> String:
	match station_id:
		"paint":
			if bool(state.get("fired", false)):
				return MESSAGES_STATEFUL["paint_fired"]
		"kiln":
			if bool(state.get("kiln_result", false)):
				return MESSAGES_STATEFUL["kiln_result"]
			if bool(state.get("kiln", false)):
				return MESSAGES_STATEFUL["kiln_running"]
		"serve":
			if not bool(state.get("can_work", true)):
				return MESSAGES_STATEFUL["serve_locked"]
	return MESSAGES.get(station_id, "")


## Screen position from the projected player head, clamped to the legacy limits.
func place_at(screen: Vector2, wrap_width: float) -> void:
	var card_size := _panel.get_combined_minimum_size()
	var left := clampf(screen.x + 128.0, 125.0, maxf(125.0, wrap_width - 125.0))
	var top := maxf(4.0, screen.y - 76.0)
	_panel.size = card_size
	_panel.position = Vector2(left - card_size.x * 0.5, top)


# Screen-space rect the card occupies, used by WorldLabels to hide plaques it
# would otherwise cover.
func blocking_rect() -> Rect2:
	if _panel == null:
		return Rect2()
	return _panel.get_global_rect()


func set_hold(progress: float) -> void:
	if _key != null and _key.has_method("set_progress"):
		_key.set_progress(progress)
