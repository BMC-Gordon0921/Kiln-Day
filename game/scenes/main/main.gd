extends Control

## Main scene shell: gradient backdrop + 3D site in a transparent SubViewport + HUD layer.
## Mirrors the legacy DOM stack: #app gradient, #world-wrap canvas, task overlay above.

const BACKDROP_INNER := Color("f4f0e0")
const BACKDROP_OUTER := Color("e4e3d6")

## Legacy #world-wrap box: top 95px, bottom 58px, right 265px (see legacy style.css).
const TOPBAR_HEIGHT := 95.0
const BOTTOMBAR_HEIGHT := 58.0
const RIGHT_RAIL_WIDTH := 293.0
const MIN_WORLD_HEIGHT := 760.0

const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 inner : source_color = vec4(0.957, 0.941, 0.878, 1.0);
uniform vec4 outer : source_color = vec4(0.894, 0.890, 0.839, 1.0);
uniform vec2 center = vec2(0.4, 0.5);
uniform float radius = 0.78;
void fragment() {
    vec2 uv = SCREEN_UV - center;
    uv.x *= 0.92;
    float d = clamp(length(uv) / radius, 0.0, 1.0);
    COLOR = vec4(mix(inner.rgb, outer.rgb, smoothstep(0.0, 1.0, d)), 1.0);
}
"""

var world: SiteWorld
var world_view: SubViewportContainer
var world_viewport: SubViewport
var labels: WorldLabels
var prompt: InteractionPrompt
var site_hud: SiteHud
var ui_root: Control
var _ui_scale := 1.0
var hud_layer: CanvasLayer
var debug_label: Label

var sheet: StationSheet
var codex: CodexPanel
var session: SculptSession
var kiln: KilnRun
var orders: Array = []
var order_index := 0
var steps := {}
var fired := false
var grade := ""
var _finished_ids := {}

var _shot_path := ""
var _shot_frames := 40
var _elapsed := 0.0
var _f_held := false
var _scripted_axis := Vector2.ZERO
var _walk_target := Vector2.INF
var _pending_shot := false
var _autoplay_path := ""
var _autoplay_dir := ""
var _autoplay_active := false
var _bare := false
var _moved := false


func _ready() -> void:
	_build_backdrop()
	_build_ui_root()
	_build_world()
	_build_hud()
	# UIRoot must draw above the SubViewportContainer it was created before.
	move_child(ui_root, get_child_count() - 1)
	_resize()
	get_viewport().size_changed.connect(_resize)
	call_deferred("_start")


func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BACKDROP_SHADER
	material.shader = shader
	material.set_shader_parameter("inner", BACKDROP_INNER)
	material.set_shader_parameter("outer", BACKDROP_OUTER)
	backdrop.material = material
	add_child(backdrop)


func _build_ui_root() -> void:
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(ui_root)


func _build_world() -> void:
	var container := SubViewportContainer.new()
	container.name = "WorldView"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	world_view = container

	world_viewport = SubViewport.new()
	world_viewport.name = "SubViewport"
	world_viewport.transparent_bg = true
	world_viewport.own_world_3d = true
	world_viewport.msaa_3d = Viewport.MSAA_4X
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world_viewport)

	world = SiteWorld.new()
	world.name = "SiteWorld"
	world_viewport.add_child(world)


	labels = WorldLabels.new()
	labels.name = "StationLabels"
	ui_root.add_child(labels)
	labels.setup(world)

	# The legacy #interaction card lives inside #world-wrap, so it is a sibling of
	# the 3D view and shares its coordinate space.
	prompt = InteractionPrompt.new()
	prompt.name = "Interaction"
	ui_root.add_child(prompt)


## Keep the 3D viewport inside the same rectangle as the legacy #world-wrap.
func _layout_world() -> void:
	if world_view == null:
		return
	var size := get_viewport_rect().size
	# Keep the legacy 1600x900 proportions on bigger windows instead of letting
	# the HUD shrink relative to the scene.
	_ui_scale = clampf(minf(size.y / 900.0, size.x / 1600.0), 1.0, 1.8)
	var top := TOPBAR_HEIGHT * _ui_scale
	var bar := BOTTOMBAR_HEIGHT * _ui_scale
	var rail := RIGHT_RAIL_WIDTH * _ui_scale
	world_view.offset_left = 0.0
	world_view.offset_top = top
	world_view.offset_right = -rail
	world_view.offset_bottom = -bar
	if ui_root != null:
		ui_root.scale = Vector2(_ui_scale, _ui_scale)
		ui_root.size = size / _ui_scale
	if labels != null:
		labels.set_view(world_view.position, _ui_scale)


func _build_hud() -> void:
	site_hud = SiteHud.new()
	site_hud.codex_requested.connect(_open_codex)
	site_hud.name = "SiteHUD"
	ui_root.add_child(site_hud)

	hud_layer = CanvasLayer.new()
	hud_layer.name = "Debug"
	add_child(hud_layer)
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(16, TOPBAR_HEIGHT + 8)
	debug_label.add_theme_color_override("font_color", Color(0.23, 0.26, 0.23))
	debug_label.visible = OS.get_cmdline_user_args().has("hud")
	hud_layer.add_child(debug_label)

	sheet = StationSheet.new()
	sheet.name = "StationSheet"
	ui_root.add_child(sheet)
	sheet.take_clay.connect(_on_take_clay)
	sheet.finish_step.connect(_on_finish_step)
	sheet.stoke.connect(_on_stoke)
	sheet.deliver.connect(_on_deliver)
	sheet.next_round.connect(_on_next_round)


func _resize() -> void:
	_layout_world()
	if world == null or world.camera == null or world_view == null:
		return
	var size := world_view.size
	world.camera.apply_viewport(size.x, size.y)
	debug_label.text = "%d x %d" % [int(size.x), int(size.y)]


func _start() -> void:
	_start_order()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("shot="):
			_shot_path = arg.substr(5)
		elif arg.begins_with("autoplay="):
			_autoplay_path = arg.substr(9)
		elif arg.begins_with("autoplay-dir="):
			_autoplay_dir = arg.substr(13)
		elif arg.begins_with("level="):
			world.set_bench_level(int(arg.substr(6)))
		elif arg.begins_with("shade="):
			var parts := arg.substr(6).split(",")
			if parts.size() == 3:
				world.set_lighting(float(parts[0]), float(parts[1]), float(parts[2]))
		elif arg == "bare":
			_bare = true
			site_hud.visible = false
			labels.visible = false
			prompt.visible = false
		elif arg.begins_with("walkto="):
			var target := SiteLayout.station(arg.substr(7))
			if not target.is_empty():
				_walk_target = target["approach"]
		elif arg == "clay":
			# Test hook: jump straight to the "carrying clay" milestone so the
			# tutorial/next-station copy can be captured without playing.
			world.player.has_clay = true
		elif arg.begins_with("stage="):
			# Test hook: unlock the stations up to <stage>.
			world.player.has_clay = true
			steps["clay"] = true
			var stage := arg.substr(6)
			for id in ["wheel", "carve", "paint"]:
				steps[id] = true
				if id == stage:
					break
		elif arg.begins_with("open="):
			_open_station(arg.substr(5))
		elif arg == "codex":
			var items := Catalog.items_for_site(Catalog.load_catalog())
			if items.size() > 0:
				GameState.discover(StringName(items[0]["id"]))
			if items.size() > 1:
				GameState.discover(StringName(items[1]["id"]))
			_open_codex()
		elif arg.begins_with("screen="):
			_apply_screen(arg.substr(7))
		elif arg == "take":
			_on_take_clay()
		elif arg == "sell":
			world.player.has_clay = true
			steps["clay"] = true
			steps["wheel"] = true
			steps["carve"] = true
			steps["paint"] = true
			_start_kiln()
			kiln.elapsed = kiln.duration
			kiln.seconds["perfect"] = 2.0
			kiln.seconds["good"] = 1.0
			fired = true
			grade = kiln.grade()
			_on_deliver()
		elif arg == "fire":
			# Test hook: finish the kiln with a good fire.
			world.player.has_clay = true
			steps["clay"] = true
			steps["wheel"] = true
			steps["carve"] = true
			steps["paint"] = true
			_start_kiln()
			kiln.elapsed = kiln.duration
			kiln.seconds["perfect"] = 2.0
			kiln.seconds["good"] = 1.0
			fired = true
			grade = kiln.grade()
	_resize()
	if world.site_root == null:
		print("[Site] SITE_FAIL 站点模型未加载")
		return
	if world.camera:
		print("[Site] CAM size=%.4f viewport=%s pos=%s" % [
			world.camera.size, world_view.size, world.camera.position])
	if OS.get_cmdline_user_args().has("project"):
		if world._key_light:
			print("[Site] SHADOW enabled=%s energy=%.2f" % [
				world._key_light.shadow_enabled, world._key_light.light_energy])
		var casters := 0
		var receivers := 0
		var stack: Array[Node] = [world]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D:
				var mi := node as MeshInstance3D
				if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					casters += 1
				if mi.get_meta("receive", true):
					receivers += 1
			for child in node.get_children():
				stack.append(child)
		print("[Site] CASTERS=%d" % casters)
		for entry in SiteLayout.STATIONS:
			var pos := Vector3(entry["x"], SiteWorld.SITE_LIFT, entry["z"])
			var screen: Vector2 = world.camera.unproject_position(pos)
			print("[Site] PROJ %s %.2f %.2f" % [entry["id"], screen.x, screen.y])
		var corner := world.camera.unproject_position(Vector3(-10.0, SiteWorld.SITE_LIFT, 8.0))
		print("[Site] PROJ island_corner %.2f %.2f" % [corner.x, corner.y])
		get_tree().quit()
	var box := world.site_bounds()
	print("[Site] SITE_OK %s bounds=(%.2f, %.2f, %.2f)-(%.2f, %.2f, %.2f)" % [
		world.SITE_ID, box.position.x, box.position.y, box.position.z,
		box.end.x, box.end.y, box.end.z])
	if not _autoplay_path.is_empty():
		await _run_autoplay()
		return
	if _shot_path.is_empty():
		return
	await _capture()


## Replay `art/data/legacy-flow.json` step by step and write one PNG per state.
## This is the P2 capture harness: `-- autoplay=<json> [autoplay-dir=<dir>]`.
func _run_autoplay() -> void:
	var file := FileAccess.open(_autoplay_path, FileAccess.READ)
	if file == null:
		push_error("autoplay: cannot open %s" % _autoplay_path)
		get_tree().quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("flow"):
		push_error("autoplay: missing flow object")
		get_tree().quit(1)
		return
	var flow: Dictionary = parsed["flow"]
	var out_dir := _autoplay_dir
	if out_dir.is_empty():
		out_dir = _autoplay_path.get_base_dir().path_join("godot-flow")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ids := flow.keys()
	ids.sort()
	_autoplay_active = true
	for id in ids:
		var state: Dictionary = flow[id]
		_apply_flow_state(String(id), state)
		for i in 10:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		var path := out_dir.path_join("%s.png" % id)
		var error := image.save_png(path)
		print("[Site] AUTOPLAY %s err=%d" % [id, error])
	_autoplay_active = false
	get_tree().quit()


func _apply_flow_state(id: String, state: Dictionary) -> void:
	if sheet != null and sheet.visible:
		sheet.close_sheet()
	if codex != null and codex.visible:
		codex.visible = false
	var has_clay := bool(state.get("hasClay", false))
	if has_clay:
		var lump := Node3D.new()
		lump.name = "ClayLump"
		SiteProps.ball(lump, 0.0, 0.0, 0.0, 0.22, 0.18, 0.22, Color("f3e8d2"))
		world.player.set_carried(lump)
	else:
		world.player.set_carried(null)
	world.player.has_clay = has_clay
	steps.erase("clay")
	steps.erase("wheel")
	steps.erase("carve")
	steps.erase("paint")
	var has_shape := bool(state.get("hasShape", false))
	var has_paint := bool(state.get("hasPaint", false))
	if has_clay or has_shape:
		steps["clay"] = true
	if has_shape:
		steps["wheel"] = true
	if has_shape and has_paint:
		steps["carve"] = true
	if has_paint:
		steps["paint"] = true
	fired = bool(state.get("fired", false))
	if fired and not steps.has("paint"):
		steps["clay"] = true
		steps["wheel"] = true
		steps["carve"] = true
		steps["paint"] = true
	grade = "good" if fired else ""
	_guide_step = -1
	_update_guide()
	var station := _station_for_near(String(state.get("near", "")))
	if not station.is_empty():
		var entry := SiteLayout.station(station)
		if not entry.is_empty():
			world.player.teleport(entry["approach"].x, entry["approach"].y)
	var open := ""
	match id:
		"03-supply", "04-brief":
			open = "clay"
		"06-wheel", "06-wheel-stroked":
			open = "wheel"
		"07-carve", "07-carve-stroked":
			open = "carve"
		"08-paint", "08-paint-stroked":
			open = "paint"
		"09-kiln":
			open = "kiln"
		"11-review":
			open = "serve"
	if not open.is_empty():
		_open_station(open)


func _station_for_near(near: String) -> String:
	match near:
		"取泥台", "领取与订单", "领取与订单台":
			return "clay"
		"取泥台 · 领取订单", "取泥与订单":
			return "clay"
		"拉坯台", "拉坯机", "拉坯与塑形":
			return "wheel"
		"刻花台", "细节雕刻":
			return "carve"
		"彩绘台", "手绘上色":
			return "paint"
		"窑炉", "瓷器窑炉":
			return "kiln"
		"提交台", "提交作品", "评分与交付":
			return "serve"
	if near.contains("泥"):
		return "clay"
	if near.contains("坯") or near.contains("塑"):
		return "wheel"
	if near.contains("刻"):
		return "carve"
	if near.contains("绘") or near.contains("彩"):
		return "paint"
	if near.contains("窑"):
		return "kiln"
	if near.contains("提交") or near.contains("交付"):
		return "serve"
	return ""


func _capture() -> void:
	# A scripted walk needs real frames to finish (the character moves at
	# WALK_SPEED through the same code path as the keyboard).
	if _walk_target != Vector2.INF:
		for i in 600:
			await get_tree().process_frame
			if _walk_target.distance_to(world.player.position2d) < 0.55:
				break
	for i in _shot_frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	print("[Site] SHOT_OK %s err=%d" % [_shot_path, error])
	get_tree().quit()


func _process(delta: float) -> void:
	if world == null or world.player == null or world.camera == null:
		return
	_elapsed += delta
	if sheet != null and sheet.visible:
		sheet.tick(delta)
		if kiln != null and kiln.finished() and not fired:
			fired = true
			grade = kiln.grade()
			Events.kiln_opened.emit({"grade": grade, "seconds": kiln.seconds})
			_guide_step = -1
			_update_guide()
		if prompt.visible:
			prompt.visible = false
		if _toast_label != null:
			_toast_label.visible = false
		return
	var axis := _read_axis()
	if axis.length_squared() > 1.0:
		axis = axis.normalized()
	world.player.move(axis.x, axis.y, delta, world.camera)
	world.player.update_world(_elapsed)
	world.hint.update_world(_elapsed, true, _next_station())
	_drive_scripted_walk()
	_update_prompt()
	_update_guide()
	if _pending_shot:
		_pending_shot = false
		_capture()


## Keyboard: WASD and the arrow keys both drive the same axis (legacy input map).
func _read_axis() -> Vector2:
	if _scripted_axis != Vector2.ZERO:
		return _scripted_axis
	var axis := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		axis.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		axis.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		axis.y += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		axis.y -= 1.0
	return axis


## Test hook: feed the walk code path with an axis pointing at the target, so the
## screenshots exercise real movement instead of teleporting the actor.
func _drive_scripted_walk() -> void:
	if _walk_target == Vector2.INF:
		return
	var delta := _walk_target - world.player.position2d
	if delta.length() < 0.35:
		_scripted_axis = Vector2.ZERO
		return
	var axes := SiteMotion.camera_axes(world.camera)
	var right: Vector3 = axes[0]
	var forward: Vector3 = axes[1]
	_scripted_axis = Vector2(
		delta.x * right.x + delta.y * right.z,
		delta.x * forward.x + delta.y * forward.z
	).normalized()


## Legacy main.js:322-323 — the card floats above the head at world y=2.25 and its
## copy comes from stationMessage().
func _update_prompt() -> void:
	if prompt == null or _bare:
		return
	if world.player != null and world.player.moving:
		_moved = true
	var nearest := SiteLayout.nearest(world.player.position2d.x, world.player.position2d.y)
	if nearest.is_empty() or not _moved:
		if prompt.visible:
			prompt.visible = false
		labels.set_next_visible(true)
		labels.set_avoid_rect(Rect2())
		_f_held = false
		return
	var head := Vector3(world.player.position2d.x, 2.25 + SiteWorld.SITE_LIFT,
			world.player.position2d.y)
	var screen: Vector2 = world.camera.unproject_position(head)
	prompt.show_for(str(nearest["id"]), true, _prompt_state())
	prompt.place_at(screen, world_view.size.x)
	# The callout and the F card would otherwise draw on top of each other.
	labels.set_next_visible(false)
	labels.set_avoid_rect(prompt.blocking_rect())

	var pressed := Input.is_physical_key_pressed(KEY_F)
	if pressed and not _f_held and (sheet == null or not sheet.visible):
		print("[Site] INTERACT %s" % nearest["id"])
		_open_station(String(nearest["id"]))
	_f_held = pressed


## Placeholder until the campaign state lands (Step 5): everything is unlocked.
func _prompt_state() -> Dictionary:
	var finished := kiln != null and kiln.finished()
	return {
		"fired": fired,
		"kiln": kiln != null,
		"kiln_result": finished,
		"can_work": true,
	}


## The guide card walks the same seven beats as the legacy tour.
var _guide_step := -1
var _toast_label: Label

const GUIDE := [
	{"num": "01", "kicker": "开始你的第一件作品", "title": "从一抔瓷泥开始",
		"copy": "去取泥台领取瓷泥。"},
	{"num": "02", "kicker": "新手教学 · 2 / 7", "title": "把瓷泥送上拉坯台",
		"copy": "走近「粗塑成形」台，按 F 开始揉泥、拉坯。"},
	{"num": "03", "kicker": "新手教学 · 3 / 7", "title": "修出干净的器形",
		"copy": "去「细节雕刻」台，用刮刀修掉多余泥料。"},
	{"num": "04", "kicker": "新手教学 · 4 / 7", "title": "给罐子画上青花",
		"copy": "去「手绘上色」台，画上中间那条宽蓝带。"},
	{"num": "05", "kicker": "新手教学 · 5 / 7", "title": "入窑烧制",
		"copy": "去「瓷器窑炉」按 F，按住鼓风把热度压在带里。"},
	{"num": "06", "kicker": "新手教学 · 6 / 7", "title": "交付这一单",
		"copy": "去「评分与交付」按 F，看看这窑的成色。"},
]


func _update_guide() -> void:
	if site_hud == null or world.player == null:
		return
	var step := _step()
	if step == _guide_step:
		return
	_guide_step = step
	labels.set_active(_next_index())
	var entry: Dictionary = GUIDE[mini(step, GUIDE.size() - 1)]
	var title := String(entry["title"])
	var copy := String(entry["copy"])
	if step == 0 and order_index > 0:
		title = "再开一窑"
		copy = "去取泥台领取下一单的瓷泥。"
	site_hud.set_guide(String(entry["num"]), String(entry["kicker"]), title, copy)


## Legacy nextStation(): first bench in STATIONS order that still needs work.
func _next_station() -> Dictionary:
	return SiteLayout.STATIONS[_next_index()]


func _next_index() -> int:
	return mini(_step(), 5)


func _step() -> int:
	if world.player == null or not world.player.has_clay:
		return 0
	if not steps.has("wheel"):
		return 1
	if not steps.has("carve"):
		return 2
	if not steps.has("paint"):
		return 3
	if not fired:
		return 4
	return 5


# --- 订单流程 -------------------------------------------------------------


func _start_order() -> void:
	orders = _load_orders()
	session = SculptSession.new(StringName(String(orders[order_index]["id"])), 1)
	session.radius = 18.0
	world.player.has_clay = false
	world.player.set_carried(null)
	steps.clear()
	fired = false
	grade = ""
	kiln = null
	_guide_step = -1
	_update_guide()
	if site_hud != null:
		_update_order_rail()


func _load_orders() -> Array:
	var items: Array = Catalog.items_for_site(Catalog.load_catalog())
	if items.is_empty():
		return [{"id": "band-pot", "name": "一抹青花罐",
			"task": "做一个圆润的罐子，中间画一条宽蓝带。", "hint": ""}]
	var result: Array = []
	for item in items:
		result.append({
			"id": String(item.get("id", "band-pot")),
			"name": String(item.get("name", "瓷器")),
			"task": String(item.get("task", "")),
			"hint": String(item.get("hint", "")),
		})
	return result.slice(0, mini(3, result.size()))


func _update_order_rail() -> void:
	if orders.is_empty():
		return
	var order: Dictionary = orders[order_index]
	GameState.order_index = order_index
	site_hud.set_order(String(order.get("name", "")), order_index + 1, orders.size())


func _can_work(id: String) -> bool:
	match id:
		"clay":
			return true
		"wheel", "carve", "paint":
			return world.player.has_clay
		"kiln":
			return steps.has("paint")
		"serve":
			return fired
	return false


func _open_codex() -> void:
	if sheet != null and sheet.visible:
		return
	if codex == null:
		codex = CodexPanel.new()
		add_child(codex)
		codex.closed.connect(func() -> void: site_hud.refresh_codex())
	var catalog := Catalog.load_catalog()
	var items := Catalog.items_for_site(catalog)
	var found: Array = SaveGame.data.get("codex", {}).get("discovered", [])
	site_hud.refresh_codex()
	codex.open(items, found)
	codex.move_to_front()


func _open_station(id: String) -> void:
	if session == null or not _can_work(id):
		return
	if id == "kiln" and kiln == null:
		_start_kiln()
	sheet.present(id, orders[order_index], {
		"level": order_index + 1,
		"preset_index": order_index,
		"has_clay": world.player.has_clay,
		"fired": fired,
		"grade": grade,
		"session": session,
		"kiln": kiln,
		"result": session.score(),
		"elapsed": session.elapsed_ms,
		"income": _income_preview(session.score()),
	})


func _income_preview(result: Dictionary) -> Dictionary:
	var passed := bool(result.get("passed", false))
	var order: Dictionary = orders[order_index]
	return Workshop.order_income(60.0, {
		"kiln": 1,
		"serve": 1,
		"passed": passed,
		"elapsedMs": session.elapsed_ms,
		"eligible": true,
		"firstPass": passed and not _finished_ids.has(order["id"]),
	})


## Legacy capture entry points: `-- screen=<world|supply|brief|editor|kiln|review|result>`.
func _apply_screen(screen: String) -> void:
	match screen:
		"world":
			pass
		"supply", "brief":
			_open_station("clay")
		"editor":
			world.player.has_clay = true
			_open_station("wheel")
		"carve":
			world.player.has_clay = true
			steps["wheel"] = true
			_open_station("carve")
		"paint":
			world.player.has_clay = true
			steps["wheel"] = true
			steps["carve"] = true
			_open_station("paint")
		"kiln":
			world.player.has_clay = true
			steps["wheel"] = true
			steps["carve"] = true
			steps["paint"] = true
			_open_station("kiln")
		"review", "result":
			world.player.has_clay = true
			steps["wheel"] = true
			steps["carve"] = true
			steps["paint"] = true
			_start_kiln()
			kiln.elapsed = kiln.duration
			kiln.seconds["perfect"] = 2.0
			kiln.seconds["good"] = 1.0
			fired = true
			grade = kiln.grade()
			_open_station("serve")


func _start_kiln() -> void:
	kiln = KilnRun.new(Time.get_ticks_usec() & 0xFFFF, 1)
	fired = false
	grade = ""


func _on_take_clay() -> void:
	var lump := Node3D.new()
	lump.name = "ClayLump"
	SiteProps.ball(lump, 0.0, 0.0, 0.0, 0.22, 0.18, 0.22, Color("f3e8d2"))
	world.player.set_carried(lump)
	steps["clay"] = true
	_guide_step = -1
	_update_guide()
	_toast("瓷泥到手 · 去「粗塑成形」台")


func _on_finish_step(id: String) -> void:
	steps[id] = true
	_guide_step = -1
	_update_guide()
	_toast("「%s」完成" % String(SiteLayout.station(id).get("name", id)))


func _on_stoke(started: bool) -> void:
	if kiln == null or kiln.finished():
		return
	kiln.stoking = started


var _round_earned := 0


func _on_deliver() -> void:
	if kiln == null or not kiln.finished():
		return
	var result := session.score()
	var passed := bool(result["passed"])
	var order: Dictionary = orders[order_index]
	var first_pass := passed and not _finished_ids.has(order["id"])
	var income := Workshop.order_income(60.0, {
		"kiln": 1,
		"serve": 1,
		"passed": passed,
		"elapsedMs": session.elapsed_ms,
		"eligible": true,
		"firstPass": first_pass,
	})
	GameState.add_coins(int(income["earned"]))
	GameState.discover(StringName(String(order["id"])))
	SaveGame.save_game()
	Events.sculpture_finished.emit(result)
	Events.item_sold.emit(int(income["earned"]), StringName(String(order["id"])))
	print("[Site] SERVED %s score=%.1f earned=%d coins=%d" % [
		order["id"], float(result["score"]), int(income["earned"]), GameState.coins])
	_round_earned += int(income["earned"])
	_toast("交付成功 · +%d 铜钱" % int(income["earned"]))
	_finished_ids[order["id"]] = true
	order_index += 1
	if order_index >= orders.size():
		order_index = 0
		_finished_ids.clear()
		var discovered := int(SaveGame.data.get("codex", {}).get("discovered", []).size())
		sheet.show_round(_round_earned, GameState.coins, discovered)
		return
	_start_order()


func _on_next_round() -> void:
	_round_earned = 0
	_guide_step = -1
	_start_order()


func _toast(text: String) -> void:
	if hud_layer == null:
		return
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.name = "Toast"
		_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.offset_top = -140
		_toast_label.offset_bottom = -104
		_toast_label.offset_left = -260
		_toast_label.offset_right = 260
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_size_override("font_size", 16)
		_toast_label.add_theme_color_override("font_color", Color("fdfaf1"))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.216, 0.275, 0.235, 0.94)
		style.set_corner_radius_all(10)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		_toast_label.add_theme_stylebox_override("normal", style)
		hud_layer.add_child(_toast_label)
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if codex != null and codex.visible and event.is_action_pressed("ui_cancel"):
		codex.close_panel()
		accept_event()
		return
	if sheet != null and sheet.visible and event.is_action_pressed("ui_cancel"):
		sheet.close_sheet()
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if sheet == null or not sheet.visible:
			_open_codex()
			accept_event()
