class_name SiteWorld
extends Node3D

## The playable diorama: site mesh + six workbenches + lighting + camera.
## Geometry and lighting numbers come from legacy/web-demo/src/world.js.

const SITE_ID := "guyao"
const SITE_LIFT := 0.09

const SITE_PATH := "res://assets/models/maps/%s.glb"
const BENCH_PATH := "res://assets/models/workbenches/%s.glb"

const HEMI_SKY := Color("fbf4e2")
const HEMI_GROUND := Color("a7aa90")
const KEY_COLOR := Color("ffe3b3")
const FILL_COLOR := Color("cfe4f2")
const KEY_POSITION := Vector3(-3.0, 14.0, 7.0)

## Calibrated against the legacy capture (see art/tools/parity_score.py). three.js
## intensities do not transfer 1:1, so these are measured, not copied.
const AMBIENT_ENERGY := 0.22
const KEY_ENERGY := 0.44
const FILL_ENERGY := 0.95
const FILL_POSITION := Vector3(8.0, 7.0, -5.0)

var camera: OrbitCamera
var content: Node3D
var site_root: Node3D
var bench_roots: Dictionary = {}
var environment: Environment
var smoke: ParticleField

## Per-material albedo calibration measured against the legacy capture.  The
## site GLB keeps its authored colours; these factors only steer the renderer
## towards the warmer/darker three.js palette.
const PALETTE := {
	"tile": Color(0.90, 0.89, 0.98),
	"stone_light": Color(0.90, 0.89, 0.97),
	"stone": Color(0.93, 0.92, 0.97),
	"ivory": Color(0.90, 0.89, 0.95),
	"sand": Color(0.90, 0.88, 0.96),
	"roof": Color(1.0, 1.02, 1.04),
	"leaf": Color(0.96, 0.96, 1.02),
	"sage": Color(0.95, 0.97, 1.02),
}
var player: PlayerActor
var hint: SiteHint
var cast: Node3D

var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _bench_level := 1
var _bounds := AABB()
var _bounds_found := false


func _ready() -> void:
	build()


func build() -> void:
	content = Node3D.new()
	content.name = "Content"
	content.position = Vector3(0.0, SITE_LIFT, 0.0)
	add_child(content)

	_build_environment()
	_build_lights()
	_build_site()
	_calibrate_materials()
	_build_benches()
	_build_cast()
	_build_smoke()
	_build_player()
	_build_hint()
	_build_camera()
	if camera:
		camera.apply()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = HEMI_SKY
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.90
	world.environment = environment
	add_child(world)


func _build_lights() -> void:
	_key_light = DirectionalLight3D.new()
	_key_light.name = "KeyLight"
	_key_light.light_color = KEY_COLOR
	_key_light.light_energy = KEY_ENERGY
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key_light.directional_shadow_max_distance = 45.0
	_key_light.shadow_bias = -0.0002
	_key_light.shadow_normal_bias = 0.045
	_key_light.shadow_blur = 0.5
	content.add_child(_key_light)
	_key_light.look_at_from_position(KEY_POSITION, Vector3.ZERO, Vector3.UP)

	_fill_light = DirectionalLight3D.new()
	_fill_light.name = "FillLight"
	_fill_light.light_color = FILL_COLOR
	_fill_light.light_energy = FILL_ENERGY
	_fill_light.shadow_enabled = false
	content.add_child(_fill_light)
	_fill_light.look_at_from_position(FILL_POSITION, Vector3.ZERO, Vector3.UP)


func _build_site() -> void:
	site_root = _instantiate(SITE_PATH % SITE_ID)
	if site_root == null:
		push_error("[SiteWorld] SITE_FAIL missing " + SITE_PATH % SITE_ID)
		return
	site_root.name = SITE_ID
	content.add_child(site_root)


func _calibrate_materials() -> void:
	var stack: Array[Node] = [content]
	var overrides := {}
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.mesh != null:
			var mi := node as MeshInstance3D
			for surface in mi.mesh.get_surface_count():
				var material := mi.get_active_material(surface)
				if not material is BaseMaterial3D:
					continue
				var factor := Color.WHITE
				var lower := material.resource_name.to_lower()
				for key in PALETTE:
					if lower.begins_with(key):
						factor = PALETTE[key]
						break
				if factor == Color.WHITE:
					continue
				var id := material.get_instance_id()
				if not overrides.has(id):
					var copy := material.duplicate() as BaseMaterial3D
					copy.albedo_color = copy.albedo_color * factor
					overrides[id] = copy
				mi.set_surface_override_material(surface, overrides[id])
		for child in node.get_children():
			stack.append(child)


func _build_benches() -> void:
	for entry in SiteLayout.STATIONS:
		var id: String = entry["id"]
		var root := _instantiate(BENCH_PATH % id)
		if root == null:
			push_error("[SiteWorld] BENCH_FAIL missing " + BENCH_PATH % id)
			continue
		root.name = id
		root.position = Vector3(entry["x"], 0.0, entry["z"])
		content.add_child(root)
		bench_roots[id] = root
		apply_bench_level(_bench_level)


## Characters and the signboard are procedural in the legacy build, so they are
## rebuilt here instead of being imported.
func _build_cast() -> void:
	var accent := Color("8aa78d")
	var catalog := Catalog.load_catalog()
	var site := Catalog.site(catalog, SITE_ID)
	if site.has("color"):
		accent = Color(str(site["color"]))
	SiteProps.build_sign(content, "古窑手作坊", accent)

	cast = Node3D.new()
	cast.name = "Cast"
	content.add_child(cast)

	# Legacy coats, in the fixed spawn order of world.js.
	var coats := {"rabbit": Color("b996a0"), "bear": Color("bc9d5e"), "cat": Color("92a292")}
	var spots := [[4.9, -0.25], [4.95, 1.65], [4.98, 3.35]]
	var index := 0
	for species in ["rabbit", "bear", "cat"]:
		var spot: Array = spots[index]
		var customer := SiteProps.build_animal(cast, species, float(spot[0]), float(spot[1]),
				coats[species])
		var node: Node3D = customer["group"]
		node.rotation.y = -PI * 0.5
		node.scale = Vector3(0.85, 0.85, 0.85)
		index += 1


## The player is part of the diorama (not the HUD) so the camera can orbit it and
## the depth buffer handles occlusion, exactly like the legacy `player.group`.
## The legacy build hangs a normal-blended plume off the kiln chimney anchor
## baked into each site (guyao: 6.0, 5.68, -9.3).
func _build_smoke() -> void:
	smoke = ParticleField.create(content, {
		"count": 160,
		"color": Color("d6d0c3"),
		"color2": Color("f8f3e8"),
		"size": 30.0,
		"rise": 4.6,
		"spread": 0.7,
		"opacity": 0.30,
		"additive": false,
		"radius": 0.13,
		"height": 0.08,
		"fade_in": 0.035,
		"seed": 3,
	}, "ChimneySmoke")
	smoke.position = Vector3(6.0, 5.68, -9.3)


func _process(delta: float) -> void:
	if smoke:
		smoke.update_world(delta, 0.78)


func _build_player() -> void:
	player = PlayerActor.new()
	player.name = "Player"
	player.add_to_group("player")
	# add_child triggers PlayerActor._ready() -> build(); building again would
	# create a second sculptor (the bug visible in 12-result.png).
	content.add_child(player)
	print("[Site] PLAYERS=%d" % get_tree().get_nodes_in_group("player").size())


func _build_hint() -> void:
	hint = SiteHint.new()
	hint.name = "Guidance"
	content.add_child(hint)
	hint.build()


func _instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed == null or not packed.can_instantiate():
		return null
	return packed.instantiate() as Node3D


func set_bench_level(level: int) -> void:
	_bench_level = maxi(1, level)
	apply_bench_level(_bench_level)


## Calibration hook: the legacy three.js intensities are not directly transferable,
## so the parity harness sweeps these three numbers and keeps the best match.
func set_lighting(ambient_energy: float, key_energy: float, fill_energy: float) -> void:
	if environment:
		environment.ambient_light_energy = ambient_energy
	if _key_light:
		_key_light.light_energy = key_energy
	if _fill_light:
		_fill_light.light_energy = fill_energy


func apply_bench_level(level: int) -> void:
	for id in bench_roots:
		_apply_tier_visibility(bench_roots[id], level)


## Bench props carry a `tier` meta from the Blender export: base / upgrade1 / upgrade2.
func _apply_tier_visibility(node: Node, level: int) -> void:
	if node.has_meta("tier"):
		var tier: String = str(node.get_meta("tier"))
		var needed := 1
		if tier == "upgrade1":
			needed = 2
		elif tier == "upgrade2":
			needed = 3
		node.visible = level >= needed
		if not node.visible:
			return
	for child in node.get_children():
		_apply_tier_visibility(child, level)


func _build_camera() -> void:
	camera = OrbitCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.apply_viewport(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1600),
		ProjectSettings.get_setting("display/window/size/viewport_height", 900)
	)


## Combined world-space bounds of the site mesh, used by tests and the lab view.
func site_bounds() -> AABB:
	if site_root == null:
		return AABB()
	_bounds_found = false
	_bounds = AABB()
	_collect_bounds(site_root, Transform3D.IDENTITY)
	return _bounds


func _collect_bounds(node: Node, parent_xform: Transform3D) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var box: AABB = xform * mesh_instance.get_aabb()
			if _bounds_found:
				_bounds = _bounds.merge(box)
			else:
				_bounds = box
				_bounds_found = true
	for child in node.get_children():
		_collect_bounds(child, xform)
