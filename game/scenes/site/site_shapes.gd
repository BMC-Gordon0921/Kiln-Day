class_name SiteShapes
extends RefCounted

## Flat, unlit decoration geometry: the ground rings, glows and light curtains the
## three.js build writes by hand (legacy/web-demo/src/world.js:198-219).
##
## All of it is built in the XZ plane / upright, so no per-node rotation is
## needed and the y offsets in world.js can be copied verbatim.

## Unshaded material with the depth behaviour of the legacy MeshBasicMaterial:
## transparent, no depth write, both faces, no shadow receiving.
static func unshaded(color: Color, opacity := 1.0, additive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, opacity)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_receive_shadows = true
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


## THREE.RingGeometry(inner, outer, segments) laid flat at height `y`.
static func ring(parent: Node3D, inner: float, outer: float, segments: int,
		color: Color, opacity: float, y: float) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var angle := float(i) / float(segments) * TAU
		var c := cos(angle)
		var s := sin(angle)
		vertices.append(Vector3(c * inner, y, s * inner))
		vertices.append(Vector3(c * outer, y, s * outer))
	for i in segments:
		var base := i * 2
		indices.append_array([base, base + 2, base + 1])
		indices.append_array([base + 1, base + 2, base + 3])
	return _add_mesh(parent, vertices, indices, unshaded(color, opacity))


## THREE.CircleGeometry(radius, segments) laid flat at height `y`.
static func disc(parent: Node3D, radius: float, segments: int,
		color: Color, opacity: float, y: float, additive := true) -> MeshInstance3D:
	var vertices := PackedVector3Array([Vector3(0.0, y, 0.0)])
	var indices := PackedInt32Array()
	for i in segments + 1:
		var angle := float(i) / float(segments) * TAU
		vertices.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
	for i in segments:
		indices.append_array([0, i + 1, i + 2])
	return _add_mesh(parent, vertices, indices, unshaded(color, opacity, additive))


## The warm light curtain over the next bench: an open cylinder whose alpha fades
## towards the top, exactly the canvas gradient of world.js:210-212.
static func curtain(parent: Node3D, top_radius: float, bottom_radius: float,
		height: float, color_bottom: Color, color_middle: Color, color_top: Color,
		opacity: float, y: float) -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform vec3 color_bottom : source_color;
uniform vec3 color_middle : source_color;
uniform vec3 color_top : source_color;
uniform float height = 2.15;
uniform float opacity = 0.4;

float alpha_at(float t) {
	if (t < 0.55) {
		return mix(0.72, 0.3, t / 0.55);
	}
	return mix(0.3, 0.0, (t - 0.55) / 0.45);
}

vec3 color_at(float t) {
	if (t < 0.55) {
		return mix(color_bottom, color_middle, t / 0.55);
	}
	return mix(color_middle, color_top, (t - 0.55) / 0.45);
}

void fragment() {
	float t = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
	ALBEDO = color_at(t);
	ALPHA = alpha_at(t) * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("color_bottom", color_bottom)
	material.set_shader_parameter("color_middle", color_middle)
	material.set_shader_parameter("color_top", color_top)
	material.set_shader_parameter("height", height)
	material.set_shader_parameter("opacity", opacity)

	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = Vector3(0.0, y, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _add_mesh(parent: Node3D, vertices: PackedVector3Array,
		indices: PackedInt32Array, material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
