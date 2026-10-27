class_name ParticleField
extends MeshInstance3D

## Port of `legacy/web-demo/src/particles.js`: a GPU point cloud that drifts
## upward, fades at the ends of its life and twinkles, with no per-particle CPU
## work.  The maths is a 1:1 transcript of the original shader so the chimney
## smoke, kiln embers, hint motes and dust read the same as in the web build.
##
## Two deliberate deviations:
##   * the random spread is seeded, so screenshots are reproducible;
##   * `u_boost` compensates for Godot's ACES tonemapping, which the three.js
##     ShaderMaterial never went through (measured, not guessed).

const VERTEX_SHADER := """
uniform float u_time;
uniform float u_rise;
uniform float u_spread;
uniform float u_size;
uniform float u_fade_in;

varying float v_life;
varying float v_fade;

void vertex() {
	float seed = UV.x;
	float life = fract(seed + u_time * 0.17);
	vec3 p = VERTEX;
	p.y += life * u_rise;
	p.x += sin(seed * 12.9898 + u_time * 0.8) * u_spread * life;
	p.z += cos(seed * 78.233 + u_time * 0.6) * u_spread * life;
	VERTEX = p;
	POINT_SIZE = u_size * (0.62 + 0.7 * fract(seed * 37.0)) * (0.72 + 0.5 * life);
	v_life = life;
	v_fade = smoothstep(0.0, u_fade_in, life) * (1.0 - smoothstep(0.6, 1.0, life));
}
"""

const FRAGMENT_SHADER := """
uniform vec3 u_color : source_color;
uniform vec3 u_color2 : source_color;
uniform float u_opacity;
uniform float u_active;
uniform float u_boost;

void fragment() {
	vec2 d = POINT_COORD - vec2(0.5);
	if (dot(d, d) > 0.25) {
		discard;
	}
	float radius = length(d);
	float soft = smoothstep(0.5, 0.1, radius);
	vec3 col = mix(u_color2, u_color, clamp(radius * 1.6, 0.0, 1.0));
	ALBEDO = col * u_boost;
	ALPHA = soft * v_fade * u_opacity * u_active;
}
"""

## Defaults copied from particles.js: count 120, size 16, rise 3, spread .5,
## opacity .6, radius .3, height 0, fadeIn .12, additive blending.
const DEFAULTS := {
	"count": 120,
	"color": Color(1, 1, 1),
	"color2": Color(1.0, 0.902, 0.690),
	"size": 16.0,
	"rise": 3.0,
	"spread": 0.5,
	"opacity": 0.6,
	"additive": true,
	"radius": 0.3,
	"height": 0.0,
	"start_active": 1.0,
	"fade_in": 0.12,
	"boost": 1.0,
	"seed": 1,
}

var active := 1.0
var target := 1.0
var time := 0.0

var _material: ShaderMaterial


func _init(config: Dictionary = {}) -> void:
	var cfg := DEFAULTS.duplicate()
	for key in config:
		cfg[key] = config[key]
	_build_shader(cfg)
	_build_points(cfg)
	active = float(cfg["start_active"])
	target = active
	_material.set_shader_parameter("u_active", active)


static func create(parent: Node3D, config: Dictionary = {}, node_name := "") -> ParticleField:
	var field := ParticleField.new(config)
	if not node_name.is_empty():
		field.name = node_name
	parent.add_child(field)
	return field


func _build_shader(cfg: Dictionary) -> void:
	var shader := Shader.new()
	var blend := "blend_add" if bool(cfg["additive"]) else "blend_mix"
	shader.code = "shader_type spatial;\nrender_mode %s, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;\n\n%s\n%s" % [
		blend, VERTEX_SHADER, FRAGMENT_SHADER,
	]
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("u_color", cfg["color"])
	_material.set_shader_parameter("u_color2", cfg["color2"])
	_material.set_shader_parameter("u_opacity", float(cfg["opacity"]))
	_material.set_shader_parameter("u_active", float(cfg["start_active"]))
	_material.set_shader_parameter("u_boost", float(cfg["boost"]))
	_material.set_shader_parameter("u_size", float(cfg["size"]))
	_material.set_shader_parameter("u_rise", float(cfg["rise"]))
	_material.set_shader_parameter("u_spread", float(cfg["spread"]))
	_material.set_shader_parameter("u_fade_in", float(cfg["fade_in"]))
	_material.set_shader_parameter("u_time", 0.0)


func _build_points(cfg: Dictionary) -> void:
	var count := int(cfg["count"])
	var radius := float(cfg["radius"])
	var height := float(cfg["height"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"])

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(count)
	uvs.resize(count)
	for i in count:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		vertices[i] = Vector3(cos(angle) * r, rng.randf() * height, sin(angle) * r)
		uvs[i] = Vector2(rng.randf(), 0.0)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	# The cloud moves entirely in the vertex shader, so the CPU-side bounds are
	# meaningless; the legacy build disables frustum culling for the same reason.
	mesh.custom_aabb = AABB(
		Vector3(-radius - 1.0, -1.0, -radius - 1.0),
		Vector3(radius * 2.0 + 2.0, height + float(cfg["rise"]) + 2.0, radius * 2.0 + 2.0))

	self.mesh = mesh
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0


## particles.js update(): the intensity eases towards the target, the shader is
## switched off entirely once it is indistinguishable from zero.
func update_world(delta: float, intensity := 1.0) -> void:
	target = clampf(intensity, 0.0, 1.0)
	active += (target - active) * minf(1.0, delta * 4.0)
	time += delta
	_material.set_shader_parameter("u_active", active)
	_material.set_shader_parameter("u_time", time)
	visible = active > 0.01


func set_boost(value: float) -> void:
	_material.set_shader_parameter("u_boost", value)
