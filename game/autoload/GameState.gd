extends Node
## 运行时游戏状态：铜钱、站点进度、升级、图鉴。数据真源在 SaveGame.data，
## 这里只是带信号的读写门面，避免 UI 到处直接摸存档字典。

signal coins_changed(coins: int)
signal site_changed(site_id: StringName)

var site_ids: PackedStringArray = ContentPack.available_site_ids()

var coins: int:
	get:
		return int(SaveGame.data.get("progress", {}).get("coins", 0))
	set(value):
		var p: Dictionary = SaveGame.data.get("progress", {})
		p["coins"] = maxi(value, 0)
		SaveGame.data["progress"] = p
		coins_changed.emit(p["coins"])
		Events.coins_changed.emit(p["coins"])

var site_index: int:
	get:
		return int(SaveGame.data.get("progress", {}).get("site_index", 0))
	set(value):
		var p: Dictionary = SaveGame.data.get("progress", {})
		p["site_index"] = clampi(value, 0, maxi(site_ids.size() - 1, 0))
		SaveGame.data["progress"] = p
		site_changed.emit(current_site_id())
		Events.site_changed.emit(current_site_id())

var order_index: int:
	get:
		return int(SaveGame.data.get("progress", {}).get("order_index", 0))
	set(value):
		var p: Dictionary = SaveGame.data.get("progress", {})
		p["order_index"] = maxi(value, 0)
		SaveGame.data["progress"] = p

func current_site_id() -> StringName:
	if site_ids.is_empty():
		return &""
	return site_ids[clampi(site_index, 0, site_ids.size() - 1)]

func is_pass(score: float) -> bool:
	return score >= float(KilnConstants.PASS_SCORE)

func add_coins(amount: int) -> void:
	coins = coins + amount

func try_spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins = coins - amount
	return true

func discover(item_id: StringName) -> bool:
	var list: Array = SaveGame.data.get("codex", {}).get("discovered", [])
	if list.has(String(item_id)):
		return false
	list.append(String(item_id))
	SaveGame.data["codex"]["discovered"] = list
	SaveGame.save_game()
	Events.item_discovered.emit(item_id)
	return true

func unlock(achievement_id: StringName) -> bool:
	var list: Array = SaveGame.data.get("achievements", {}).get("unlocked", [])
	if list.has(String(achievement_id)):
		return false
	list.append(String(achievement_id))
	SaveGame.data["achievements"]["unlocked"] = list
	SaveGame.save_game()
	Events.achievement_unlocked.emit(achievement_id)
	return true

func upgrade_level(key: StringName) -> int:
	return int(SaveGame.data.get("inventory", {}).get("upgrades", {}).get(String(key), 0))
