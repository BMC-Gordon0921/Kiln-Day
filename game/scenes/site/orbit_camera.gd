class_name OrbitCamera
extends Camera3D

## Orbit camera matching legacy/web-demo/src/world.js:164-200.
## three.js builds the position from spherical coordinates around TARGET; Godot's
## orthographic `size` plays the role of `camera.zoom`.

const TARGET := Vector3(-0.2, 0.7, -0.7)
const HOME_EYE := Vector3(10.0, 17.0, 20.0)
const POLAR_MIN := 0.4188790204786391   # deg_to_rad(24)
const POLAR_MAX := 1.5707963267948966   # PI/2
const ZOOM_MIN := 0.62
const ZOOM_MAX := 2.6
const DRAG_AZIMUTH := 0.0062
const DRAG_POLAR := 0.005
const WHEEL_ZOOM := 0.0012
const HOME_DURATION := 0.65
const MIN_VIEW_HEIGHT := 15.8
const ASPECT_NUMERATOR := 24.0

var azimuth := 0.0
var polar := 0.0
var radius := 28.0
var zoom := 1.0
var view_height := MIN_VIEW_HEIGHT
var interaction_enabled := true

var _home_azimuth := 0.0
var _home_polar := 0.0
var _home_radius := 28.0
var _dragging := false
var _tween: Tween


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 0.1
	far = 140.0
	var offset := HOME_EYE - TARGET
	_home_radius = offset.length()
	_home_azimuth = atan2(offset.x, offset.z)
	_home_polar = acos(clampf(offset.y / _home_radius, -1.0, 1.0))
	go_home(true)


func go_home(immediate := false) -> void:
	if immediate:
		azimuth = _home_azimuth
		polar = _home_polar
		radius = _home_radius
		zoom = 1.0
		apply()
		return
	_animate(_home_azimuth, _home_polar, 1.0)


func is_home() -> bool:
	return absf(azimuth - _home_azimuth) < 0.0005 and absf(zoom - 1.0) < 0.0005


func apply() -> void:
	var s := sin(polar)
	var c := cos(polar)
	position = Vector3(
		TARGET.x + radius * s * sin(azimuth),
		TARGET.y + radius * c,
		TARGET.z + radius * s * cos(azimuth)
	)
	look_at(TARGET, Vector3.UP)
	size = view_height / zoom


func apply_viewport(width: float, height: float, preview := false) -> void:
	var aspect: float = maxf(width, 1.0) / maxf(height, 1.0)
	var base: float = maxf(23.0, 32.0 / aspect) if preview else maxf(MIN_VIEW_HEIGHT, ASPECT_NUMERATOR / aspect)
	view_height = base
	apply()


func _animate(to_azimuth: float, to_polar: float, to_zoom: float) -> void:
	var delta := euclidean_modulo(to_azimuth - azimuth + PI, TAU) - PI
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_step_tween.bind(azimuth, azimuth + delta, polar, to_polar, zoom, to_zoom), 0.0, 1.0, HOME_DURATION)


func _step_tween(progress: float, from_az: float, to_az: float, from_polar: float, to_polar: float, from_zoom: float, to_zoom: float) -> void:
	var eased := progress * progress * (3.0 - 2.0 * progress)
	azimuth = lerpf(from_az, to_az, eased)
	polar = lerpf(from_polar, to_polar, eased)
	zoom = lerpf(from_zoom, to_zoom, eased)
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(WHEEL_ZOOM * 60.0)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(-WHEEL_ZOOM * 60.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if _tween and _tween.is_valid():
			_tween.kill()
		azimuth -= motion.relative.x * DRAG_AZIMUTH
		polar = clampf(polar + motion.relative.y * DRAG_POLAR, POLAR_MIN, POLAR_MAX)
		apply()
		get_viewport().set_input_as_handled()


func _zoom_by(amount: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	zoom = clampf(zoom * exp(amount), ZOOM_MIN, ZOOM_MAX)
	apply()


static func euclidean_modulo(value: float, modulus: float) -> float:
	var r := fmod(value, modulus)
	return r + modulus if r < 0.0 else r
