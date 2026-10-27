class_name StationSheet
extends Control

## The station sheet of the legacy world: one cream card per station, opened with F.
## It is a pure view + input layer; the order/session/kiln state stays in Main.

signal closed
signal take_clay
signal finish_step(id: String)
signal stoke(started: bool)
signal deliver
signal next_round

const TEXT := Color("3a4239")
const MUTED := Color("858678")
const PAPER := Color("faf6eb")
const PAPER_SOFT := Color("f3edda")
const BORDER := Color("dcdacb")
const GREEN := Color("374e3c")
const GREEN_SOFT := Color("e0e5d3")

const CARD_SIZE := Vector2(980, 610)

var _dim: ColorRect
var _card: PanelContainer
var _close_button: Button
var _kicker: Label
var _title: Label
var _body: VBoxContainer
var _font_body: Font
var _font_title: Font

var _canvas: SculptCanvas
var _score_bar: ProgressBar
var _score_label: Label
var _heat: HeatBar
var _kiln_status: Label
var _stoke_button: Button
var _serve_label: Label

var _session: SculptSession
var _kiln: KilnRun
var _station := ""
var _order: Dictionary = {}
var _data: Dictionary = {}


func _ready() -> void:
	name = "StationSheet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_fonts()
	_build_card()


func _build_fonts() -> void:
	_font_body = _load_font("res://assets/fonts/DMSans-Variable.ttf")
	_font_title = _load_font("res://assets/fonts/Fraunces-Variable.ttf")


func _load_font(path: String) -> Font:
	var font: Font = load(path)
	if font == null:
		return ThemeDB.fallback_font
	var fallbacks := SystemFont.new()
	fallbacks.font_names = PackedStringArray([
		"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "sans-serif"
	])
	font.fallbacks = [fallbacks]
	return font


func _build_card() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.13, 0.11, 0.38)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.custom_minimum_size = CARD_SIZE
	_card.size = CARD_SIZE
	_card.offset_left = -CARD_SIZE.x * 0.5
	_card.offset_right = CARD_SIZE.x * 0.5
	_card.offset_top = -CARD_SIZE.y * 0.5
	_card.offset_bottom = CARD_SIZE.y * 0.5
	_card.add_theme_stylebox_override("panel", _paper_box())
	add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_card.add_child(column)

	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", 34)
	head.add_theme_constant_override("margin_right", 26)
	head.add_theme_constant_override("margin_top", 26)
	head.add_theme_constant_override("margin_bottom", 10)
	column.add_child(head)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 14)
	head.add_child(head_row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(titles)
	_kicker = _label("", 12, MUTED)
	titles.add_child(_kicker)
	_title = _label("", 30, TEXT, _font_title)
	titles.add_child(_title)
	var close := Button.new()
	_close_button = close
	close.text = "✕"
	close.flat = true
	close.custom_minimum_size = Vector2(40, 40)
	close.add_theme_font_override("font", _font_body)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", MUTED)
	close.pressed.connect(close_sheet)
	head_row.add_child(close)

	var rule := ColorRect.new()
	rule.color = BORDER
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 26)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_body)
	column.add_child(margin)


func _paper_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = Color("d8d2bf")
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.shadow_color = Color(0.15, 0.16, 0.13, 0.18)
	box.shadow_size = 24
	return box


func _label(text: String, size: int, color: Color,
		font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font != null else _font_body)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_override("font", _font_body)
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GREEN if primary else PAPER_SOFT
	normal.border_color = GREEN if primary else BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("4a6350") if primary else Color("eee6cf")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("fdfaf1") if primary else TEXT)
	return button


## Open the sheet for one station. `data` carries the live state:
## {has_clay, steps, fired, grade, session, kiln, passed}.
func present(station: String, order: Dictionary, data: Dictionary) -> void:
	_station = station
	_order = order
	_data = data
	if _close_button != null:
		_close_button.visible = true
	_session = data.get("session")
	_kiln = data.get("kiln")
	visible = true
	_kicker.text = "第 %d 关 / 3 · 订单「%s」" % [
		int(data.get("level", 1)), String(order.get("name", "瓷器"))]
	_title.text = _station_name(station)
	_clear_body()
	match station:
		"clay":
			_build_clay()
		"wheel", "carve", "paint":
			_build_sculpt(station)
		"kiln":
			_build_kiln()
		"serve":
			_build_serve()
		_:
			_build_clay()


func close_sheet() -> void:
	if _canvas != null:
		_canvas.queue_free()
		_canvas = null
	visible = false
	closed.emit()


func _station_name(id: String) -> String:
	var entry := SiteLayout.station(id)
	return String(entry.get("name", id))


func _clear_body() -> void:
	_canvas = null
	_heat = null
	_kiln_status = null
	_stoke_button = null
	_score_bar = null
	_serve_label = null
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


# --- 取泥 -----------------------------------------------------------------


func _build_clay() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(300, 300)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color("efe6cd")
	box.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", box)
	row.add_child(frame)
	var art := TextureRect.new()
	art.texture = load("res://assets/reference/preset-0.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(260, 260)
	frame.add_child(art)

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 12)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(_label("本单要求", 13, MUTED))
	var task := _label(String(_order.get("task", "")), 17, TEXT)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.custom_minimum_size = Vector2(0, 90)
	copy.add_child(task)
	var hint := _label(String(_order.get("hint", "")), 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(spacer)
	var take := _button("领取完整瓷泥", true)
	take.custom_minimum_size = Vector2(280, 44)
	take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	take.disabled = bool(_data.get("has_clay", false))
	take.text = "瓷泥已领取" if take.disabled else "领取完整瓷泥"
	take.pressed.connect(func():
		take_clay.emit()
		close_sheet())
	copy.add_child(take)


# --- 拉坯 / 雕刻 / 上色 ----------------------------------------------------


func _build_sculpt(station: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(430, 430)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER_SOFT
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", box)
	row.add_child(frame)
	_canvas = SculptCanvas.new()
	_canvas.background = Color("f3ecd9")
	_canvas.empty_color = Color("e2d6ba")
	_canvas.custom_minimum_size = Vector2(410, 410)
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(_canvas)
	_canvas.set_session(_session)
	_canvas.tool = SculptSession.station_tool(station)
	_session.radius = 18.0 if _canvas.tool == "push" else _canvas.brush_radius
	_canvas.refresh()
	_canvas.stroke_changed.connect(_refresh_score)
	_canvas.stroke_finished.connect(_refresh_score)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	var reference := TextureRect.new()
	reference.texture = load("res://assets/reference/preset-0.png")
	reference.custom_minimum_size = Vector2(118, 96)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ref_box := PanelContainer.new()
	var ref_style := StyleBoxFlat.new()
	ref_style.bg_color = Color("efe6cd")
	ref_style.set_corner_radius_all(6)
	ref_box.add_theme_stylebox_override("panel", ref_style)
	ref_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ref_box.add_child(reference)
	side.add_child(ref_box)
	side.add_child(_label(_station_hint(station), 14, MUTED))
	_score_bar = ProgressBar.new()
	_score_bar.max_value = 80
	_score_bar.show_percentage = false
	_score_bar.custom_minimum_size = Vector2(0, 12)
	side.add_child(_score_bar)
	_score_label = _label("", 14, TEXT)
	side.add_child(_score_label)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	side.add_child(tools)
	for tool in [["cut", "刮刀"], ["add", "补泥"], ["paint", "画笔"]]:
		var button := _button(String(tool[1]))
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(func():
			_canvas.tool = String(tool[0])
			_session.radius = 18.0 if _canvas.tool == "push" else _canvas.brush_radius)
		tools.add_child(button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	side.add_child(actions)
	for action in [["undo", "撤销"], ["redo", "重做"], ["reset", "重来"]]:
		var button := _button(String(action[1]))
		button.custom_minimum_size = Vector2(0, 34)
		var kind := String(action[0])
		button.pressed.connect(func(): _do_action(kind))
		actions.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var done := _button("完成这一道", true)
	done.custom_minimum_size = Vector2(280, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	done.pressed.connect(func():
		finish_step.emit(station)
		close_sheet())
	side.add_child(done)
	_refresh_score()


func _do_action(kind: String) -> void:
	match kind:
		"undo":
			_session.undo()
		"redo":
			_session.redo()
		"reset":
			_session.reset()
	_canvas.refresh()
	_refresh_score()


func _refresh_score() -> void:
	if _session == null or _score_bar == null:
		return
	var result := _session.score()
	_score_bar.value = float(result["score"])
	_score_label.text = "当前评分 %.1f / 80（通过线 60）" % float(result["score"])
	_score_label.add_theme_color_override("font_color",
		TEXT if bool(result["passed"]) else Color("b0603c"))


func _station_hint(station: String) -> String:
	match station:
		"wheel":
			return "按住拖拽把泥团推成罐形，轮廓越贴近参考越好。"
		"carve":
			return "用刮刀修掉多余泥料，让器形干净利落。"
		"paint":
			return "选画笔，把中间那条宽蓝带画上去。"
		_:
			return "调整到满意为止。"


# --- 窑炉 -----------------------------------------------------------------


func _build_kiln() -> void:
	_heat = HeatBar.new()
	_heat.custom_minimum_size = Vector2(0, 200)
	_heat.run = _kiln
	_body.add_child(_heat)
	_kiln_status = _label("按住鼓风，把热度压在暖色带里。", 14, TEXT)
	_body.add_child(_kiln_status)
	_stoke_button = _button("鼓风（按住）", true)
	_stoke_button.button_down.connect(func(): stoke.emit(true))
	_stoke_button.button_up.connect(func(): stoke.emit(false))
	_body.add_child(_stoke_button)


func tick(delta: float) -> void:
	if not visible:
		return
	if _station == "kiln" and _kiln != null:
		if not _kiln.finished():
			_kiln.tick(delta)
			if _kiln_status != null:
				_kiln_status.text = "热度 %.0f%% · 完美 %.1fs · 良好 %.1fs" % [
					_kiln.heat * 100.0,
					float(_kiln.seconds["perfect"]),
					float(_kiln.seconds["good"])]
			if _kiln.finished():
				_data["fired"] = true
				if _stoke_button != null:
					_stoke_button.disabled = true
				if _kiln_status != null:
					_kiln_status.text = "烧制完成 · 火候 %s" % _grade_text(_kiln.grade())
		elif _kiln_status != null:
			_kiln_status.text = "烧制完成 · 火候 %s" % _grade_text(_kiln.grade())
	if _station in ["wheel", "carve", "paint"] and _session != null:
		_session.advance(delta * 1000.0)


func _grade_text(grade: String) -> String:
	match grade:
		"perfect":
			return "完美"
		"good":
			return "良好"
		_:
			return "一般"


# --- 交付 -----------------------------------------------------------------


func _build_serve() -> void:
	var result: Dictionary = _data.get("result", {})
	var passed := bool(result.get("passed", false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(230, 230)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = Color("efe6cd")
	box.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", box)
	row.add_child(frame)
	var art := TextureRect.new()
	art.texture = load("res://assets/reference/preset-0.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(200, 200)
	frame.add_child(art)

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 8)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(_label("本单评分", 13, MUTED))
	_serve_label = _label("%.1f / 80" % float(result.get("score", 0.0)),
		50, TEXT, _font_title)
	copy.add_child(_serve_label)
	var verdict := "达标，可以交付" if passed else "还差一点，先回去修一修"
	copy.add_child(_label(verdict, 16, TEXT if passed else Color("b0603c")))
	copy.add_child(_label("形状 %.1f · 上色 %.1f · 用时 %.1fs" % [
		float(result.get("shape", 0.0)), float(result.get("paint", 0.0)),
		float(_data.get("elapsed", 0.0)) / 1000.0], 13, MUTED))
	var grade: String = String(_data.get("grade", ""))
	if grade != "":
		copy.add_child(_label("火候 · %s" % _grade_text(grade), 13, MUTED))
	var income: Dictionary = _data.get("income", {})
	if not income.is_empty():
		copy.add_child(_label("本单收益 +%d 铜钱" % int(income.get("earned", 0)),
			15, GREEN))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var deliver_button := _button("交付这一单", true)
	deliver_button.pressed.connect(func():
		deliver.emit()
		close_sheet())
	_body.add_child(deliver_button)


## 一日打烊：三单交付后盖在场景上的整屏结算。
func show_round(earned: int, coins: int, discovered: int) -> void:
	_station = "round"
	if _close_button != null:
		_close_button.visible = false
	_session = null
	_kiln = null
	visible = true
	_kicker.text = "古窑手艺人 · 一日"
	_title.text = "今日打烊"
	_clear_body()
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer_top)
	var total := _label("今天成交 3 单", 16, MUTED)
	_body.add_child(total)
	_body.add_child(_label("进账 %d 铜钱" % earned, 46, TEXT, _font_title))
	_body.add_child(_label("铜钱总数 %d · 图鉴已收录 %d 件" % [coins, discovered],
		15, MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var again := _button("再来一天", true)
	again.custom_minimum_size = Vector2(280, 46)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again.pressed.connect(func():
		next_round.emit()
		close_sheet())
	_body.add_child(again)
