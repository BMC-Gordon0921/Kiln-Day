extends Control

## Main scene shell: gradient backdrop + 3D site in a transparent SubViewport + HUD layer.
## Mirrors the legacy DOM stack: #app gradient, #world-wrap canvas, task overlay above.

const BACKDROP_INNER := Color("f4f0e0")
const BACKDROP_OUTER := Color("e4e3d6")

## Legacy #world-wrap box: top 95px, bottom 58px, right 265px (see legacy style.css).
const TOPBAR_HEIGHT := 95.0
const BOTTOMBAR_HEIGHT := 58.0
const RIGHT_RAIL_WIDTH := 265.0
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
var hud_layer: CanvasLayer
var debug_label: Label

var _shot_path := ""
var _shot_frames := 40
var _elapsed := 0.0
var _f_held := false
var _scripted_axis := Vector2.ZERO
var _walk_target := Vector2.INF
var _pending_shot := false
var _bare := false
var _moved := false


func _ready() -> void:
	_build_backdrop()
	_build_world()
	_build_hud()
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
	world_viewport.msaa_3d = Viewport.MSAA_2X
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world_viewport)

	world = SiteWorld.new()
	world.name = "SiteWorld"
	world_viewport.add_child(world)


	labels = WorldLabels.new()
	labels.name = "StationLabels"
	container.add_child(labels)
	labels.setup(world)

	# The legacy #interaction card lives inside #world-wrap, so it is a sibling of
	# the 3D view and shares its coordinate space.
	prompt = InteractionPrompt.new()
	prompt.name = "Interaction"
	container.add_child(prompt)


## Keep the 3D viewport inside the same rectangle as the legacy #world-wrap.
func _layout_world() -> void:
	if world_view == null:
		return
	var size := get_viewport_rect().size
	var top := TOPBAR_HEIGHT
	var bar := BOTTOMBAR_HEIGHT
	var rail := RIGHT_RAIL_WIDTH
	if size.y <= 760.0:
		top = 79.0
	if size.x <= 1100.0:
		rail = 220.0
	world_view.offset_left = 0.0
	world_view.offset_top = top
	world_view.offset_right = -rail
	world_view.offset_bottom = -bar


func _build_hud() -> void:
	site_hud = SiteHud.new()
	site_hud.name = "SiteHUD"
	add_child(site_hud)

	hud_layer = CanvasLayer.new()
	hud_layer.name = "Debug"
	add_child(hud_layer)
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(16, TOPBAR_HEIGHT + 8)
	debug_label.add_theme_color_override("font_color", Color(0.23, 0.26, 0.23))
	debug_label.visible = OS.get_cmdline_user_args().has("hud")
	hud_layer.add_child(debug_label)


func _resize() -> void:
	_layout_world()
	if world == null or world.camera == null or world_view == null:
		return
	var size := world_view.size
	world.camera.apply_viewport(size.x, size.y)
	debug_label.text = "%d x %d" % [int(size.x), int(size.y)]


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("shot="):
			_shot_path = arg.substr(5)
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
	if _shot_path.is_empty():
		return
	await _capture()


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
		_f_held = false
		return
	var head := Vector3(world.player.position2d.x, 2.25 + SiteWorld.SITE_LIFT,
			world.player.position2d.y)
	var screen: Vector2 = world.camera.unproject_position(head)
	prompt.show_for(str(nearest["id"]), true, _prompt_state())
	prompt.place_at(screen, world_view.size.x)

	var pressed := Input.is_physical_key_pressed(KEY_F)
	if pressed and not _f_held:
		print("[Site] INTERACT %s" % nearest["id"])
	_f_held = pressed


## Placeholder until the campaign state lands (Step 5): everything is unlocked.
func _prompt_state() -> Dictionary:
	return {"fired": false, "kiln": false, "kiln_result": false, "can_work": true}


## The guide card branches on the same milestone as the legacy tour: carry clay,
## then head for the wheel.
var _guide_step := -1

func _update_guide() -> void:
	if site_hud == null or world.player == null:
		return
	var step := 1 if world.player.has_clay else 0
	if step == _guide_step:
		return
	_guide_step = step
	labels.set_active(_next_index())
	if step == 1:
		site_hud.set_guide("02", "新手教学 · 2 / 7", "把瓷泥送上拉坯台",
			"走近「粗塑成形」台，按 F 开始揉泥、拉坯。")
	else:
		site_hud.set_guide("01", "开始你的第一件作品", "从一抔瓷泥开始",
			"去取泥台领取瓷泥。")


## Legacy nextStation(): first bench in STATIONS order that still needs work.
func _next_station() -> Dictionary:
	return SiteLayout.STATIONS[_next_index()]


func _next_index() -> int:
	# Only two milestones exist on this prototype: fetch clay, then throw it.
	return 1 if world.player != null and world.player.has_clay else 0
