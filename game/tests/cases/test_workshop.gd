extends RefCounted
## 与 JS 版 `legacy/web-demo/src/workshop.js` 的逐值对拍。
##
## 重点在烧窑漂移：它用 mulberry32 + 32 位无符号运算播种，
## 只要有一处按有符号整数算，整条曲线就会偏，这里会立刻红。

const GOLDEN_PATH := "res://tests/data/workshop_golden.json"


func run(report: TestReport) -> void:
	var golden := _load(report)
	if golden.is_empty():
		return
	_check_bands(report, golden)
	_check_drift(report, golden)
	_check_grades(report, golden)
	_check_incomes(report, golden)
	_check_elapsed(report, golden)
	_check_clocks(report, golden)


func _load(report: TestReport) -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		report.error("缺少 golden：%s（先跑 node art/tools/golden_workshop.mjs）" % GOLDEN_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if parsed == null or not (parsed is Dictionary):
		report.error("golden 解析失败：" + GOLDEN_PATH)
		return {}
	return parsed


func _check_bands(report: TestReport, golden: Dictionary) -> void:
	for level in golden["bands"]:
		var band := Workshop.fire_band(int(level))
		var expected: Dictionary = golden["bands"][level]
		report.ok(
			absf(float(band["good"]) - float(expected["good"])) < 1e-9,
			"火候带宽 等级 %s" % level,
			"期望 %s，实际 %s" % [expected["good"], band["good"]]
		)
		report.ok(
			absf(float(band["perfect"]) - float(expected["perfect"])) < 1e-9,
			"完美带 等级 %s" % level,
			"期望 %s，实际 %s" % [expected["perfect"], band["perfect"]]
		)


func _check_drift(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["drift"]:
		var drift := Workshop.create_fire_drift(int(entry["seed"]))
		var worst := 0.0
		for sample in entry["samples"]:
			var t := float(sample[0])
			var expected := float(sample[1])
			var got: float = drift.call(t)
			worst = maxf(worst, absf(got - expected))
		report.ok(
			worst < 1e-6,
			"烧窑漂移 种子 %s 逐点误差" % entry["seed"],
			"最大偏差 %.9f" % worst
		)


func _check_grades(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["grades"]:
		var seconds: Dictionary = entry["seconds"]
		report.eq(Workshop.fire_grade(seconds), String(entry["grade"]), "品级 %s" % [seconds])
		report.ok(
			absf(Workshop.fire_ratio(seconds) - float(entry["ratio"])) < 1e-6,
			"带内占比 %s" % [seconds],
			"期望 %s，实际 %s" % [entry["ratio"], Workshop.fire_ratio(seconds)]
		)


func _check_incomes(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["incomes"]:
		var result := Workshop.order_income(float(entry["base"]), entry["options"])
		var expected: Dictionary = entry["result"]
		for key in ["regularEarned", "kilnBonus", "serveBonus", "efficiencyBonus", "firstPassBonus", "earned"]:
			report.eq(int(result[key]), int(expected[key]), "结算 %s 的 %s" % [entry["base"], key])
		report.eq(
			bool(result["efficiency"]["qualified"]),
			bool(expected["efficiency"]["qualified"]),
			"结算 %s 的效率奖判定" % entry["base"]
		)


func _check_elapsed(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["elapsed"]:
		report.eq(Workshop.format_elapsed(float(entry["ms"])), String(entry["text"]), "计时显示 %s" % entry["ms"])


func _check_clocks(report: TestReport, golden: Dictionary) -> void:
	for entry in golden["clocks"]:
		var result := Workshop.clock_policy(entry["flags"])
		var expected: Dictionary = entry["result"]
		report.eq(bool(result["efficiency"]), bool(expected["efficiency"]), "计时器 效率 %s" % [entry["flags"]])
		report.eq(bool(result["kiln"]), bool(expected["kiln"]), "计时器 烧窑 %s" % [entry["flags"]])
