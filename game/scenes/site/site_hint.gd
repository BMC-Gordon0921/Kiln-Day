class_name SiteHint
extends Node3D

## The "go here next" guidance: a pulsing ring on the approach spot of the next
## bench plus a glowing curtain and floating motes around its workbench
## (legacy/web-demo/src/world.js:198-219, animated at :286-295).
##
## One deliberate omission: the legacy build builds a floating arrow at :213-217
## and then hides it unconditionally at :292, so it never reaches the screen.
## Rebuilding invisible geometry would only cost draw calls.

const MARKER_INNER := 0.47
const MARKER_OUTER := 0.56
const MARKER_SEGMENTS := 40
const MARKER_COLOR := Color("f7dfa2")
const MARKER_OPACITY := 0.83

const GLOW_RADIUS := 1.08
const GLOW_COLOR := Color("ffcf82")
const GLOW_OPACITY := 0.16

const RING_INNER := 0.88
const RING_OUTER := 0.96
const RING_SEGMENTS := 44
const RING_COLOR := Color("ffe1a4")
const RING_OPACITY := 0.55

const CURTAIN_OPACITY := 0.4
const CURTAIN_HEIGHT := 2.15

var marker: MeshInstance3D
var hint: Node3D
var glow: MeshInstance3D
var ring: MeshInstance3D
var curtain: MeshInstance3D
var motes: ParticleField

var reduced_motion := false


func _ready() -> void:
	if marker == null:
		build()


func build() -> void:
	marker = SiteShapes.ring(self, MARKER_INNER, MARKER_OUTER, MARKER_SEGMENTS,
		MARKER_COLOR, MARKER_OPACITY, 0.085)
	marker.name = "ApproachMarker"
	marker.visible = false

	hint = Node3D.new()
	hint.name = "NextStationHint"
	hint.visible = false
	add_child(hint)

	glow = SiteShapes.disc(hint, GLOW_RADIUS, 40, GLOW_COLOR, GLOW_OPACITY, 0.1, true)
	glow.name = "HintGlow"
	ring = SiteShapes.ring(hint, RING_INNER, RING_OUTER, RING_SEGMENTS,
		RING_COLOR, RING_OPACITY, 0.11)
	ring.name = "HintRing"
	curtain = SiteShapes.curtain(hint, 0.8, 0.96, CURTAIN_HEIGHT,
		Color("ffebb4"), Color("ffcc78"), Color("ffd68c"), CURTAIN_OPACITY, 1.15)
	curtain.name = "HintCurtain"
	motes = ParticleField.create(hint, {
		"count": 34, "color": Color("ffcf82"), "color2": Color("fff5cd"),
		"size": 9.0, "rise": 1.8, "spread": 0.4, "opacity": 0.7,
		"radius": 0.9, "height": 2.2, "seed": 7,
	}, "HintMotes")


## `next` is a SiteLayout station entry, or {} to hide the guidance.
func update_world(time: float, playing: bool, next: Dictionary) -> void:
	var show := playing and not next.is_empty()
	marker.visible = show
	hint.visible = show
	if not show:
		if motes != null:
			motes.update_world(0.0, 0.0)
		return

	var approach: Vector2 = next["approach"]
	marker.position = Vector3(approach.x, 0.085, approach.y)
	var marker_scale := 1.0 + sin(time * 3.0) * 0.08
	marker.scale = Vector3.ONE * (marker_scale if not reduced_motion else 1.0)

	hint.position = Vector3(float(next["x"]), 0.0, float(next["z"]))
	if reduced_motion:
		glow.scale = Vector3.ONE
		ring.scale = Vector3.ONE
		_set_alpha(glow, 0.13)
		_set_alpha(ring, 0.46)
		curtain.rotation.y = 0.0
		_set_shader_opacity(curtain, 0.34)
	else:
		glow.scale = Vector3.ONE * (1.0 + sin(time * 2.5) * 0.07)
		ring.scale = Vector3.ONE * (1.0 + sin(time * 2.5 + 1.0) * 0.05)
		_set_alpha(glow, 0.13 + sin(time * 2.5) * 0.035)
		_set_alpha(ring, 0.46 + sin(time * 2.5 + 1.0) * 0.1)
		curtain.rotation.y = time * 0.22
		_set_shader_opacity(curtain, 0.34 + sin(time * 2.2) * 0.06)
	motes.update_world(get_process_delta_time(), 1.0 if playing else 0.0)


func _set_alpha(node: MeshInstance3D, alpha: float) -> void:
	var material := node.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color.a = alpha


func _set_shader_opacity(node: MeshInstance3D, value: float) -> void:
	var material := node.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("opacity", value)
