extends RefCounted
## 与 JS 版 `legacy/web-demo/src/sculpture.js` 的逐值对拍。
##
## golden 由 `node art/tools/golden_sculpture.mjs` 生成，里面是旧版算法跑出来的
## 结果（像素哈希、评分、抓边坐标）。移植只要有一个取整写错，这里就会红。

const GOLDEN_PATH := "res://tests/data/sculpture_golden.json"


func _hash(pixels: PackedByteArray) -> String:
	var h := 0x811c9dc5
	for value in pixels:
		h = h ^ value
		h = h & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return "%08x" % h


func _counts(pixels: PackedByteArray) -> Array:
	var counts := [0, 0, 0]
	for value in pixels:
		if value < 3:
			counts[value] += 1
	return counts


func _load_golden(report: TestReport) -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		report.error("缺少 golden：%s（先跑 node art/tools/golden_sculpture.mjs）" % GOLDEN_PATH)
		return {}
	var text := FileAccess.get_file_as_string(GOLDEN_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		report.error("golden 解析失败：" + GOLDEN_PATH)
		return {}
	return parsed


func run(report: TestReport) -> void:
	var golden := _load_golden(report)
	if golden.is_empty():
		return

	_check_targets(report, golden)
	_check_blank(report, golden)
	_check_supplied(report, golden)
	_check_strokes(report, golden)
	_check_compares(report, golden)
	_check_edges(report, golden)


func _check_targets(report: TestReport, golden: Dictionary) -> void:
	var targets: Dictionary = golden["targets"]
	for id in targets:
		var expected: Dictionary = targets[id]
		var pixels := Sculpture.create_target(StringName(id))
		report.eq(_hash(pixels), String(expected["hash"]), "目标图案 %s 的像素哈希" % id)
		report.eq(_counts(pixels), _to_int_array(expected["counts"]), "目标图案 %s 的颜色计数" % id)


func _check_blank(report: TestReport, golden: Dictionary) -> void:
	var expected: Dictionary = golden["blank"]
	var pixels := Sculpture.make_blank()
	report.eq(_hash(pixels), String(expected["hash"]), "空白泥团的像素哈希")
	report.eq(_counts(pixels), _to_int_array(expected["counts"]), "空白泥团的颜色计数")


func _check_supplied(report: TestReport, golden: Dictionary) -> void:
	var supplied: Dictionary = golden["supplied"]
	for id in supplied:
		var target := Sculpture.create_target(StringName(id))
		for level in supplied[id]:
			var expected := String(supplied[id][level])
			var pixels := Sculpture.supplied_clay(target, int(level))
			report.eq(_hash(pixels), expected, "供泥 %s 等级 %s" % [id, level])


func _check_strokes(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["strokes"]:
		var design := String(entry["design"])
		var target := Sculpture.create_target(StringName(design))
		var path: Array = entry["path"]
		var radius := float(entry["radius"]) if entry.has("radius") else 18.0
		var pixels: PackedByteArray
		var changed := false
		var flags: Array = []
		if String(entry.get("kind", "brush")) == "push":
			var level := int(entry["level"])
			pixels = Sculpture.supplied_clay(target, level)
			var grab: Variant = _grab_from_json(entry["firstGrab"])
			for i in range(1, path.size()):
				var from_point: Array = path[i - 1]
				var to_point: Array = path[i]
				var did := Sculpture.push_clay(
					pixels,
					float(from_point[0]),
					float(from_point[1]),
					float(to_point[0]),
					float(to_point[1]),
					radius,
					grab,
					{"target": target, "level": level, "symmetric": true}
				)
				flags.append(did)
				grab = Sculpture.clay_edge(
					pixels, float(to_point[0]), float(to_point[1]), radius
				)
			changed = flags.any(func(value): return value)
		else:
			pixels = Sculpture.supplied_clay(target, 2)
			var tool := String(entry["tool"])
			var color := int(entry["color"])
			for i in range(1, path.size()):
				var from_point: Array = path[i - 1]
				var to_point: Array = path[i]
				var did := Sculpture.apply_brush(
					pixels,
					float(from_point[0]),
					float(from_point[1]),
					float(to_point[0]),
					float(to_point[1]),
					radius,
					tool,
					color
				)
				changed = changed or did
		if String(entry.get("kind", "brush")) == "push":
			report.eq(flags, entry["changed"], "笔画 %s 每段是否改动" % entry["name"])
			changed = flags.any(func(value): return value)
		else:
			report.eq(changed, bool(entry["changed"]), "笔画 %s 是否改动" % entry["name"])
		report.eq(_hash(pixels), String(entry["hash"]), "笔画 %s 的像素哈希" % entry["name"])


func _check_compares(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["compares"]:
		var design := String(entry["design"])
		var target := Sculpture.create_target(StringName(design))
		var actual := _actual_for(String(entry["name"]), target)
		var result := Sculpture.compare(actual, target)
		for key in ["score", "shape", "paint"]:
			var expected := float(entry[key])
			var got := float(result[key])
			report.ok(
				absf(got - expected) < 0.05,
				"评分 %s 的 %s" % [entry["name"], key],
				"期望 %.1f，实际 %.1f" % [expected, got]
			)
		report.eq(bool(result["passed"]), bool(entry["passed"]), "评分 %s 是否过关" % entry["name"])
		report.eq(int(result["missing"]), int(entry["missing"]), "评分 %s 的缺失像素" % entry["name"])
		report.eq(int(result["excess"]), int(entry["excess"]), "评分 %s 的多余像素" % entry["name"])


## 与 golden 生成脚本里的 actual() 一一对应。
func _actual_for(name: String, target: PackedByteArray) -> PackedByteArray:
	match name:
		"target-vs-target":
			return target.duplicate()
		"blank-vs-target", "blank-vs-dot-jar":
			return Sculpture.make_blank()
		"supplied2-vs-target":
			return Sculpture.supplied_clay(target, 2)
		"supplied3-vs-target":
			return Sculpture.supplied_clay(target, 3)
		"painted-vs-band-pot":
			var pixels := Sculpture.supplied_clay(target, 3)
			Sculpture.apply_brush(pixels, 20, 60, 92, 60, 6, "paint", 2)
			Sculpture.apply_brush(pixels, 20, 40, 92, 40, 6, "paint", 2)
			return pixels
		"carved-vs-moon-jar":
			var pixels := Sculpture.supplied_clay(target, 3)
			Sculpture.apply_brush(pixels, 10, 10, 10, 100, 10, "cut", 2)
			return pixels
	push_error("golden 里出现未知的评分用例：" + name)
	return Sculpture.make_blank()


func _check_edges(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["edges"]:
		var design := String(entry["design"])
		var target := Sculpture.create_target(StringName(design))
		var pixels := Sculpture.supplied_clay(target, 3)
		var got: Variant = Sculpture.clay_edge(
			pixels, float(entry["x"]), float(entry["y"]), float(entry["radius"])
		)
		var expected: Variant = entry["result"]
		var label := "抓边 %s (%.0f,%.0f)" % [design, float(entry["x"]), float(entry["y"])]
		if expected == null:
			report.ok(got == null, label + " 应抓不到", "实际 %s" % [got])
			continue
		if got == null:
			report.ok(false, label + " 应抓到", "实际 null")
			continue
		var want: Dictionary = expected
		report.ok(absf(float(got["x"]) - float(want["x"])) < 0.01, label + " 的 x")
		report.ok(absf(float(got["y"]) - float(want["y"])) < 0.01, label + " 的 y")
		report.eq(bool(got["horizontal"]), bool(want["horizontal"]), label + " 的方向")
		report.eq(bool(got["fromLeft"]), bool(want["fromLeft"]), label + " 的起始侧")


func _grab_from_json(value: Variant) -> Variant:
	if value == null:
		return null
	var source: Dictionary = value
	return {
		"x": float(source["x"]),
		"y": float(source["y"]),
		"horizontal": bool(source["horizontal"]),
		"fromLeft": bool(source["fromLeft"]),
	}


func _to_int_array(values: Array) -> Array:
	var result := []
	for value in values:
		result.append(int(value))
	return result
