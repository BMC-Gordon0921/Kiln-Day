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
var _hover := false
var _mouse := Vector2.ZERO

## Theme hooks so the canvas can sit on paper instead of the dark workshop panel.
var background := Color(0.08, 0.08, 0.09, 1.0)
var empty_color := Color(0.13, 0.12, 0.12, 1.0)
## Dashed guide outline colour: cobalt for the kiln yard, rose for Taoxichuan.
var accent := Color("2f5d9e")


func _ready() -> void:
	mouse_exited.connect(_notify_exit)
	custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE


func debug_cursor_at(point: Vector2) -> void:
	_hover = true
	_mouse = point
	queue_redraw()


func radius_for_tool() -> float:
	return brush_radius * 3.0 if tool == "push" else brush_radius


func set_session(p_session: SculptSession) -> void:
	session = p_session
	_image = Image.create(Sculpture.SIZE, Sculpture.SIZE, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_ghost = Image.create(Sculpture.SIZE, Sculpture.SIZE, false, Image.FORMAT_RGBA8)
	_ghost.fill(Color(0, 0, 0, 0))
	var size: int = Sculpture.SIZE
	for i in session.target.size():
		if session.target[i] == 0:
			continue
		var x := i % size
		var y := i / size
		var edge := x == 0 or y == 0 or x == size - 1 or y == size - 1
		if not edge:
			edge = session.target[i - 1] == 0 or session.target[i + 1] == 0 				or session.target[i - size] == 0 or session.target[i + size] == 0
		if edge and (x + y) % 8 < 4:
			_ghost.set_pixel(x, y, Color(accent.r, accent.g, accent.b, 0.72))
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
	if _hover:
		var scale := size.x / float(Sculpture.SIZE)
		var radius := radius_for_tool() * scale
		draw_arc(_mouse, radius, 0.0, TAU, 48, Color(0.14, 0.2, 0.16, 0.7), 5.0)
		draw_arc(_mouse, radius, 0.0, TAU, 48, Color(1.0, 0.99, 0.93, 1.0), 2.2)
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
	elif event is InputEventMouseMotion:
		_hover = true
		_mouse = event.position
		queue_redraw()
		if _drawing:
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


func _notify_exit() -> void:
	_hover = false
	queue_redraw()


func _begin(point: Vector2) -> void:
	_drawing = true
	session.radius = radius_for_tool()
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
