class_name KilnIcon
extends Control
## Small drawn illustration of the egg kiln for the firing sheet.


var heat := 0.0
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if heat <= 0.01:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var base_y := size.y * 0.86
	var body_w := 150.0
	var body_h := 96.0
	var clunch := Color("f0dcc0")
	var clay := Color("d98a5d")
	var clay_dark := Color("b96f47")
	var dark := Color("4a3323")
	# plinth
	draw_rect(Rect2(cx - body_w * 0.62, base_y - 10, body_w * 1.24, 14), Color("cbb793"))
	# body
	draw_rect(Rect2(cx - body_w * 0.5, base_y - body_h, body_w, body_h), clay)
	var rows := 5
	for i in rows:
		var y := base_y - body_h + (i + 1) * body_h / float(rows + 1)
		draw_line(Vector2(cx - body_w * 0.5, y), Vector2(cx + body_w * 0.5, y), clunch, 2.0)
	# dome
	draw_circle(Vector2(cx, base_y - body_h + 2), body_w * 0.56, clay)
	draw_circle(Vector2(cx - 26, base_y - body_h - 16), body_w * 0.26, clay.lightened(0.06))
	# chimney
	draw_rect(Rect2(cx - 14, base_y - body_h - 96, 28, 52), clay_dark)
	draw_rect(Rect2(cx - 20, base_y - body_h - 100, 40, 10), clay_dark)
	# door
	draw_circle(Vector2(cx, base_y - 30), 30, dark)
	draw_rect(Rect2(cx - 30, base_y - 30, 60, 26), dark)
	draw_arc(Vector2(cx, base_y - 30), 34, PI, TAU, 24, clunch, 6.0, true)
	_draw_fire(cx, base_y - 30, base_y - body_h)


func _draw_fire(cx: float, door_y: float, _dome_y: float) -> void:
	var t := _t
	var glow := clampf(heat, 0.0, 1.0)
	for i in 5:
		var k := 1.0 - float(i) / 5.0
		var r := 26.0 + 20.0 * k + sin(t * 2.2 + i) * 2.0
		draw_circle(Vector2(cx, door_y + 4), r, Color(1.0, 0.52, 0.18, 0.05 * glow * k))
	for i in 3:
		var sway := sin(t * 3.0 + i * 1.7) * 6.0
		var h := (18.0 + 10.0 * i) * glow
		var base := Vector2(cx - 10.0 + i * 10.0 + sway, door_y + 18.0)
		var pts := PackedVector2Array([base, base + Vector2(-7, -h), base + Vector2(7, -h * 0.7)])
		draw_colored_polygon(pts, Color(1.0, 0.62 - 0.1 * i, 0.22, 0.55 * glow))
	for i in 6:
		var phase := fmod(t * 0.6 + i * 0.17, 1.0)
		var ex := cx + sin(i * 2.1 + t) * 18.0
		var ey := door_y - phase * 110.0
		var a := (1.0 - phase) * 0.7 * glow
		draw_circle(Vector2(ex, ey), 2.0 + phase * 1.5, Color(1.0, 0.72, 0.35, a))
