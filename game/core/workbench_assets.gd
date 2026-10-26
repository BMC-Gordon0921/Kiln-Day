class_name WorkbenchAssets
extends RefCounted
## 工作台 GLB 清单。由 art/export/build-workbenches.py 生成，六个工作台各带
## base / upgrade1 / upgrade2 三个层级，节点自定义属性 tier 记录所属层级。

const PATH := "res://assets/models/workbenches/manifest.json"
const DIR := "res://assets/models/workbenches/"
const TIER_KEYS := ["base", "upgrade1", "upgrade2"]


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		return parsed
	return {}


static func entries() -> Dictionary:
	return load_manifest().get("workbenches", {})


static func ids() -> PackedStringArray:
	var keys: Array = entries().keys()
	keys.sort()
	return PackedStringArray(keys)


static func scene_path(entry: Dictionary) -> String:
	return DIR + String(entry.get("file", ""))


static func tier_count(entry: Dictionary, tier: String) -> int:
	var tiers: Dictionary = entry.get("tiers", {})
	return int(tiers.get(tier, 0))


## 给定工作台等级（1..3），判断某个 tier 是否应该显示。
static func tier_visible(tier: String, level: int) -> bool:
	match tier:
		"base":
			return true
		"upgrade1":
			return level >= 2
		"upgrade2":
			return level >= 3
		_:
			return false
