class_name Sculpture
extends RefCounted
## 112×112 浮雕画布：0 空白 / 1 瓷白 / 2 钴蓝。
##
## 逐函数对照 `legacy/web-demo/src/sculpture.js` 移植。这里的每一个取整、每一个
## 边界都是旧版行为的复刻，别"顺手优化"——`tests/cases/test_sculpture.gd` 会拿
## JS 生成的 goldens 逐值对拍，改了就会红。

const SIZE := KilnConstants.SIZE
const PASS_SCORE := KilnConstants.PASS_SCORE

## 与旧版 `PRESETS` 的 id 一一对应（器型数据在 data/catalog.json）。
const PRESET_IDS: PackedStringArray = ["band-pot", "tall-pot", "dot-jar", "rim-pot", "moon-jar"]

## 调色板：索引 0 透明（没有泥），1 瓷白，2 钴蓝。
static func palette_color(index: int) -> Color:
	match index:
		1:
			return Color("f2efe5")
		2:
			return Color("315fa9")
		_:
			return Color(0, 0, 0, 0)


## 旧版 `Math.round`：.5 一律向 +∞ 取整，与 GDScript 的 roundi() 不同。
static func _js_round(value: float) -> int:
	return int(floor(value + 0.5))


static func _ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	return pow((x - cx) / rx, 2.0) + pow((y - cy) / ry, 2.0) <= 1.0


static func _rect(x: float, y: float, left: float, top: float, right: float, bottom: float) -> bool:
	return x >= left and x <= right and y >= top and y <= bottom


## 奇偶规则的点在多边形内判定。
static func _poly(x: float, y: float, points: PackedVector2Array) -> bool:
	var inside := false
	var count := points.size()
	var j := count - 1
	for i in count:
		var xi := points[i].x
		var yi := points[i].y
		var xj := points[j].x
		var yj := points[j].y
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
			inside = not inside
		j = i
	return inside


## 单个目标像素。x/y 是 0…100 的设计坐标（不是画布索引）。
static func target_pixel(id: StringName, x: float, y: float) -> int:
	var shape := false
	var color := 1
	match id:
		&"band-pot":
			var r := 0.0
			if y < 31.0:
				r = 14.0
			elif y < 53.0:
				r = 14.0 + 15.0 * sin((y - 31.0) / 22.0 * PI / 2.0)
			else:
				r = 29.0 * sqrt(maxf(0.0, 1.0 - pow((y - 53.0) / 43.0, 2.0)))
			shape = y >= 19.0 and y <= 84.0 and absf(x - 50.0) <= r
			if y >= 54.0 and y <= 66.0:
				color = 2
		&"tall-pot":
			var r := 0.0
			if y < 29.0:
				r = 12.0
			elif y < 43.0:
				r = 12.0 + (y - 29.0) * 0.65
			elif y < 76.0:
				r = 21.1
			else:
				r = 21.1 - (y - 76.0) * 0.2
			shape = y >= 12.0 and y <= 88.0 and absf(x - 50.0) <= r
			if (y >= 46.0 and y <= 56.0) or (y >= 69.0 and y <= 79.0):
				color = 2
		&"dot-jar":
			shape = _poly(x, y, PackedVector2Array([
				Vector2(29, 23), Vector2(71, 23), Vector2(80, 36), Vector2(80, 76),
				Vector2(70, 85), Vector2(30, 85), Vector2(20, 76), Vector2(20, 36),
			]))
			if (
				_ellipse(x, y, 33, 55, 6, 6)
				or _ellipse(x, y, 50, 55, 6, 6)
				or _ellipse(x, y, 67, 55, 6, 6)
			):
				color = 2
		&"rim-pot":
			shape = _poly(x, y, PackedVector2Array([
				Vector2(18, 24), Vector2(82, 24), Vector2(82, 37), Vector2(76, 37),
				Vector2(68, 85), Vector2(32, 85), Vector2(24, 37), Vector2(18, 37),
			]))
			if y <= 37.0:
				color = 2
		&"moon-jar":
			shape = _ellipse(x, y, 50, 56, 31, 31) or _rect(x, y, 39, 18, 61, 36)
			if y >= 38.0 and y <= 77.0 and ((x >= 33.0 and x <= 43.0) or (x >= 57.0 and x <= 67.0)):
				color = 2
		_:
			return 0
	return color if shape else 0


## 目标图案（每格是调色板索引）。
static func create_target(id: StringName) -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			pixels[y * SIZE + x] = target_pixel(
				id, (x + 0.5) / SIZE * 100.0, (y + 0.5) / SIZE * 100.0
			)
	return pixels


## 初始泥团：一个圆角方块，不含任何目标形状信息。
static func make_blank() -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(SIZE * SIZE)
	var half := SIZE / 2.0
	for y in SIZE:
		for x in SIZE:
			var nx := absf((x + 0.5 - half) / (SIZE * 0.455))
			var ny := absf((y + 0.5 - half) / (SIZE * 0.445))
			if pow(nx, 4.0) + pow(ny, 4.0) <= 1.0:
				pixels[y * SIZE + x] = 1
	return pixels


## 某一行的左右边界。整行为空时返回 left=SIZE, right=SIZE-1（和旧版一致）。
static func row_bounds(pixels: PackedByteArray, row: int, horizontal := true) -> Dictionary:
	var left := 0
	var right := SIZE - 1
	if horizontal:
		while left < SIZE and pixels[row * SIZE + left] == 0:
			left += 1
		while right >= left and pixels[row * SIZE + right] == 0:
			right -= 1
	else:
		while left < SIZE and pixels[left * SIZE + row] == 0:
			left += 1
		while right >= left and pixels[right * SIZE + row] == 0:
			right -= 1
	return {"left": left, "right": right}


static func _vertical_bounds(pixels: PackedByteArray) -> Dictionary:
	var top := 0
	var bottom := SIZE - 1
	while top < SIZE:
		var bounds := row_bounds(pixels, top)
		if int(bounds["right"]) >= int(bounds["left"]):
			break
		top += 1
	while bottom > top:
		var bounds := row_bounds(pixels, bottom)
		if int(bounds["right"]) >= int(bounds["left"]):
			break
		bottom -= 1
	return {"top": top, "bottom": bottom}


## 捏泥台的初始供泥：按台位等级把空白泥团往目标外轮廓靠 0 / 30% / 50%。
static func supplied_clay(target: PackedByteArray, level := 1) -> PackedByteArray:
	var blank := make_blank()
	var amounts := [0.0, 0.3, 0.5]
	var amount := 0.0
	if level >= 1 and level <= amounts.size():
		amount = amounts[level - 1]
	if amount == 0.0:
		return blank

	var result := PackedByteArray()
	result.resize(SIZE * SIZE)
	var b := _vertical_bounds(blank)
	var t := _vertical_bounds(target)
	var top := _js_round(float(b["top"]) + (float(t["top"]) - float(b["top"])) * amount)
	var bottom := _js_round(float(b["bottom"]) + (float(t["bottom"]) - float(b["bottom"])) * amount)
	if bottom <= top:
		return result
	for y in range(top, bottom + 1):
		var f := float(y - top) / float(bottom - top)
		var br := row_bounds(blank, _js_round(float(b["top"]) + f * float(b["bottom"] - b["top"])))
		var tr := row_bounds(target, _js_round(float(t["top"]) + f * float(t["bottom"] - t["top"])))
		var left := _js_round(float(br["left"]) + (float(tr["left"]) - float(br["left"])) * amount)
		var right := _js_round(float(br["right"]) + (float(tr["right"]) - float(br["right"])) * amount)
		for x in range(left, right + 1):
			if x >= 0 and x < SIZE:
				result[y * SIZE + x] = 1
	return result


## 雕刻台的"保护"：低等级只补内圈，高等级连外沿一起补。
static func protected_cut(
	pixels: PackedByteArray, before: PackedByteArray, target: PackedByteArray, level: int
) -> void:
	if level < 2:
		return
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			if target[i] == 0 or before[i] == 0 or pixels[i] != 0:
				continue
			var interior := (
				x > 0
				and y > 0
				and x < SIZE - 1
				and y < SIZE - 1
				and target[i - 1] != 0
				and target[i + 1] != 0
				and target[i - SIZE] != 0
				and target[i + SIZE] != 0
			)
			if level == 3 or interior:
				pixels[i] = before[i]


static func pixels_equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	return a == b


## 找一条外侧泥边。按下时算一次，之后整段拖动都沿用同一个 grab。
## 返回 {x, y, horizontal, fromLeft} 或 null。
static func clay_edge(pixels: PackedByteArray, x: float, y: float, radius := 18.0, tolerance := 0.0) -> Variant:
	if not is_finite(x + y + radius):
		return null
	radius = maxf(14.0, minf(26.0, radius)) + tolerance
	var best: Variant = null
	var distance := radius
	for horizontal in [true, false]:
		var cross := y if horizontal else x
		var from_row := maxi(0, int(floor(cross - radius)))
		var to_row := mini(SIZE, int(ceil(cross + radius)))
		for row in range(from_row, to_row):
			var left := 0
			var right := SIZE - 1
			if horizontal:
				while left < SIZE and pixels[row * SIZE + left] == 0:
					left += 1
				while right > left and pixels[row * SIZE + right] == 0:
					right -= 1
			else:
				while left < SIZE and pixels[left * SIZE + row] == 0:
					left += 1
				while right > left and pixels[right * SIZE + row] == 0:
					right -= 1
			if right - left < 5:
				continue
			for from_left in [true, false]:
				var along := (float(left) if from_left else float(right)) + 0.5
				var px := along if horizontal else float(row) + 0.5
				var py := float(row) + 0.5 if horizontal else along
				var d := sqrt(pow(px - x, 2.0) + pow(py - y, 2.0))
				if d < distance:
					distance = d
					best = {"x": px, "y": py, "horizontal": horizontal, "fromLeft": from_left}
	return best


## 拉坯：把 grab 所在的那条泥带整体压缩/拉伸，泥带上的颜色跟着走。
static func push_clay(
	pixels: PackedByteArray,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	radius := 18.0,
	grab: Variant = null,
	options := {}
) -> bool:
	if not is_finite(x0 + y0 + x1 + y1 + radius):
		return false
	radius = maxf(14.0, minf(26.0, radius))
	var dx := x1 - x0
	var dy := y1 - y0
	if sqrt(dx * dx + dy * dy) < 0.75:
		return false
	if grab == null:
		grab = clay_edge(pixels, x0, y0, radius)
	if grab == null or not (grab is Dictionary):
		return false

	var horizontal: bool = grab["horizontal"]
	var from_left: bool = grab["fromLeft"]
	var along := float(grab["x"]) if horizontal else float(grab["y"])
	var cross := float(grab["y"]) if horizontal else float(grab["x"])
	var raw_delta := dx if horizontal else dy
	var target: Variant = options.get("target", null)
	var level := int(options.get("level", 1))
	var symmetric := bool(options.get("symmetric", true))
	var delta := clampf(raw_delta, -28.0, 28.0) if target != null else raw_delta
	var before := pixels.duplicate()

	var from_row := maxi(0, int(floor(cross - radius)))
	var to_row := mini(SIZE, int(ceil(cross + radius)))
	for row in range(from_row, to_row):
		var left := 0
		var right := SIZE - 1
		if horizontal:
			while left < SIZE and before[row * SIZE + left] == 0:
				left += 1
			while right > left and before[row * SIZE + right] == 0:
				right -= 1
		else:
			while left < SIZE and before[left * SIZE + row] == 0:
				left += 1
			while right > left and before[right * SIZE + row] == 0:
				right -= 1
		if right - left < 5:
			continue
		var edge := left if from_left else right
		if absf(along - float(edge)) > radius:
			continue
		var d := absf(float(row) + 0.5 - cross) / radius
		if d >= 1.0:
			continue
		var influence := (1.0 + cos(d * PI)) / 2.0
		var shift := delta * influence
		if target != null and absf(delta) >= 0.75:
			var wanted_bounds := row_bounds(target, row, horizontal)
			var wanted := float(wanted_bounds["left"] if from_left else wanted_bounds["right"])
			var proposed := float(edge) + shift
			if int(wanted_bounds["right"]) >= int(wanted_bounds["left"]) and absf(wanted - proposed) <= level:
				var gains := [0.25, 0.4, 0.55]
				var gain: float = gains[clampi(level - 1, 0, 2)]
				shift += (wanted - proposed) * gain
		var new_left := left
		var new_right := right
		if from_left:
			new_left = maxi(0, mini(right - 5, _js_round(float(left) + shift)))
		else:
			new_right = mini(SIZE - 1, maxi(left + 5, _js_round(float(right) + shift)))
		if symmetric and horizontal:
			if from_left:
				new_right = mini(SIZE - 1, maxi(new_left + 5, right - (new_left - left)))
			else:
				new_left = maxi(0, mini(new_right - 5, left - (new_right - right)))
		var span := maxi(right, new_right) - mini(left, new_left)
		for a in range(mini(left, new_left), maxi(right, new_right) + 1):
			_set_pixel(pixels, a, row, horizontal, 0)
		for a in range(new_left, new_right + 1):
			if span <= 0:
				continue
			var src := _js_round(
				float(left) + float(a - new_left) / float(new_right - new_left) * float(right - left)
			)
			_set_pixel(pixels, a, row, horizontal, _get_pixel(before, src, row, horizontal))

	for i in pixels.size():
		if pixels[i] != before[i]:
			return true
	return false


static func _set_pixel(pixels: PackedByteArray, a: int, b: int, horizontal: bool, value: int) -> void:
	if a < 0 or a >= SIZE or b < 0 or b >= SIZE:
		return
	pixels[(b * SIZE + a) if horizontal else (a * SIZE + b)] = value


static func _get_pixel(pixels: PackedByteArray, a: int, b: int, horizontal: bool) -> int:
	if a < 0 or a >= SIZE or b < 0 or b >= SIZE:
		return 0
	return pixels[(b * SIZE + a) if horizontal else (a * SIZE + b)]


## 笔刷：沿 (x0,y0)→(x1,y1) 扫一遍。
## tool: "cut" 刮掉 / "add" 填泥 / "paint" 上色（只作用在已有泥的地方）。
static func apply_brush(
	pixels: PackedByteArray,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	radius: float,
	tool: String,
	color := 2
) -> bool:
	if not is_finite(x0 + y0 + x1 + y1 + radius) or radius <= 0.0:
		return false
	var left := maxi(0, int(floor(minf(x0, x1) - radius)))
	var right := mini(SIZE - 1, int(ceil(maxf(x0, x1) + radius)))
	var top := maxi(0, int(floor(minf(y0, y1) - radius)))
	var bottom := mini(SIZE - 1, int(ceil(maxf(y0, y1) + radius)))
	var vx := x1 - x0
	var vy := y1 - y0
	var length := vx * vx + vy * vy
	var changed := false
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var t := 0.0
			if length > 0.0:
				t = clampf(((x + 0.5 - x0) * vx + (y + 0.5 - y0) * vy) / length, 0.0, 1.0)
			var px := x + 0.5 - (x0 + t * vx)
			var py := y + 0.5 - (y0 + t * vy)
			if px * px + py * py > radius * radius:
				continue
			var i := y * SIZE + x
			var old := pixels[i]
			var next := old
			match tool:
				"cut":
					next = 0
				"add":
					next = old if old != 0 else 1
				_:
					next = color if old != 0 else 0
			if next != old:
				pixels[i] = next
				changed = true
	return changed


## 评分：形状 IoU 占 65%，每类颜色的 F1 占 35%。
## 分数向下取到 0.1，避免 79.99 显示成 80 却判失败。
static func compare(actual: PackedByteArray, target: PackedByteArray) -> Dictionary:
	var intersection := 0
	var union := 0
	var missing := 0
	var excess := 0
	var expected := [0, 0, 0]
	var predicted := [0, 0, 0]
	var correct := [0, 0, 0]
	for i in target.size():
		var a := actual[i] if i < actual.size() else 0
		var b := target[i]
		if a != 0 or b != 0:
			union += 1
		if a != 0 and b != 0:
			intersection += 1
		if a != 0 and b == 0:
			excess += 1
		if b != 0 and a == 0:
			missing += 1
		if b < 3:
			expected[b] += 1
		if a < 3:
			predicted[a] += 1
		if a == b and b != 0 and b < 3:
			correct[b] += 1
	var shape := 0.0
	if union > 0:
		shape = float(intersection) / float(union) * 100.0
	var paint := 0.0
	var classes := 0
	for c in range(1, 3):
		if expected[c] != 0 or predicted[c] != 0:
			paint += (2.0 * float(correct[c]) / float(expected[c] + predicted[c])) * 100.0
			classes += 1
	if classes > 0:
		paint /= float(classes)
	var raw := shape * 0.65 + paint * 0.35
	return {
		"score": floor(raw * 10.0 + 1e-8) / 10.0,
		"shape": floor(shape * 10.0 + 1e-8) / 10.0,
		"paint": floor(paint * 10.0 + 1e-8) / 10.0,
		"passed": raw + 1e-9 >= float(PASS_SCORE),
		"missing": missing,
		"excess": excess,
	}
