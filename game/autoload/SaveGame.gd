extends Node
## 存档：user://save_v1.json
##
## 关键约定（后续加模块时别再改结构，只加字段）：
##   progress     站点/订单/铜钱/已过关卡
##   inventory    升级等级、库存
##   codex        图鉴已发现条目       ← 图鉴模块
##   achievements 已解锁成就            ← 成就模块
##   story        已看过的剧情节拍       ← 剧情模块
##   meta         版本、创建时间、引擎
##
## 旧 three.js 版的 localStorage 键是 "terra-porcelain-journey-v6"，
## 只在 Web 导出且玩家主动导入时才读取（S2 实现）。

const SAVE_PATH := "user://save_v1.json"
const SAVE_VERSION := 1
const LEGACY_WEB_KEY := "terra-porcelain-journey-v6"

var data: Dictionary = {}
var last_error: String = ""

func _ready() -> void:
	if not load_game():
		data = default_data()
		save_game()

func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"progress": {
			"site_index": 0,
			"order_index": 0,
			"coins": 120,
			"passed": [],
		},
		"inventory": {
			"upgrades": {},
			"stock": {},
		},
		"codex": {
			"discovered": [],
		},
		"achievements": {
			"unlocked": [],
		},
		"story": {
			"seen_beats": [],
		},
		"meta": {
			"engine": "godot",
			"created_at": Time.get_datetime_string_from_system(true),
		},
	}

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		last_error = "无法打开存档：%s" % error_string(FileAccess.get_open_error())
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "存档不是合法 JSON 对象"
		return false
	data = migrate(parsed, text)
	Events.save_loaded.emit(int(data.get("version", SAVE_VERSION)))
	return true

func save_game() -> bool:
	data["version"] = SAVE_VERSION
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		last_error = "无法写入存档：%s" % error_string(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

## 逐版本迁移。新增版本时在下面加一条即可，老存档会自动补齐缺省字段。
func migrate(old: Dictionary, _raw: String = "") -> Dictionary:
	var out := default_data()
	var old_version := int(old.get("version", 0))
	for key in ["progress", "inventory", "codex", "achievements", "story", "meta"]:
		if typeof(old.get(key)) == TYPE_DICTIONARY:
			out[key].merge(old[key], true)
	# 未来：if old_version < 2: ...

	# 兜底：任何缺失的键都用默认值填上
	for key in default_data().keys():
		if not out.has(key):
			out[key] = default_data()[key]
	out["version"] = SAVE_VERSION
	return out

func reset() -> void:
	data = default_data()
	save_game()
	Events.reset_session()

## 试玩版 → 完整版的进度迁移码（JSON + 简易校验和，base64）。
func export_transfer_code() -> String:
	var payload := data.duplicate(true)
	payload.erase("meta")
	var body := JSON.stringify(payload)
	var checksum := _checksum(body)
	return Marshalls.raw_to_base64(("%s|%d" % [body, checksum]).to_utf8_buffer())

func import_transfer_code(code: String) -> bool:
	var raw := Marshalls.base64_to_raw(code)
	var text := raw.get_string_from_utf8()
	var sep := text.rfind("|")
	if sep <= 0:
		last_error = "迁移码格式不对"
		return false
	var body := text.substr(0, sep)
	var checksum := text.substr(sep + 1)
	if int(checksum) != _checksum(body):
		last_error = "迁移码校验失败"
		return false
	var parsed: Variant = JSON.parse_string(body)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "迁移码内容损坏"
		return false
	data = migrate(parsed)
	save_game()
	return true

func _checksum(s: String) -> int:
	var h := 5381
	for i in s.length():
		h = (h * 33 + s.unicode_at(i)) & 0x7FFFFFFF
	return h
