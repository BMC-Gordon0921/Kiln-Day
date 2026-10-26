class_name ContentPack
extends RefCounted
## 双发行内容门控：一份工程，两个导出预设。
##
##   desktop_full : 无额外 feature tag             → 全部站点与图鉴
##   web_demo     : 导出预设 custom_features="demo" → 只放 1 站、图鉴前 4 格
##
## 判定只走 OS.has_feature("demo")，不要在业务代码里散落平台判断。

const DEMO_SITE_IDS: Array[String] = ["guyao"]
const DEMO_MAX_CODEX := 4

static func is_demo() -> bool:
	return OS.has_feature("demo")

static func available_site_ids() -> PackedStringArray:
	if is_demo():
		return PackedStringArray(DEMO_SITE_IDS)
	return PackedStringArray(KilnConstants.SITE_IDS)

static func is_site_available(site_id: StringName) -> bool:
	return available_site_ids().has(String(site_id))

static func limits() -> Dictionary:
	if is_demo():
		return {
			"sites": DEMO_SITE_IDS.size(),
			"orders_per_site": KilnConstants.ORDERS_PER_SCENE,
			"codex_max": DEMO_MAX_CODEX,
			"allow_transfer_code": true,
			"allow_save": true,
		}
	return {
		"sites": KilnConstants.SITE_IDS.size(),
		"orders_per_site": KilnConstants.ORDERS_PER_SCENE,
		"codex_max": -1,
		"allow_transfer_code": true,
		"allow_save": true,
	}
