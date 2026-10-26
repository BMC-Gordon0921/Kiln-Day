class_name SiteProps
extends RefCounted

## Procedural props of the guyao yard.
##
## The legacy build (`legacy/web-demo/src/world.js`) assembles the sculptor, the
## customers and the workshop sign out of primitives; there is no model file to
## import.  This class rebuilds the same shapes from the same numbers so the
## silhouettes match, and keeps every helper close to the three.js original
## (`box` = RoundedBoxGeometry(1,1,1,2,.075) scaled, `ball` = SphereGeometry(1,16,12)
## scaled, `cyl` = CylinderGeometry(rt,rb,h,segments), `torus` = TorusGeometry(r,t,8,28)).

const PI_HALF := PI * 0.5

static var _materials: Dictionary = {}
static var _shadow_tex_cache: ImageTexture = null


# --- primitives -------------------------------------------------------------

static func material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var key := "%s|%.3f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.specular = 0.35
	_materials[key] = mat
	return mat


static func box(parent: Node3D, x: float, y: float, z: float,
		w: float, h: float, d: float, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, d)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = Vector3(x, y, z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func ball(parent: Node3D, x: float, y: float, z: float,
		rx: float, ry: float, rz: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = Vector3(x, y, z)
	node.scale = Vector3(rx, ry, rz)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func cyl(parent: Node3D, x: float, y: float, z: float,
		rt: float, rb: float, h: float, color: Color, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = rt
	mesh.bottom_radius = rb
	mesh.height = h
	mesh.radial_segments = segments
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = Vector3(x, y, z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func torus(parent: Node3D, x: float, y: float, z: float,
		radius: float, tube: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - tube)
	mesh.outer_radius = radius + tube
	mesh.rings = 28
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = Vector3(x, y, z)
	node.rotation = Vector3(PI_HALF, 0.0, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func group(parent: Node3D, x := 0.0, y := 0.0, z := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(x, y, z)
	parent.add_child(node)
	return node


## Soft contact shadow: the legacy build draws a transparent dark circle at
## y = 0.075 under every character.
static func ground_shadow(parent: Node3D, x: float, z: float,
		rx: float, rz: float, opacity := 0.14) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _shadow_texture()
	mat.albedo_color = Color(0.24, 0.22, 0.15, opacity)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	node.material_override = mat
	node.position = Vector3(x, 0.075, z)
	node.rotation = Vector3(-PI_HALF, 0.0, 0.0)
	node.scale = Vector3(rx, rz, 1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _shadow_texture() -> ImageTexture:
	if _shadow_tex_cache != null:
		return _shadow_tex_cache
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	for py in size:
		for px in size:
			var dx := (px - center) / center
			var dy := (py - center) / center
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	_shadow_tex_cache = ImageTexture.create_from_image(img)
	return _shadow_tex_cache


# --- characters -------------------------------------------------------------

static func build_sculptor(parent: Node3D, x := -4.55, z := -2.15) -> Dictionary:
	var skin := Color("dca37e")
	var hair := Color("674837")
	var shirt := Color("819685")
	var g := group(parent, x, 0.0, z)
	var body := group(g)
	ground_shadow(g, 0, 0, 0.5, 0.38, 0.17)

	var feet: Array[Node3D] = []
	feet.append(ball(body, -0.2, 0.15, 0.1, 0.18, 0.14, 0.27, Color("645444")))
	feet.append(ball(body, 0.2, 0.15, 0.1, 0.18, 0.14, 0.27, Color("645444")))
	box(body, -0.18, 0.36, 0, 0.23, 0.4, 0.29, Color("646e62"))
	box(body, 0.18, 0.36, 0, 0.23, 0.4, 0.29, Color("646e62"))
	ball(body, 0, 0.77, 0, 0.42, 0.46, 0.32, shirt)
	cyl(body, 0, 1.18, 0, 0.13, 0.15, 0.24, skin, 16)
	box(body, 0, 0.76, 0.32, 0.45, 0.67, 0.055, Color("e7d9b4"))
	box(body, 0, 0.64, 0.36, 0.31, 0.21, 0.035, Color("cbb793"))
	for ax in [-0.17, 0.17]:
		box(body, ax, 1.08, 0.30, 0.06, 0.3, 0.045, Color("e7d9b4"))

	var arms: Array[Node3D] = []
	for i in 2:
		var a := group(body, -0.47 if i == 0 else 0.47, 0.96, 0)
		ball(a, 0, -0.12, 0, 0.14, 0.24, 0.15, shirt)
		ball(a, 0, -0.37, 0.035, 0.12, 0.14, 0.135, skin)
		ball(a, 0.07 if i == 0 else -0.07, -0.33, 0.13, 0.065, 0.085, 0.065, skin)
		a.rotation.z = -0.13 if i == 0 else 0.13
		arms.append(a)

	var head := group(body, 0, 1.57, 0)
	ball(head, 0, 0, 0, 0.415, 0.43, 0.35, skin)
	for sign in [-1.0, 1.0]:
		ball(head, sign * 0.435, -0.015, 0, 0.09, 0.13, 0.08, skin)
		ball(head, sign * 0.166, 0.018, 0.326, 0.034, 0.052, 0.025, Color("3e382e"))
		ball(head, sign * 0.159, 0.035, 0.346, 0.011, 0.014, 0.008, Color.WHITE)
		ball(head, sign * 0.29, -0.11, 0.288, 0.068, 0.025, 0.018, Color("cf8d77"))
	ball(head, 0, -0.074, 0.365, 0.07, 0.065, 0.065, Color("d79972"))
	ball(head, 0, 0.24, -0.067, 0.449, 0.255, 0.33, hair)
	for i in 4:
		var lock := ball(head, -0.28 + i * 0.155, 0.245 + (i % 2) * 0.055, 0.23, 0.14, 0.135, 0.09, hair)
		lock.rotation.z = -0.24
	ball(head, 0, 0.44, -0.045, 0.39, 0.12, 0.29, Color("627e70"))
	cyl(head, 0, 0.545, -0.055, 0.042, 0.047, 0.09, Color("496454"), 12)
	box(head, 0.06, 0.418, 0.235, 0.35, 0.042, 0.14, Color("557260"))

	var apron_roll := box(body, 0, 1.18, 0.27, 0.22, 0.11, 0.13, Color("cba668"))
	apron_roll.rotation.z = 0.18
	box(body, 0, 0.71, 0.35, 0.3, 0.2, 0.055, Color("b9aa82"))
	for bx in [-0.13, 0.13]:
		ball(body, bx, 0.78, 0.39, 0.019, 0.019, 0.012, Color("85765b"))

	return {"group": g, "body": body, "head": head, "feet": feet, "arms": arms}


static func build_animal(parent: Node3D, type: String, x: float, z: float,
		coat := Color("769078")) -> Dictionary:
	var g := group(parent, x, 0.0, z)
	var body := group(g)
	var fur := Color("d2864a")
	if type == "rabbit":
		fur = Color("e5d8c0")
	elif type == "bear":
		fur = Color("9c7757")
	elif type != "fox":
		fur = Color("bba28a")
	var dark := Color("4d3d2d")
	var cream := Color("f3e2bd")

	ground_shadow(g, 0, 0, 0.52, 0.38, 0.17)
	var feet: Array[Node3D] = []
	feet.append(ball(body, -0.21, 0.15, 0.1, 0.2, 0.15, 0.27, dark))
	feet.append(ball(body, 0.21, 0.15, 0.1, 0.2, 0.15, 0.27, dark))
	ball(body, 0, 0.66, 0, 0.47, 0.56, 0.35, fur)
	ball(body, 0, 0.61, 0.09, 0.435, 0.45, 0.325, coat)

	var arms: Array[Node3D] = []
	for i in 2:
		var arm := ball(body, -0.49 if i == 0 else 0.49, 0.73, 0.04, 0.16, 0.32, 0.16, fur)
		arm.rotation.z = -0.25 if i == 0 else 0.25
		arms.append(arm)

	var head := group(body, 0, 1.32, 0)
	ball(head, 0, 0, 0, 0.56, 0.49, 0.43, fur)
	var ears: Array[Node3D] = []
	if type == "fox" or type == "cat":
		for sign in [-1.0, 1.0]:
			var ear := cyl(head, sign * 0.37, 0.43, -0.045, 0.0, 0.215, 0.56, fur, 4)
			ear.rotation.z = sign * -0.12
			var inner := cyl(head, sign * 0.37, 0.44, 0.075, 0.0, 0.124, 0.34,
					Color("6e4b34") if type == "fox" else Color("d9ab98"), 3)
			inner.rotation.z = sign * -0.12
			ears.append(ear)
			ears.append(inner)
	elif type == "rabbit":
		for sign in [-1.0, 1.0]:
			ears.append(ball(head, sign * 0.25, 0.65, -0.02, 0.155, 0.48, 0.14, fur))
			ears.append(ball(head, sign * 0.25, 0.68, 0.09, 0.08, 0.33, 0.025, Color("d9a899")))
	else:
		ears.append(ball(head, -0.4, 0.33, -0.03, 0.21, 0.22, 0.14, fur))
		ears.append(ball(head, 0.4, 0.33, -0.03, 0.21, 0.22, 0.14, fur))
		ball(head, -0.4, 0.35, 0.08, 0.11, 0.13, 0.045, Color("c39a78"))
		ball(head, 0.4, 0.35, 0.08, 0.11, 0.13, 0.045, Color("c39a78"))

	var tail: Node3D = null
	if type == "fox":
		var l := ball(head, -0.235, -0.17, 0.325, 0.29, 0.23, 0.16, cream)
		l.rotation.z = 0.3
		var r := ball(head, 0.235, -0.17, 0.325, 0.29, 0.23, 0.16, cream)
		r.rotation.z = -0.3
		ball(head, 0, -0.18, 0.47, 0.18, 0.13, 0.15, cream)
		tail = group(body, 0, 0.48, -0.29)
		tail.rotation.x = -0.75
		ball(tail, 0, 0.25, -0.14, 0.23, 0.42, 0.22, fur)
		ball(tail, 0, 0.57, -0.13, 0.21, 0.21, 0.2, cream)
	else:
		ball(head, 0, -0.17, 0.385, 0.28, 0.2, 0.11,
				Color("ede0c3") if type == "cat" else Color("e0c6a2"))
		if type == "cat":
			tail = group(body, 0, 0.5, -0.28)
			tail.rotation.x = -0.95
			ball(tail, 0, 0.28, -0.12, 0.12, 0.42, 0.12, fur)
			ball(tail, 0, 0.58, -0.12, 0.1, 0.1, 0.1, cream)

	ball(head, 0, -0.11, 0.59 if type == "fox" else 0.487, 0.073, 0.052, 0.048, dark)
	var eyes: Array[Node3D] = []
	for sign in [-1.0, 1.0]:
		eyes.append(ball(head, sign * 0.215, 0.025, 0.389, 0.044, 0.066, 0.032, dark))
		eyes.append(ball(head, sign * 0.204, 0.044, 0.414, 0.013, 0.018, 0.009, Color.WHITE))
		ball(head, sign * 0.343, -0.1, 0.369, 0.075, 0.035, 0.018, Color("d59977"))
	return {"group": g, "body": body, "head": head, "feet": feet, "arms": arms,
			"eyes": eyes, "ears": ears, "tail": tail}


# --- signboard --------------------------------------------------------------

static func build_sign(parent: Node3D, text: String, accent := Color("8aa78d")) -> Node3D:
	var g := group(parent, 0.25, 1.34, -5.3)
	g.name = "workshop-sign"
	for s in [-1.0, 1.0]:
		box(g, s * 1.88, -0.55, 0, 0.13, 1.42, 0.13, Color("6a4b2f"))
	box(g, 0, 0, 0, 3.98, 0.94, 0.14, Color("46311f"))

	# Board face: gradient plate, accent frame and the four diamond rivets of the
	# canvas texture in world.js.
	var face := box(g, 0, 0, 0.078, 3.68, 0.9, 0.02, Color("2c3a30"))
	face.material_override = material(Color("2c3a30"), 0.7)
	for s in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var rivet := box(g, s.x * 1.72, s.y * 0.37, 0.095, 0.06, 0.06, 0.02, accent)
		rivet.rotation.z = PI * 0.25
	box(g, 0, 0.44, 0.088, 3.72, 0.014, 0.02, accent)
	box(g, 0, -0.44, 0.088, 3.72, 0.014, 0.02, accent)
	box(g, -1.86, 0, 0.088, 0.014, 0.9, 0.02, accent)
	box(g, 1.86, 0, 0.088, 0.014, 0.9, 0.02, accent)

	var title := Label3D.new()
	title.text = text
	title.font = _serif_font()
	title.font_size = 96
	title.pixel_size = 0.0052
	title.modulate = Color("fdf3d6")
	title.outline_size = 0
	title.position = Vector3(0, 0.06, 0.11)
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.no_depth_test = false
	title.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(title)

	var sub := Label3D.new()
	sub.text = "T E R R A   ·   C L A Y   S T U D I O"
	sub.font = _serif_font()
	sub.font_size = 32
	sub.pixel_size = 0.0032
	sub.modulate = accent
	sub.position = Vector3(0, -0.30, 0.11)
	sub.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(sub)

	# Cornice, roof tiles and the two lamp brackets.
	box(g, 0, 0.57, 0.02, 4.2, 0.09, 0.34, Color("774b2d"))
	box(g, 0, 0.64, 0.05, 3.96, 0.05, 0.28, Color("9a613c"))
	for i in 8:
		box(g, -1.7 + i * 0.49, 0.68, 0.06, 0.32, 0.035, 0.3, Color("b2764c"))
	for s in [-1.0, 1.0]:
		box(g, s * 1.95, 0.07, 0, 0.1, 0.78, 0.16, Color("68482c"))
		box(g, s * 1.62, -0.42, 0.04, 0.05, 0.32, 0.05, Color("34251a"))
		ball(g, s * 1.62, -0.27, 0.04, 0.1, 0.13, 0.1, Color("2b1d15"))
		var bulb := ball(g, s * 1.62, -0.43, 0.04, 0.105, 0.105, 0.105, Color("ffd7a2"))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("ffd7a2")
		glow.emission_enabled = true
		glow.emission = Color("ff9a44")
		glow.emission_energy_multiplier = 1.15
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bulb.material_override = glow
		ball(g, s * 1.62, -0.56, 0.04, 0.15, 0.028, 0.028, Color("c9a04a"))
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb15f")
	lamp.light_energy = 0.6
	lamp.omni_range = 3.4
	lamp.position = Vector3(0, 0.3, 0.55)
	g.add_child(lamp)
	return g


static func _serif_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Songti SC", "STSong", "SimSun", "Noto Serif SC", "Source Han Serif SC",
		"Georgia", "serif",
	])
	return font
