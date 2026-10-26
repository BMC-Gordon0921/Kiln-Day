class_name SiteLayout
extends RefCounted

## Layout numbers copied from the three.js build (legacy/web-demo/src/world.js:26-33).
## Changing a number here means the Godot scene no longer matches the reference.

const STATIONS := [
	{"id": "clay", "name": "取泥与订单", "x": -5.65, "z": -3.65, "w": 2.1, "d": 1.45,
		"approach": Vector2(-5.65, -2.05), "label_y": 2.0},
	{"id": "wheel", "name": "粗塑成形", "x": -2.7, "z": -3.65, "w": 1.8, "d": 1.6,
		"approach": Vector2(-2.7, -1.95), "label_y": 2.05},
	{"id": "carve", "name": "细节雕刻", "x": 0.4, "z": -3.65, "w": 2.35, "d": 1.45,
		"approach": Vector2(0.4, -2.05), "label_y": 2.0},
	{"id": "paint", "name": "手绘上色", "x": -1.25, "z": 1.35, "w": 2.4, "d": 1.45,
		"approach": Vector2(-1.25, 2.95), "label_y": 1.9},
	{"id": "kiln", "name": "瓷器窑炉", "x": -5.65, "z": 0.3, "w": 2.2, "d": 2.1,
		"approach": Vector2(-3.95, 0.3), "label_y": 2.7},
	{"id": "serve", "name": "评分与交付", "x": 3.2, "z": 0.0, "w": 1.25, "d": 3.1,
		"approach": Vector2(1.7, 0.0), "label_y": 2.05},
]

## world.js: MIN/MAX of canMove() and the player capsule radius.
const BOUND_MIN_X := -7.76
const BOUND_MAX_X := 2.45
const BOUND_MIN_Z := -4.9
const BOUND_MAX_Z := 5.13
const BODY_RADIUS := 0.37

const PLAYER_SPAWN := Vector2(-4.55, -2.15)
const PLAYER_FACING := -0.2
const WALK_SPEED := 3.35
const TURN_RATE := 15.0
const WALK_STRIDE_RATE := 11.0
const INTERACT_RADIUS := 1.04

const CUSTOMERS := [
	{"species": "rabbit", "x": 4.9, "z": -0.25, "coat": 0xb996a0},
	{"species": "bear", "x": 4.95, "z": 1.65, "coat": 0xbc9d5e},
	{"species": "cat", "x": 4.98, "z": 3.35, "coat": 0x92a292},
]


static func station(id: String) -> Dictionary:
	for entry in STATIONS:
		if entry["id"] == id:
			return entry
	return {}


static func station_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in STATIONS:
		ids.append(entry["id"])
	return ids


## world.js canMove(): outer bounds plus one expanded rect per station.
static func can_move(x: float, z: float) -> bool:
	if x < BOUND_MIN_X or x > BOUND_MAX_X or z < BOUND_MIN_Z or z > BOUND_MAX_Z:
		return false
	for entry in STATIONS:
		var half_w: float = entry["w"] * 0.5 + BODY_RADIUS
		var half_d: float = entry["d"] * 0.5 + BODY_RADIUS
		if absf(x - entry["x"]) < half_w and absf(z - entry["z"]) < half_d:
			return false
	return true


## world.js nearest(): distance to the station rect (not its centre), first match wins.
static func nearest(x: float, z: float, radius := INTERACT_RADIUS) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for entry in STATIONS:
		var dx: float = maxf(absf(x - entry["x"]) - entry["w"] * 0.5, 0.0)
		var dz: float = maxf(absf(z - entry["z"]) - entry["d"] * 0.5, 0.0)
		var distance := sqrt(dx * dx + dz * dz)
		if distance < radius and distance < best_distance:
			best = entry
			best_distance = distance
	return best


static func approach(id: String) -> Vector2:
	var entry := station(id)
	if entry.is_empty():
		return Vector2.ZERO
	return entry["approach"]
