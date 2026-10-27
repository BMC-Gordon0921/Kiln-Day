class_name SiteMotion
extends RefCounted

## Movement maths ported from `world.js` move() (legacy/web-demo/src/world.js:260).
##
## Three details are load-bearing and easy to get wrong:
##   1) input is normalised *before* the camera basis is applied, so diagonal
##      walking is not faster;
##   2) the two axes are tried separately, which lets the actor slide along a
##      bench instead of sticking to it;
##   3) the camera right vector is flattened onto the ground plane and the
##      forward axis is `right × up`, matching the three.js build exactly.
##
## No nodes here on purpose: the headless suite checks this behaviour directly.

## Returns {"position": Vector2, "facing": float, "moved": bool}.
## `position` is the (x, z) pair; `facing` only means something when moved.
static func walk(position: Vector2, dx: float, dz: float, dt: float,
		right: Vector3, forward: Vector3) -> Dictionary:
	if is_zero_approx(dx) and is_zero_approx(dz):
		return {"position": position, "facing": 0.0, "moved": false}

	var length := sqrt(dx * dx + dz * dz)
	var nx := dx / length
	var nz := dz / length
	var vx := right.x * nx + forward.x * nz
	var vz := right.z * nx + forward.z * nz

	var step_size := SiteLayout.WALK_SPEED * dt
	var result := position
	if SiteLayout.can_move(result.x + vx * step_size, result.y):
		result.x += vx * step_size
	if SiteLayout.can_move(result.x, result.y + vz * step_size):
		result.y += vz * step_size

	return {
		"position": result,
		"facing": atan2(vx, vz),
		"moved": result.distance_squared_to(position) > 1e-8,
	}


## Camera basis on the ground plane: [right, forward], both unit length.
static func camera_axes(camera: Node3D) -> Array:
	var right := Vector3.RIGHT
	if camera != null:
		right = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	right = right.normalized()
	return [right, right.cross(Vector3.UP)]


## Shortest-arc turn towards `target`, eased by SiteLayout.TURN_RATE per second.
static func turn(current: float, target: float, dt: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff * minf(1.0, dt * SiteLayout.TURN_RATE)


## world.js nearest(): distance to the station rectangle, closest wins.
static func nearest(x: float, z: float, radius := SiteLayout.INTERACT_RADIUS) -> Dictionary:
	return SiteLayout.nearest(x, z, radius)
