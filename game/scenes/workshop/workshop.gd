extends Node3D
## 古窑手作坊：垂直切片的主场景。
##
## 一条完整的闭环：接单 → 揉泥/拉坯/雕刻/上色（像素画布）→ 控火烧制 → 交付结算。
## 数值全部来自 Sculpture / Workshop / KilnRun（已与 JS 版逐值对拍），
## 这里只负责编排与呈现。

const BENCHES: PackedStringArray = ["clay", "wheel", "carve", "paint", "kiln", "serve"]
const BENCH_NAMES := {
	"clay": "揉泥台",
	"wheel": "拉坯台",
	"carve": "雕刻台",
	"paint": "上色台",
	"kiln": "窑炉",
	"serve": "交付台",
}
const BENCH_SPACING := 1.6
const ORDER_BASE_INCOME := 60

var orders: Array = []
var order_index := 0
var session: SculptSession
var kiln: KilnRun
var kiln_level := 1
var serve_level := 1
var total_earned := 0

var _station := "clay"
var _benches: Array[Node] = []
var _camera: Camera3D
var _rig: Node3D
var _canvas: SculptCanvas
var _heat_bar: HeatBar
var _score_bar: ProgressBar
var _order_label: Label
var _coins_label: Label
var _task_label: Label
var _hint_label: Label
var _status_label: Label
var _grade_label: Label
var _stroke_count := 0
var _served := false
var _kiln_started := false
var _kiln_panel: Control
var _round_panel: Control
var _round_summary: Label
var _finished_ids := {}


func _ready() -> void:
	_build_3d()
	_build_hud()
	_start_order()
	print("[Workshop] WORKSHOP_OK 古窑手作坊已就绪，订单 %d 单" % orders.size())
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if text.begins_with("station="):
			_select_station(text.substr(8))
		elif text == "roundend":
			_show_round_end()
		elif text.begins_with("shot="):
			_capture_after_frames(text.substr(5))


## 调试用：截图存盘后退出。`-- shot=D:/path/shot.png`（需非 headless 运行）。
func _capture_after_frames(path: String) -> void:
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[Workshop] SHOT_OK %s err=%d" % [path, error])
	get_tree().quit(0 if error == OK else 1)


# --- 3D ---


func _build_3d() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.13, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 1.1
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -34, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 12)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.22, 0.25)
	material.roughness = 0.95
	ground.material_override = material
	ground.position = Vector3(0, -0.02, 0)
	add_child(ground)

	_rig = Node3D.new()
	_rig.position = Vector3(-1.0, 0, 0)
	add_child(_rig)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_rig.add_child(_camera)
	_camera.position = Vector3(0, 5.2, 16.5)
	_camera.look_at(Vector3(0, 1.2, 0))

	for i in BENCHES.size():
		var id := BENCHES[i]
		var path := "res://assets/models/workbenches/%s.glb" % id
		if not ResourceLoader.exists(path):
			push_warning("[Workshop] 缺少工作台模型：" + path)
			continue
		var packed: PackedScene = load(path)
		var node := packed.instantiate()
		node.name = "Bench_" + id
		node.position = Vector3((i - (BENCHES.size() - 1) * 0.5) * BENCH_SPACING, 0, 0)
		node.rotation_degrees.y = -16.0
		add_child(node)
		_benches.append(node)
		_apply_tier_visibility(node, 1)


## GLB 里每个零件带 tier 元数据；这里只显示当前等级允许的部分。
func _apply_tier_visibility(node: Node, level: int) -> void:
	if node.has_meta("tier") and int(node.get_meta("tier")) > level:
		node.visible = false
	for child in node.get_children():
		_apply_tier_visibility(child, level)


func _focus_bench(index: int) -> void:
	var target_x := -1.0
	if index >= 0 and index < _benches.size():
		target_x = -1.0 + _benches[index].position.x * 0.1
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "position:x", target_x, 0.28)


# --- HUD ---


## 半透明深色面板样式，保证 3D 场景不会透过 HUD 干扰阅读。
func _panel_style(alpha := 0.94) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.14, alpha)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.09)
	return style


func _build_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif"
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)

	# 顶栏
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.offset_bottom = 74
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	_order_label = Label.new()
	_order_label.text = "古窑手作坊"
	top_row.add_child(_order_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	_coins_label = Label.new()
	top_row.add_child(_coins_label)

	# 画布
	var canvas_panel := PanelContainer.new()
	canvas_panel.add_theme_stylebox_override("panel", _panel_style())
	canvas_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	canvas_panel.offset_left = 24
	canvas_panel.offset_top = -270
	canvas_panel.offset_right = 560
	canvas_panel.offset_bottom = 280
	root.add_child(canvas_panel)
	_canvas = SculptCanvas.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_panel.add_child(_canvas)
	_canvas.stroke_finished.connect(_on_stroke_finished)
	_canvas.stroke_changed.connect(_on_stroke_changed)

	# 右侧面板
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", _panel_style())
	side.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	side.offset_left = -372
	side.offset_right = -24
	side.offset_top = -280
	side.offset_bottom = 280
	root.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side.add_child(side_box)

	var title := Label.new()
	title.text = "本单要求"
	side_box.add_child(title)

	_task_label = Label.new()
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_label.custom_minimum_size = Vector2(300, 96)
	side_box.add_child(_task_label)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.modulate = Color(1, 1, 1, 0.65)
	_hint_label.custom_minimum_size = Vector2(300, 64)
	side_box.add_child(_hint_label)

	_score_bar = ProgressBar.new()
	_score_bar.min_value = 0
	_score_bar.max_value = 100
	_score_bar.value = 0
	_score_bar.show_percentage = false
	_score_bar.custom_minimum_size = Vector2(300, 26)
	side_box.add_child(_score_bar)

	_status_label = Label.new()
	_status_label.text = "评分 0.0 / 80"
	side_box.add_child(_status_label)

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	side_box.add_child(tool_row)
	for tool in [["cut", "刮刀"], ["add", "补泥"], ["paint", "画笔"]]:
		var button := Button.new()
		button.text = String(tool[1])
		button.pressed.connect(_pick_tool.bind(String(tool[0])))
		tool_row.add_child(button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	side_box.add_child(action_row)
	var undo := Button.new()
	undo.text = "撤销"
	undo.pressed.connect(_on_undo)
	action_row.add_child(undo)
	var redo := Button.new()
	redo.text = "重做"
	redo.pressed.connect(_on_redo)
	action_row.add_child(redo)
	var clear := Button.new()
	clear.text = "重取泥"
	clear.pressed.connect(_on_reset)
	action_row.add_child(clear)

	_grade_label = Label.new()
	_grade_label.text = "尚未烧制"
	side_box.add_child(_grade_label)

	var serve_spacer := Control.new()
	serve_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(serve_spacer)

	var serve_button := Button.new()
	serve_button.text = "交付这一单"
	serve_button.custom_minimum_size = Vector2(300, 44)
	serve_button.pressed.connect(_on_serve)
	side_box.add_child(serve_button)

	# 窑炉面板
	var kiln_panel := PanelContainer.new()
	kiln_panel.name = "KilnPanel"
	kiln_panel.add_theme_stylebox_override("panel", _panel_style())
	kiln_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	kiln_panel.offset_left = -230
	kiln_panel.offset_right = 230
	kiln_panel.offset_top = -215
	kiln_panel.offset_bottom = 215
	kiln_panel.visible = false
	root.add_child(kiln_panel)
	_kiln_panel = kiln_panel
	var kiln_box := VBoxContainer.new()
	kiln_box.add_theme_constant_override("separation", 10)
	kiln_panel.add_child(kiln_box)
	var kiln_title := Label.new()
	kiln_title.text = "窑火 · 按住鼓风，把热度压在带里"
	kiln_box.add_child(kiln_title)
	_heat_bar = HeatBar.new()
	_heat_bar.custom_minimum_size = Vector2(400, 220)
	kiln_box.add_child(_heat_bar)
	var stoke := Button.new()
	stoke.text = "鼓风（按住）"
	stoke.custom_minimum_size = Vector2(400, 48)
	stoke.button_down.connect(_on_stoke_down)
	stoke.button_up.connect(_on_stoke_up)
	kiln_box.add_child(stoke)
	var kiln_status := Label.new()
	kiln_status.name = "KilnStatus"
	kiln_status.text = "点拉坯台上的窑，12 秒内控火"
	kiln_box.add_child(kiln_status)

	# 一日打烊结算面板
	var round_root := Control.new()
	round_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	round_root.visible = false
	root.add_child(round_root)
	_round_panel = round_root
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	round_root.add_child(dim)
	var round_panel := PanelContainer.new()
	round_panel.name = "RoundPanel"
	round_panel.add_theme_stylebox_override("panel", _panel_style(0.98))
	round_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	round_panel.offset_left = -260
	round_panel.offset_right = 260
	round_panel.offset_top = -120
	round_panel.offset_bottom = 120
	round_root.add_child(round_panel)
	var round_box := VBoxContainer.new()
	round_box.alignment = BoxContainer.ALIGNMENT_CENTER
	round_box.add_theme_constant_override("separation", 14)
	round_panel.add_child(round_box)
	var round_title := Label.new()
	round_title.text = "今日打烊"
	round_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_box.add_child(round_title)
	_round_summary = Label.new()
	_round_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	round_box.add_child(_round_summary)
	var again := Button.new()
	again.text = "再来一天"
	again.custom_minimum_size = Vector2(240, 44)
	again.pressed.connect(_on_next_day)
	round_box.add_child(again)

	# 底部工位切换
	var tabs := HBoxContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tabs.offset_left = -420
	tabs.offset_right = 420
	tabs.offset_top = -68
	tabs.offset_bottom = -16
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for id in BENCHES:
		var button := Button.new()
		button.text = String(BENCH_NAMES[id])
		button.custom_minimum_size = Vector2(128, 44)
		button.pressed.connect(_select_station.bind(String(id)))
		tabs.add_child(button)


# --- 订单流程 ---


func _start_order() -> void:
	orders = _load_orders()
	session = SculptSession.new(StringName(String(orders[order_index]["id"])), 1)
	session.radius = 18.0
	_canvas.set_session(session)
	_served = false
	_kiln_started = false
	kiln = null
	_grade_label.text = "尚未烧制"
	_session_reset()
	_update_hud()
	_select_station("clay")


func _load_orders() -> Array:
	var items: Array = Catalog.items_for_site(Catalog.load_catalog())
	if items.is_empty():
		# 兜底：catalog 读不到时至少还能玩一单
		return [{"id": "band-pot", "name": "一抹青花罐", "task": "做一个圆润的罐子，中间画一条宽蓝带。", "hint": ""}]
	var result: Array = []
	for item in items:
		result.append({
			"id": String(item.get("id", "band-pot")),
			"name": String(item.get("name", "瓷器")),
			"task": String(item.get("task", "")),
			"hint": String(item.get("hint", "")),
		})
	return result.slice(0, mini(3, result.size()))


func _select_station(id: String) -> void:
	_station = id
	var index := BENCHES.find(id)
	_focus_bench(index)
	var is_kiln := id == "kiln"
	var panel: Node = _canvas.get_parent()
	if panel is Control:
		(panel as Control).visible = not is_kiln and id != "serve"
	if _kiln_panel != null:
		_kiln_panel.visible = is_kiln
	_canvas.tool = SculptSession.station_tool(id)
	session.radius = 18.0 if _canvas.tool == "push" else _canvas.brush_radius
	_canvas.refresh()
	if is_kiln and not _kiln_started:
		_start_kiln()
	_update_hud()


func _pick_tool(tool: String) -> void:
	_canvas.tool = tool
	session.radius = 18.0 if tool == "push" else _canvas.brush_radius


func _session_reset() -> void:
	_canvas.refresh()
	_update_score()


func _on_stroke_changed() -> void:
	_stroke_count += 1
	_update_score()


func _on_stroke_finished() -> void:
	_update_score()


func _on_undo() -> void:
	if session.undo():
		_canvas.refresh()
		_update_score()


func _on_redo() -> void:
	if session.redo():
		_canvas.refresh()
		_update_score()


func _on_reset() -> void:
	session.reset()
	_canvas.refresh()
	_update_score()


func _update_score() -> void:
	var result := session.score()
	_score_bar.value = float(result["score"])
	_status_label.text = "评分 %.1f / 80（形状 %.1f · 上色 %.1f）" % [
		float(result["score"]), float(result["shape"]), float(result["paint"])
	]
	_score_bar.modulate = Color(1, 1, 1) if bool(result["passed"]) else Color(1.0, 0.72, 0.5)


func _update_hud() -> void:
	if order_index >= orders.size():
		return
	var order: Dictionary = orders[order_index]
	_order_label.text = "古窑手作坊 · %d/%d　%s" % [order_index + 1, orders.size(), order["name"]]
	_task_label.text = String(order["task"])
	_hint_label.text = String(order["hint"])
	_coins_label.text = "铜钱 %d" % GameState.coins


# --- 烧窑 ---


func _on_stoke_down() -> void:
	if kiln == null or kiln.finished():
		return
	kiln.stoking = true


func _on_stoke_up() -> void:
	if kiln == null:
		return
	kiln.stoking = false


func _start_kiln() -> void:
	_kiln_started = true
	kiln = KilnRun.new(Time.get_ticks_usec() & 0xFFFF, kiln_level)
	_heat_bar.run = kiln
	_grade_label.text = "烧制中…"
	_served = false


func _process(delta: float) -> void:
	if session != null:
		session.advance(delta * 1000.0)
	if kiln == null or kiln.finished():
		return
	kiln.tick(delta)
	var status := find_child("KilnStatus", true, false)
	if status is Label:
		(status as Label).text = "热度 %.0f%% · 完美 %.1fs · 良好 %.1fs" % [
			kiln.heat * 100.0, float(kiln.seconds["perfect"]), float(kiln.seconds["good"])
		]
	if not kiln.finished():
		return
	kiln.stoking = false
	var grade := kiln.grade()
	var names := {"perfect": "窑变 · 完美", "good": "火候 · 良好", "plain": "火候 · 一般"}
	_grade_label.text = "烧成：%s（火候 %.2f）" % [names.get(grade, grade), Workshop.fire_ratio(kiln.seconds)]
	Events.kiln_opened.emit({"grade": grade, "seconds": kiln.seconds})
	print("[Workshop] KILN_DONE grade=%s ratio=%.3f" % [grade, Workshop.fire_ratio(kiln.seconds)])


func _on_serve() -> void:
	if _served:
		return
	if kiln == null or not kiln.finished():
		_grade_label.text = "先去窑炉把这件烧出来"
		_select_station("kiln")
		return
	var result := session.score()
	var passed := bool(result["passed"])
	var order: Dictionary = orders[order_index]
	var first_pass := passed and not _finished_ids.has(order["id"])
	var income := Workshop.order_income(ORDER_BASE_INCOME * (1 if passed else 0.5), {
		"kiln": kiln_level,
		"serve": serve_level,
		"passed": passed,
		"elapsedMs": session.elapsed_ms,
		"eligible": true,
		"firstPass": first_pass,
	})
	_served = true
	_finished_ids[order["id"]] = true
	total_earned += int(income["earned"])
	GameState.add_coins(int(income["earned"]))
	GameState.discover(StringName(String(order["id"])))
	SaveGame.save_game()
	Events.sculpture_finished.emit(result)
	Events.item_sold.emit(int(income["earned"]), StringName(String(order["id"])))
	_grade_label.text = "成交！评分 %.1f，本单 +%d 铜钱（%s）" % [
		float(result["score"]),
		int(income["earned"]),
		"通过" if passed else "未达标",
	]
	print("[Workshop] SERVED score=%.1f earned=%d total=%d" % [float(result["score"]), int(income["earned"]), GameState.coins])
	_coins_label.text = "铜钱 %d" % GameState.coins
	order_index += 1
	if order_index >= orders.size():
		order_index = 0
		print("[Workshop] ALL_ORDERS_DONE 全部订单完成，铜钱 %d" % GameState.coins)
		_show_round_end()
		return
	_start_order()


## 三单做完：弹结算，等玩家点“再来一天”。
func _show_round_end() -> void:
	_round_summary.text = "今天成交 %d 单，进账 %d 铜钱。\n铜钱总数 %d，图鉴已收录 %d 件。" % [
		orders.size(), total_earned, GameState.coins,
		int(SaveGame.data.get("codex", {}).get("discovered", []).size()),
	]
	_round_panel.visible = true
	_kiln_panel.visible = false
	_canvas.get_parent().visible = false


func _on_next_day() -> void:
	_round_panel.visible = false
	_canvas.get_parent().visible = true
	total_earned = 0
	_finished_ids.clear()
	_start_order()
