class_name PlayerActor
extends Node3D

## The player-controlled sculptor: the walking body, its ground ring and the piece
## it carries.  Every number comes from `world.js` (player setup at :194, motion at
## :260, idle animation at :267-282).

## Arms swing forward like this while clay is carried (world.js:269).
const CARRY_ARM_PITCH := -1.05
## Idle fidget: a short gesture 10s into every 18s beat (world.js:280).
const IDLE_BEAT := 18.0
const IDLE_GESTURE_START := 10.0
const IDLE_GESTURE_LENGTH := 3.0

var position2d := SiteLayout.PLAYER_SPAWN
var facing := SiteLayout.PLAYER_FACING
var walking := 0.0
var stride := 0.0
var moving := false
var has_clay := false

var body: Node3D
var head: Node3D
var feet: Array[Node3D] = []
var arms: Array[Node3D] = []
var carry_slot: Node3D
var ring: MeshInstance3D

var _root: Node3D


func _ready() -> void:
	if _root == null:
		build()


func build() -> void:
	var parts := SiteProps.build_sculptor(self, position2d.x, position2d.y)
	_root = parts["group"]
	body = parts["body"]
	head = parts["head"]
	feet.assign(parts["feet"])
	arms.assign(parts["arms"])
	_root.rotation.y = facing

	# The sandbox ring is a sibling of the body, not a child, so it never bobs.
	ring = SiteShapes.ring(self, 0.5, 0.54, 36, Color("ffffdf"), 0.55, 0.09)
	ring.name = "PlayerRing"
	ring.position = Vector3(position2d.x, 0.09, position2d.y)

	carry_slot = Node3D.new()
	carry_slot.name = "CarrySlot"
	carry_slot.position = Vector3(0.0, 0.86, 0.66)
	body.add_child(carry_slot)


## world.js move(): normalise, project onto the camera basis, step each axis
## separately, then turn towards the direction of travel.
func move(dx: float, dz: float, dt: float, camera: Node3D) -> void:
	if is_zero_approx(dx) and is_zero_approx(dz):
		moving = false
		return
	var axes := SiteMotion.camera_axes(camera)
	var result := SiteMotion.walk(position2d, dx, dz, dt, axes[0], axes[1])
	facing = SiteMotion.turn(facing, float(result["facing"]), dt)
	position2d = result["position"]
	moving = bool(result["moved"])
	if moving:
		walking += dt * SiteLayout.WALK_STRIDE_RATE
		stride += dt * SiteLayout.WALK_STRIDE_RATE
	apply_transform()


func apply_transform() -> void:
	if _root == null:
		return
	_root.position = Vector3(position2d.x, 0.0, position2d.y)
	_root.rotation.y = facing
	if ring != null:
		ring.position.x = position2d.x
		ring.position.z = position2d.y


func teleport(x: float, z: float) -> void:
	position2d = Vector2(x, z)
	apply_transform()


## Body, feet, arms and head animation (world.js:267-282).
func update_world(time: float) -> void:
	if body == null:
		return
	body.position.y = absf(sin(walking)) * 0.04 if moving else sin(time * 2.0) * 0.015
	for i in feet.size():
		feet[i].position.z = 0.1 + (sin(walking + float(i) * PI) * 0.16 if moving else 0.0)
	for i in arms.size():
		if has_clay:
			arms[i].rotation.x = CARRY_ARM_PITCH
		elif moving:
			arms[i].rotation.x = sin(walking + float(i) * PI) * 0.45
		else:
			arms[i].rotation.x = 0.0
	head.rotation.z = sin(walking * 0.5) * 0.015 if moving else sin(time * 0.7) * 0.02
	if moving:
		return
	var beat := fmod(time, IDLE_BEAT)
	var gesture := 0.0
	if beat > IDLE_GESTURE_START and beat < IDLE_GESTURE_START + IDLE_GESTURE_LENGTH:
		gesture = sin((beat - IDLE_GESTURE_START) / IDLE_GESTURE_LENGTH * PI)
	head.rotation.y = gesture * 0.15
	if not arms.is_empty():
		arms[0].rotation.x -= gesture * 0.65


## world.js:296 — the carried statue rides on the chest at 45% scale.
func set_carried(node: Node3D) -> void:
	if carry_slot == null:
		return
	for child in carry_slot.get_children():
		child.queue_free()
	has_clay = node != null
	if node == null:
		return
	node.scale = Vector3.ONE * 0.45
	node.position = Vector3.ZERO
	carry_slot.add_child(node)
