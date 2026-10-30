class_name SiteHud
extends Control

signal codex_requested
signal reset_view_requested

## The world-screen chrome, ported from the legacy DOM stack (style.css: topbar,
## commissions rail, guide card, bottom bar).  Everything is built in code because
## the layout mirrors the CSS box model one-to-one; the numbers in the comments are
## the computed values captured in art/data/legacy-screen-tokens.json.

const FONT_SCALE := 1.15
const TOPBAR_HEIGHT := 95.0
const BOTTOMBAR_HEIGHT := 58.0
const RAIL_WIDTH := 250.0
const RAIL_RIGHT := 26.0
const RAIL_TOP := 125.0

const TEXT := Color("3a4239")
const MUTED := Color("858678")
const SOFT := Color("8c8d7b")
const PAPER := Color("faf6eb")
const BORDER := Color("dcdacb")
const GREEN := Color("374e3c")
const GREEN_SOFT := Color("e0e5d3")
const CREAM := Color("f7f5e9")
const GOLD := Color("bd8a3d")

const SANS_PATH := "res://assets/fonts/DMSans-Variable.ttf"
const DISPLAY_PATH := "res://assets/fonts/Fraunces-Variable.ttf"
const PRESET_PATH := "res://assets/reference/preset-%d.png"
const DECAL_PATH := "res://assets/textures/decals/0%d-%s.png"
const DECAL_FILES := ["blue-floral", "linglong", "kiln-flame", "pink-petals"]

var _sans: Font
var _bold: Font
var _display: Font
var _display_bold: Font
var _cjk: SystemFont

var _topbar: Panel
var _day_pill: HBoxContainer
var _rail: VBoxContainer
var _level_label: Label
var _order_name_label: Label
var _reference_art: TextureRect
var _collection_value: Label
var _guide: PanelContainer
var _money_label: Label
var _guide_number: Label
var _guide_kicker: Label
var _guide_title: Label
var _guide_copy: Label
var _scene_title: Label
var _scene_small: Label

var _site: Dictionary = {}
var _order: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_fonts()

	_site = Catalog.site(Catalog.load_catalog(), GameState.current_site_id())
	var items := Catalog.items_for_site(Catalog.load_catalog())
	if not items.is_empty():
		_order = items[clampi(GameState.order_index, 0, items.size() - 1)]

	_build_topbar()
	_build_rail()
	_build_guide()
	_build_bottom_bar()
	_build_reset_button()
	GameState.coins_changed.connect(_on_coins_changed)


func _build_fonts() -> void:
	_cjk = SystemFont.new()
	_cjk.multichannel_signed_distance_field = false
	_cjk.font_names = PackedStringArray([
		"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "SimHei", "sans-serif",
	])
	var fallbacks: Array[Font] = [_cjk]

	_sans = load(SANS_PATH)
	if _sans is FontFile:
		(_sans as FontFile).multichannel_signed_distance_field = false
		(_sans as FontFile).fallbacks = fallbacks
	_display = load(DISPLAY_PATH)
	if _display is FontFile:
		(_display as FontFile).multichannel_signed_distance_field = false
		(_display as FontFile).fallbacks = fallbacks

	var bold := FontVariation.new()
	bold.base_font = _sans
	bold.variation_opentype = {"wght": 700}
	_bold = bold

	var display_bold := FontVariation.new()
	display_bold.base_font = _display
	display_bold.variation_opentype = {"wght": 600}
	_display_bold = display_bold

	var theme := Theme.new()
	theme.default_font = _sans
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	self.theme = theme


func _build_topbar() -> void:
	_topbar = Panel.new()
	_topbar.name = "Topbar"
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_topbar.offset_bottom = TOPBAR_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.937, 0.925, 0.882, 0.91)
	style.border_width_bottom = 1
	style.border_color = Color(0.843, 0.843, 0.769, 0.5)
	_topbar.add_theme_stylebox_override("panel", style)
	add_child(_topbar)

	# Brand: rotated clay tile + wordmark + subtitle (style.css .brand).
	var brand := HBoxContainer.new()
	brand.name = "Brand"
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.position = Vector2(32, 0)
	brand.size = Vector2(420, TOPBAR_HEIGHT)
	brand.alignment = BoxContainer.ALIGNMENT_BEGIN
	brand.add_theme_constant_override("separation", 11)
	_topbar.add_child(brand)

	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/logo-mark.png")
	mark.custom_minimum_size = Vector2(48, 48)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark_holder := Control.new()
	mark_holder.custom_minimum_size = Vector2(48, 48)
	mark_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark_holder.rotation = deg_to_rad(-7.0)
	mark_holder.pivot_offset = Vector2(24, 24)
	mark_holder.add_child(mark)
	# logo-mark.png already carries the rust tile shape and transparency.
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brand.add_child(mark_holder)

	var brand_text := VBoxContainer.new()
	brand_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_text.add_theme_constant_override("separation", 0)
	brand.add_child(brand_text)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 3)
	brand_text.add_child(title_row)
	var wordmark := _label(title_row, "terra", 40, TEXT, _display_bold)
	wordmark.add_theme_constant_override("outline_size", 0)
	wordmark.custom_minimum_size.y = 35
	wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var reg_box := MarginContainer.new()
	reg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reg_box.add_theme_constant_override("margin_top", 6)
	title_row.add_child(reg_box)
	var registered := _label(reg_box, "®", 12, TEXT, _sans)
	var subtitle := _label(brand_text, "四方瓷韵 · 瓷器工坊", 12, TEXT, _bold)
	subtitle.add_theme_color_override("font_color", TEXT)

	# Day pill, centred at 47% of the bar (style.css .day-pill).
	_day_pill = HBoxContainer.new()
	_day_pill.name = "DayPill"
	_day_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_day_pill.anchor_left = 0.47
	_day_pill.anchor_right = 0.47
	_day_pill.offset_left = -170
	_day_pill.offset_right = 170
	_day_pill.offset_top = 0
	_day_pill.offset_bottom = TOPBAR_HEIGHT
	_day_pill.alignment = BoxContainer.ALIGNMENT_CENTER
	_day_pill.add_theme_constant_override("separation", 12)
	_topbar.add_child(_day_pill)

	var sun := _label(_day_pill, "☀", 32, Color("b98544"), _sans)
	sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var day_text := VBoxContainer.new()
	day_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	day_text.add_theme_constant_override("separation", 0)
	_day_pill.add_child(day_text)
	var short: String = _site.get("short", "古窑民俗")
	var decal: String = _site.get("decal", "青花缠枝纹")
	var day_title := _label(day_text, short, 12, TEXT, _sans)
	day_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var day_small := _label(day_text, "场景 %d / %d · %s" % [
		GameState.site_index + 1, maxi(ContentPack.available_site_ids().size(), 1), decal,
	], 12, Color("8c8d7b"), _bold)
	day_small.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Top actions: wallet + four icon buttons, right aligned.
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.offset_left = -520
	actions.offset_right = -32
	actions.offset_top = 0
	actions.offset_bottom = TOPBAR_HEIGHT
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	_topbar.add_child(actions)

	var wallet := HBoxContainer.new()
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_theme_constant_override("separation", 10)
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(wallet)
	var coin := _label(wallet, "◉", 26, GOLD, _sans)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wallet_text := VBoxContainer.new()
	wallet_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_text.add_theme_constant_override("separation", 0)
	wallet.add_child(wallet_text)
	_label(wallet_text, "当前硬币", 10, Color("797c6d"), _bold)
	var money_row := HBoxContainer.new()
	money_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_row.add_theme_constant_override("separation", 3)
	wallet_text.add_child(money_row)
	_money_label = _label(money_row, str(GameState.coins), 24, TEXT, _display_bold)
	var coin_unit := _label(money_row, "硬币", 12, TEXT, _sans)
	coin_unit.size_flags_vertical = Control.SIZE_SHRINK_END

	_action_button(actions, "↑  升级", 76)
	_action_button(actions, "⌖  地图", 76)
	_icon_button(actions, "♪")
	_icon_button(actions, "EN")
	_icon_button(actions, "?")


func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.name = "Commissions"
	_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	_rail.anchor_left = 1.0
	_rail.anchor_right = 1.0
	_rail.anchor_top = 0.0
	_rail.anchor_bottom = 1.0
	_rail.offset_left = -(RAIL_RIGHT + RAIL_WIDTH)
	_rail.offset_right = -RAIL_RIGHT
	_rail.offset_top = RAIL_TOP
	_rail.offset_bottom = -(BOTTOMBAR_HEIGHT + 10)
	_rail.add_theme_constant_override("separation", 12)
	add_child(_rail)

	# Scene heading + four chapter chips.
	_label(_rail, "瓷器之旅 · %d / %d" % [
		GameState.site_index + 1, maxi(ContentPack.available_site_ids().size(), 1),
	], 11, Color("89907b"), _bold)
	_scene_title = _label(_rail, _site.get("short", "古窑民俗"), 25, TEXT, _display)
	_scene_title.custom_minimum_size.y = 30

	var path := HBoxContainer.new()
	path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path.add_theme_constant_override("separation", 7)
	_rail.add_child(path)
	for i in 4:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(40, 27)
		var chip_style := StyleBoxFlat.new()
		chip_style.set_corner_radius_all(6)
		chip_style.bg_color = GREEN if i == GameState.site_index else Color(1, 1, 1, 0.0)
		chip_style.border_width_left = 1
		chip_style.border_width_top = 1
		chip_style.border_width_right = 1
		chip_style.border_width_bottom = 1
		chip_style.border_color = BORDER
		chip.add_theme_stylebox_override("panel", chip_style)
		var num := _label(chip, "%02d" % (i + 1), 11,
			Color("fff9e8") if i == GameState.site_index else Color("8b917d"), _bold)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		path.add_child(chip)

	_build_reference_card()
	_rail_gap(8)
	_build_preset_path()
	_rail_gap(14)
	_build_decal_goal()

	var hit := PanelContainer.new()
	var hit_style := StyleBoxFlat.new()
	hit_style.bg_color = Color(0, 0, 0, 0)
	hit_style.set_corner_radius_all(6)
	hit_style.content_margin_left = 4
	hit_style.content_margin_right = 4
	hit_style.content_margin_top = 4
	hit_style.content_margin_bottom = 4
	hit.add_theme_stylebox_override("panel", hit_style)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.gui_input.connect(_on_collection_input)
	_rail.add_child(hit)
	var collection := HBoxContainer.new()
	collection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(collection)
	_label(collection, "我的瓷器藏品", 12, Color("7d8471"), _sans)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection.add_child(spacer)
	_collection_value = _label(collection, "%d / 4" % _found_count(), 12, TEXT, _bold)


func _found_count() -> int:
	return int(SaveGame.data.get("codex", {}).get("discovered", []).size())


func refresh_codex() -> void:
	if _collection_value != null:
		_collection_value.text = "%d / 4" % _found_count()


func _on_collection_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		codex_requested.emit()


func _build_reference_card() -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _card_style()
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	_rail.add_child(card)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_level_label = _label(head, "第 %d 关 / 3" % (GameState.order_index + 1), 11, SOFT, _bold)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_label(head, "80% 通关", 11, SOFT, _bold)

	var art_holder := PanelContainer.new()
	art_holder.custom_minimum_size = Vector2(0, 150)
	art_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art_holder.clip_contents = true
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("f1e8d2")
	art_style.set_corner_radius_all(6)
	art_holder.add_theme_stylebox_override("panel", art_style)
	box.add_child(art_holder)
	var art := TextureRect.new()
	art.texture = load(PRESET_PATH % clampi(GameState.order_index, 0, 2))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reference_art = art
	art_holder.add_child(art)

	var name: String = _order.get("name", "一抹青花罐")
	_order_name_label = _label(box, name, 13, TEXT, _bold)
	_label(box, "60% 起奖励 · 首次通关 +60 币", 11, SOFT, _sans)
	var note := PanelContainer.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color(0.93, 0.95, 0.9, 0.65)
	note_style.set_corner_radius_all(6)
	note_style.content_margin_left = 8
	note_style.content_margin_right = 8
	note_style.content_margin_top = 5
	note_style.content_margin_bottom = 5
	note.add_theme_stylebox_override("panel", note_style)
	box.add_child(note)
	var note_text := _label(note, "五分钟内通过，订单收益 +20%", 10, Color("6f8261"), _sans)
	note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "查看订单  ↗", 11, Color("6f8261"), _bold)


func _build_preset_path() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_rail.add_child(row)
	for i in 3:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(70, 76)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := _card_style()
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		if i == GameState.order_index:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color("bd8953")
		cell.add_theme_stylebox_override("panel", style)
		row.add_child(cell)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 0)
		cell.add_child(stack)
		var thumb := TextureRect.new()
		thumb.texture = load(PRESET_PATH % i)
		thumb.custom_minimum_size = Vector2(58, 54)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(thumb)
		var num := _label(stack, str(i + 1), 10, SOFT, _bold)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_decal_goal() -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _card_style()
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	_rail.add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var decal := TextureRect.new()
	decal.texture = load(DECAL_PATH % [GameState.site_index + 1, DECAL_FILES[clampi(GameState.site_index, 0, 3)]])
	decal.custom_minimum_size = Vector2(46, 46)
	decal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(decal)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_label(text, "本场景贴画 · 400 币", 10, SOFT, _sans)
	_label(text, _site.get("decal", "青花缠枝纹"), 12, TEXT, _bold)
	_label(text, "0/3 关 · 0/400 币", 10, Color("9b7856"), _sans)
	_label(row, "↗", 13, Color("7d8471"), _sans)


func _build_guide() -> void:
	_guide = PanelContainer.new()
	_guide.name = "GuideCard"
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.anchor_left = 0.0
	_guide.anchor_top = 1.0
	_guide.anchor_right = 0.0
	_guide.anchor_bottom = 1.0
	_guide.offset_left = 27
	_guide.offset_right = 27 + 352
	_guide.offset_top = -(80 + 104)
	_guide.offset_bottom = -80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.973, 0.961, 0.918, 0.92)
	style.set_corner_radius_all(12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("faf8ee")
	style.content_margin_left = 13
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.369, 0.376, 0.231, 0.047)
	style.shadow_size = 14
	_guide.add_theme_stylebox_override("panel", style)
	add_child(_guide)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_guide.add_child(row)

	var number_panel := PanelContainer.new()
	number_panel.custom_minimum_size = Vector2(34, 34)
	number_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var number_style := StyleBoxFlat.new()
	number_style.bg_color = GREEN_SOFT
	number_style.set_corner_radius_all(8)
	number_panel.add_theme_stylebox_override("panel", number_style)
	row.add_child(number_panel)
	_guide_number = _label(number_panel, "01", 13, Color("738164"), _display)
	_guide_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	_guide_kicker = _label(text, "开始你的第一件作品", 11, Color("8e9481"), _bold)
	_guide_title = _label(text, "从一抔瓷泥开始", 13, TEXT, _bold)
	_guide_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_copy = _label(text, "去取泥台领取瓷泥。", 12, Color("868878"), _sans)
	_guide_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_bottom_bar() -> void:
	var bar := Panel.new()
	bar.name = "BottomBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -BOTTOMBAR_HEIGHT
	bar.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.937, 0.925, 0.882, 0.63)
	style.border_width_top = 1
	style.border_color = Color(0.824, 0.835, 0.769, 0.47)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_right = -30
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var controls := HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	row.add_child(controls)
	_key(controls, "W")
	_key(controls, "A")
	_key(controls, "S")
	_key(controls, "D")
	_label(controls, " / 方向键  移动", 11, Color("8b9180"), _sans)
	_spacer(controls, 18)
	_key(controls, "F")
	_label(controls, " 操作", 11, Color("8b9180"), _sans)
	_spacer(controls, 18)
	_label(controls, "左键旋转 · 滚轮缩放", 11, Color("8b9180"), _sans)
	_spacer(controls, 18)
	_key(controls, "Esc")
	_label(controls, " 退出面板", 11, Color("8b9180"), _sans)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var tag := HBoxContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.alignment = BoxContainer.ALIGNMENT_CENTER
	tag.add_theme_constant_override("separation", 7)
	row.add_child(tag)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color("8e9e78")
	dot_style.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", dot_style)
	tag.add_child(dot)
	_label(tag, "四方瓷韵", 11, Color("8a917d"), _sans)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(26, 20)
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("dce1d1")
	chip_style.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", chip_style)
	tag.add_child(chip)
	var chip_label := _label(chip, "05", 10, Color("7d8471"), _bold)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_reset_button() -> void:
	var button := Button.new()
	button.text = "↺  恢复视角"
	button.name = "ResetView"
	button.position = Vector2(20, TOPBAR_HEIGHT + 20)
	button.custom_minimum_size = Vector2(108, 34)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("56604f"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.973, 0.961, 0.918, 0.88) if state == "normal" else Color(0.91, 0.93, 0.87, 0.95)
		style.set_corner_radius_all(17)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color("d9dccf")
		button.add_theme_stylebox_override(state, style)
	add_child(button)
	button.pressed.connect(_on_reset_view)


func _on_reset_view() -> void:
	reset_view_requested.emit()


func _on_coins_changed(coins: int) -> void:
	if _money_label != null:
		_money_label.text = str(coins)


## Called by the main scene when the player state changes, so the guide card keeps
## the same copy branches as the legacy HUD (main.js:100).
func set_guide(number: String, kicker: String, title: String, copy: String) -> void:
	if _guide_number == null:
		return
	_guide_number.text = number
	_guide_kicker.text = kicker
	_guide_title.text = title
	_guide_copy.text = copy


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.843, 0.843, 0.78, 0.65)
	return style


func _action_button(parent: Control, text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", _sans)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("56604f"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.0) if state == "normal" else Color(0.87, 0.89, 0.83, 0.8)
		style.set_corner_radius_all(8)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color("d4d5c6")
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	return button


func _icon_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(34, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", _sans)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("56604f"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.0) if state == "normal" else Color(0.87, 0.89, 0.83, 0.8)
		style.set_corner_radius_all(17)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color("d4d5c6")
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	return button


func _key(parent: Control, text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(26, 28)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(4)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("d2d6c5")
	style.shadow_color = Color("d9dcca")
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := _label(panel, text, 11, Color("717966"), _bold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(parent: Control, text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", roundi(size * FONT_SCALE))
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _rail_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.add_child(gap)


func _spacer(parent: Control, width: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func set_order(name: String, index: int, total: int) -> void:
	if _order_name_label != null:
		_order_name_label.text = name
	if _level_label != null:
		_level_label.text = "第 %d 关 / %d" % [index, total]
	if _reference_art != null:
		_reference_art.texture = load(PRESET_PATH % clampi(index - 1, 0, 2))
