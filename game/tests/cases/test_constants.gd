extends RefCounted
## 常量与纯函数：这些数字一旦漂移，手感和经济就变了，所以逐条钉死。

func run(t: TestReport) -> void:
	t.eq(KilnConstants.SIZE, 112, "画布 112×112")
	t.eq(KilnConstants.PASS_SCORE, 80, "过关线 80")
	t.eq(KilnConstants.KILN_SECONDS, 12.0, "烧窑 12 秒")
	t.eq(KilnConstants.ORDERS_PER_SCENE, 3, "每站 3 单")
	t.eq(KilnConstants.DECAL_PRICE, 400, "贴画 400")
	t.eq(KilnConstants.WORKBENCH_IDS.size(), 6, "六个工位")
	t.eq(KilnConstants.SITE_IDS.size(), 4, "四个站点")
	t.eq(KilnConstants.PALETTE.size(), 3, "调色板 3 档（含空白）")
	t.eq(KilnConstants.UPGRADE_COSTS.size(), 2, "两级升级价")

	# rewardForScore：与旧版 campaign.js 等价（<60 归零，否则按 10 取整、封顶 100）
	t.eq(KilnConstants.reward_for_score(0.0), 0, "0 分 → 0")
	t.eq(KilnConstants.reward_for_score(59.9), 0, "59.9 分 → 0")
	t.eq(KilnConstants.reward_for_score(60.0), 60, "60 分 → 60")
	t.eq(KilnConstants.reward_for_score(84.0), 80, "84 分 → 80")
	t.eq(KilnConstants.reward_for_score(99.9), 90, "99.9 分 → 90")
	t.eq(KilnConstants.reward_for_score(100.0), 100, "100 分 → 100")
	t.eq(KilnConstants.reward_for_score(NAN), 0, "NaN → 0")
