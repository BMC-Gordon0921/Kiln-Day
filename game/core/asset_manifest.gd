class_name AssetManifest
extends RefCounted
## 读取并校验 4 个旅游场景的 glTF 清单（来自旧版 public/models/maps/manifest.json）。
##
## 清单字段：url / bounds{min,max} / groundY / chimney / batches
## 用途：Boot 自检、AssetLab 摆放、S1 性能基线。

const MANIFEST_PATH := "res://assets/models/maps/manifest.json"
const ASSET_ROOT := "res://assets/"

static func load_manifest(path: String = MANIFEST_PATH) -> Dictionary:
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

static func ids(manifest: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var keys := manifest.keys()
	keys.sort()
	for k in keys:
		out.append(String(k))
	return out

static func scene_path(entry: Dictionary) -> String:
	return ASSET_ROOT + String(entry.get("url", ""))

## 返回 {ok:bool, errors:Array[String], entries:Dictionary}
static func validate(path: String = MANIFEST_PATH) -> Dictionary:
	var errors: Array[String] = []
	var manifest := load_manifest(path)
	if manifest.is_empty():
		return {"ok": false, "errors": ["找不到或无法解析清单：%s" % path], "entries": {}}

	var entries := {}
	for id in ids(manifest):
		var entry: Dictionary = manifest[id]
		errors.append_array(_validate_entry(id, entry))
		entries[id] = entry

	if manifest.size() != KilnConstants.SITE_IDS.size():
		errors.append("清单条目数 %d 与站点数 %d 不一致" % [manifest.size(), KilnConstants.SITE_IDS.size()])

	return {"ok": errors.is_empty(), "errors": errors, "entries": entries}

static func _validate_entry(id: String, entry: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var url := String(entry.get("url", ""))
	if url.is_empty():
		errs.append("%s: 缺少 url" % id)
	elif not FileAccess.file_exists(ASSET_ROOT + url):
		errs.append("%s: 文件不存在 %s" % [id, ASSET_ROOT + url])

	for corner in ["min", "max"]:
		var bounds: Variant = entry.get("bounds", {})
		if typeof(bounds) != TYPE_DICTIONARY:
			errs.append("%s: 缺少 bounds" % id)
			break
		var vec: Variant = bounds.get(corner)
		if typeof(vec) != TYPE_ARRAY or (vec as Array).size() != 3:
			errs.append("%s: bounds.%s 不是 3 维数组" % [id, corner])

	if not (typeof(entry.get("groundY", null)) in [TYPE_FLOAT, TYPE_INT]):
		errs.append("%s: 缺少 groundY" % id)
	if int(entry.get("batches", 0)) <= 0:
		errs.append("%s: batches 应为正数" % id)
	return errs

## 粗略估算三角面数（用于 S1 性能基线前的一致性检查；精确值由 S1 实测替换）。
static func vertical_span(entry: Dictionary) -> float:
	var bounds: Dictionary = entry.get("bounds", {})
	var lo: Array = bounds.get("min", [0, 0, 0])
	var hi: Array = bounds.get("max", [0, 0, 0])
	return float(hi[1]) - float(lo[1])
