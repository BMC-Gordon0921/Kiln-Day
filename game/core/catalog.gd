class_name Catalog
extends RefCounted
## data/catalog.json 的读取与校验。
##
## 为什么用 JSON 而不是 .tres：
##   1) 策划/美术用文本编辑器就能改，审阅 diff 友好；
##   2) 现在还没进 S2，器型的目标像素由代码生成，先不急着引入 Resource 序列化；
##   3) 若后续需要编辑器内拖拽编辑，再加一层 .tres → JSON 的转换即可。

const PATH := "res://data/catalog.json"

static func load_catalog(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func site(catalog: Dictionary, site_id: StringName) -> Dictionary:
	for s in catalog.get("sites", []):
		if String(s.get("id", "")) == String(site_id):
			return s
	return {}

static func item(catalog: Dictionary, item_id: StringName) -> Dictionary:
	for it in catalog.get("items", []):
		if String(it.get("id", "")) == String(item_id):
			return it
	return {}

static func items_for_site(catalog: Dictionary) -> Array:
	var out: Array = []
	var all_items: Array = catalog.get("items", [])
	for i in range(mini(KilnConstants.ORDERS_PER_SCENE, all_items.size())):
		out.append(all_items[i])
	return out

## 返回错误列表；空列表 = 通过。
static func validate(catalog: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if catalog.is_empty():
		return ["无法加载 " + PATH]

	var sites: Array = catalog.get("sites", [])
	if sites.size() != KilnConstants.SITE_IDS.size():
		errs.append("sites 数量 %d != %d" % [sites.size(), KilnConstants.SITE_IDS.size()])
	for i in sites.size():
		var s: Dictionary = sites[i]
		for field in ["id", "name", "chapter", "color"]:
			if not s.has(field):
				errs.append("sites[%d] 缺少字段 %s" % [i, field])
		if String(s.get("id", "")) != String(KilnConstants.SITE_IDS[i]):
			errs.append("sites[%d].id 顺序与 KilnConstants.SITE_IDS 不一致" % i)

	var items: Array = catalog.get("items", [])
	if items.size() < KilnConstants.ORDERS_PER_SCENE:
		errs.append("items 至少需要 %d 条" % KilnConstants.ORDERS_PER_SCENE)
	for i in items.size():
		var it: Dictionary = items[i]
		for field in ["id", "name", "task", "hint"]:
			if not it.has(field):
				errs.append("items[%d] 缺少字段 %s" % [i, field])

	for i in catalog.get("achievements", []).size():
		var a: Dictionary = catalog["achievements"][i]
		for field in ["id", "name", "desc", "stat", "count"]:
			if not a.has(field):
				errs.append("achievements[%d] 缺少字段 %s" % [i, field])
	return errs
