class_name HeatBar
extends Control
## 烧窑面板里的热度条：横轴是 12 秒进度，纵轴是 0…1 的热度。
## 绿色 = 完美带，黄色 = 可用带，白点是当前热度。

var run: KilnRun


func _ready() -> void:
	custom_minimum_size = Vector2(360, 220)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.09, 0.1, 1.0))
	if run == null:
		return

	var band := Workshop.fire_band(run.level)
	var center := run.band_center()
	var good := float(band["good"])
	var perfect := float(band["perfect"])
	# 带子跟着当前时刻的漂移中心走，只画当前一列，读起来像"火在呼吸"。
	var column := Rect2(rect.size.x - 6.0, 0.0, 6.0, rect.size.y)
	draw_rect(column, Color(0.85, 0.75, 0.5, 0.9))
	draw_v_band(rect, center + good, center - good, Color(0.85, 0.66, 0.2, 0.35))
	draw_v_band(rect, center + perfect, center - perfect, Color(0.35, 0.85, 0.45, 0.55))

	# 进度线
	var progress_x := rect.size.x * run.progress()
	draw_line(Vector2(progress_x, 0), Vector2(progress_x, rect.size.y), Color(1, 1, 1, 0.18), 1.0)

	# 当前热度
	var heat_y := rect.size.y * (1.0 - run.heat)
	draw_line(Vector2(0, heat_y), Vector2(rect.size.x, heat_y), Color(1, 1, 1, 0.85), 2.0)
	var marker := Color(0.95, 0.95, 0.95)
	if run.in_perfect():
		marker = Color(0.4, 1.0, 0.5)
	elif run.in_good():
		marker = Color(1.0, 0.86, 0.3)
	draw_circle(Vector2(rect.size.x - 12.0, heat_y), 6.0, marker)
	draw_rect(rect, Color(0.86, 0.82, 0.72, 0.4), false, 2.0)


func draw_v_band(rect: Rect2, top: float, bottom: float, color: Color) -> void:
	var y0 := rect.size.y * (1.0 - top)
	var y1 := rect.size.y * (1.0 - bottom)
	draw_rect(Rect2(0, y0, rect.size.x, maxf(1.0, y1 - y0)), color)
