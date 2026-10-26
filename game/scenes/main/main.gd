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
var hud: CanvasLayer
var debug_label: Label

var _shot_path := ""
var _shot_frames := 40


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
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(16, 16)
	debug_label.add_theme_color_override("font_color", Color(0.23, 0.26, 0.23))
	debug_label.visible = OS.get_cmdline_user_args().has("hud")
	hud.add_child(debug_label)


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
	for i in _shot_frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	print("[Site] SHOT_OK %s err=%d" % [_shot_path, error])
	get_tree().quit()
