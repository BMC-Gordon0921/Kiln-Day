extends RefCounted
## 垂直切片的端到端逻辑测试：捏塑 → 评分 → 烧窑 → 结算 → 存档字段。
## 不依赖场景与 UI，只测数据流是否闭合。


func run(report: TestReport) -> void:
	report.begin("slice")

	# 1) 直接复制目标像素当成品：应当满分通过。
	var session := SculptSession.new(&"band-pot", 1)
	session.pixels = session.target.duplicate()
	var perfect := session.score()
	report.eq(perfect["score"], 100.0, "复制目标像素得 100 分")
	report.ok(perfect["passed"], "100 分判定为通过")

	# 2) 空白泥团：不该通过，且分数与 golden 一致。
	var blank := SculptSession.new(&"band-pot", 1)
	var blank_score := blank.score()
	report.ok(not blank_score["passed"], "空白泥团不通过")
	report.eq(snappedf(blank_score["score"], 0.1), 34.1, "空白泥团 34.1 分")

	# 3) 笔画 + 撤销 / 重做：推一次泥，撤销回到原点，重做再回来。
	var edit := SculptSession.new(&"band-pot", 1)
	var before := edit.pixels.duplicate()
	edit.stroke_begin(Vector2(111, 56), "push")
	edit.stroke_move(Vector2(96, 56))
	edit.stroke_end()
	report.ok(edit.pixels != before, "推泥改变了像素")
	report.ok(edit.can_undo(), "改动后可以撤销")
	edit.undo()
	report.ok(edit.pixels == before, "撤销回到初始像素")
	report.ok(edit.can_redo(), "撤销后可以重做")
	edit.redo()
	report.ok(edit.pixels != before, "重做恢复推泥结果")

	# 4) 工具切换：雕刻能切掉像素，上色只改颜色不改轮廓。
	var carved := SculptSession.new(&"band-pot", 1)
	var outline_before := _opaque_count(carved.pixels)
	carved.stroke_begin(Vector2(56, 40), "cut")
	carved.stroke_move(Vector2(56, 70))
	carved.stroke_end()
	report.ok(_opaque_count(carved.pixels) < outline_before, "雕刻减少了不透明像素")

	var painted := SculptSession.new(&"band-pot", 1)
	var paint_before := _opaque_count(painted.pixels)
	painted.stroke_begin(Vector2(56, 56), "paint")
	painted.stroke_move(Vector2(60, 60))
	painted.stroke_end()
	report.eq(_opaque_count(painted.pixels), paint_before, "上色不改变轮廓")

	# 5) 存档往返：像素与参数要能完整序列化。
	var round_trip := SculptSession.new(&"dot-jar", 2)
	round_trip.pixels = round_trip.target.duplicate()
	var restored := SculptSession.from_dict(round_trip.to_dict())
	report.eq(restored.design_id, round_trip.design_id, "存档往返保住器型")
	report.eq(restored.level, round_trip.level, "存档往返保住等级")
	report.ok(restored.pixels == round_trip.pixels, "存档往返保住像素")

	# 6) 烧窑：跟着靶心鼓风，绿带时间要占大头。
	var kiln := KilnRun.new(1, 1)
	var guard := 0
	while not kiln.finished() and guard < 20000:
		kiln.stoking = kiln.heat < kiln.band_center()
		kiln.tick(1.0 / 60.0)
		guard += 1
	report.ok(kiln.finished(), "烧窑 12 秒后结束")
	report.eq(snappedf(kiln.seconds["perfect"] + kiln.seconds["good"] + kiln.seconds["fair"], 0.01),
		snappedf(kiln.duration, 0.01), "三段计时之和等于时长")
	report.ok(kiln.grade() != "fair", "跟住靶心不会烧成普通品")

	# 7) 结算：完美 + 准时 + 首通，收入要高于只按基础价。
	var income := Workshop.order_income(60, {
		"kiln": 1, "serve": 1, "passed": true, "elapsedMs": 90000,
		"eligible": true, "firstPass": true,
	})
	report.ok(income["earned"] > 60, "完美交付收入高于基础价 60")
	report.eq(income["firstPassBonus"], KilnConstants.FIRST_PASS_BONUS, "首通奖励 60")

	# 8) 存档分区：默认数据必须带上图鉴 / 成就 / 剧情切片。
	var schema := SaveGame.default_data()
	for key in ["progress", "inventory", "codex", "achievements", "story", "meta"]:
		report.ok(schema.has(key), "存档分区存在：" + key)
	report.eq(int(schema["version"]), SaveGame.SAVE_VERSION, "存档版本号一致")

	report.finish()


func _opaque_count(pixels: PackedByteArray) -> int:
	var total := 0
	for value in pixels:
		if value != 0:
			total += 1
	return total
