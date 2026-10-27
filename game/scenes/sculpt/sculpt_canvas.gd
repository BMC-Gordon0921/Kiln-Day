class_name SculptCanvas
extends Control
## 把 112×112 的像素画布画出来，并把鼠标/触摸翻译成笔画。
##
## 只负责显示与坐标换算；像素运算全在 SculptSession / Sculpture 里。

signal stroke_changed
signal stroke_finished

const DISPLAY_SIZE := 504.0

var session: SculptSession
var tool := "push"
var brush_radius := 6.0

var _image: Image
var _texture: ImageTexture
var _ghost: Image
var _ghost_texture: ImageTexture
var _drawing := false

## Theme hooks so the canvas can sit on paper instead of the dark workshop panel.
var background := Color(0.08, 0.08, 0.09, 1.0)
var empty_color := Color(0.13, 0.12, 0.12, 1.0)


func _ready() -> void:
	custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE


func set_session(p_session: SculptSession) -> void:
	session = p_session
	_image = Image.create(Sculpture.SIZE, Sculpture.SIZE, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_ghost = Image.create(Sculpture.SIZE, Sculpture.SIZE, false, Image.FORMAT_RGBA8)
	_ghost.fill(Color(0, 0, 0, 0))
	for i in session.target.size():
		if session.target[i] != 0:
			_ghost.set_pixel(i % Sculpture.SIZE, i / Sculpture.SIZE, Color(0.45, 0.85, 1.0, 0.30))
	_ghost_texture = ImageTexture.create_from_image(_ghost)
	refresh()


## 把 session 里的像素刷到贴图上。笔画结束、撤销、换工具时调用。
func refresh() -> void:
	if session == null or _image == null:
		return
	for i in session.pixels.size():
		var value := session.pixels[i]
		var color := Sculpture.palette_color(value)
		# 空白格画成深色泥底，让"还没刻"的区域看得见。
		if value == 0:
			color = empty_color
		_image.set_pixel(i % Sculpture.SIZE, i / Sculpture.SIZE, color)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, background)
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
	if _ghost_texture != null:
		draw_texture_rect(_ghost_texture, rect, false)
	draw_rect(rect, Color(0.86, 0.82, 0.72, 0.55), false, 2.0)


func _to_canvas(position: Vector2) -> Vector2:
	return Vector2(
		position.x / maxf(1.0, size.x) * Sculpture.SIZE,
		position.y / maxf(1.0, size.y) * Sculpture.SIZE
	)


func _gui_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(_to_canvas(event.position))
		else:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and _drawing:
		_move(_to_canvas(event.position))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin(_to_canvas(event.position))
		else:
			_end()
		accept_event()
	elif event is InputEventScreenDrag:
		_move(_to_canvas(event.position))
		accept_event()


func _begin(point: Vector2) -> void:
	_drawing = true
	session.radius = 18.0 if tool == "push" else brush_radius
	session.stroke_begin(point, tool)
	refresh()
	stroke_changed.emit()


func _move(point: Vector2) -> void:
	if session.stroke_move(point):
		refresh()
		stroke_changed.emit()


func _end() -> void:
	if not _drawing:
		return
	_drawing = false
	session.stroke_end()
	refresh()
	stroke_finished.emit()
