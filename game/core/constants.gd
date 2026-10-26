class_name KilnConstants
extends RefCounted
## 全局数值常量。
##
## 来源：旧版 src/workshop.js 与 src/sculpture.js 的导出常量。
## S2 移植时会用 golden 用例逐值核对；在此之前不要随手改数字。

# --- 像素画布 ---
const SIZE := 112                 # 画布边长（像素）
const PASS_SCORE := 80            # 订单过关线
const REWARD_MIN_SCORE := 60      # 达到才给钱
const REWARD_MAX := 100           # 单笔奖励上限
const DECAL_PRICE := 400          # 贴画售价
const ORDERS_PER_SCENE := 3       # 每站订单数

# --- 工作台 / 经营 ---
const FIRST_PASS_BONUS := 60
const EFFICIENCY_LIMIT_MS := 300000
const UPGRADE_COSTS := {1: 100, 2: 200}
const WORKBENCH_IDS := ["clay", "wheel", "carve", "paint", "kiln", "serve"]

# --- 烧窑（12 秒连续加温） ---
const KILN_SECONDS := 12.0
const FIRE_HEAT_RATE := 0.85
const FIRE_COOL_RATE := 0.5
const FIRE_START_HEAT := 0.42
const FIRE_BAND_GOOD := 0.12
const FIRE_BAND_PERFECT := 0.045
const FIRE_RATIO_PERFECT := 0.72
const FIRE_RATIO_GOOD := 0.38

# --- 调色板：索引 0 = 空白，1 = 瓷白，2 = 钴蓝 ---
const PALETTE := [null, "#f2efe5", "#315fa9"]
const COLOR_NAMES := ["", "瓷白", "钴蓝"]

# --- 站点顺序（与 data/catalog.json 一致） ---
const SITE_IDS := ["guyao", "museum", "imperial", "taoxichuan"]

const LEGACY_SAVE_KEY := "terra-porcelain-journey-v6"

## 与 campaign.js 的 rewardForScore 等价。
static func reward_for_score(score: float) -> int:
	if not is_finite(score) or score < REWARD_MIN_SCORE:
		return 0
	return mini(REWARD_MAX, int(floor(score / 10.0)) * 10)
