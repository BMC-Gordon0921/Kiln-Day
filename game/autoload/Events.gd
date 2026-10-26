extends Node
## 全局事件总线。
##
## 设计意图：成就、图鉴、剧情、统计都只订阅事件，彼此不直接引用，
## 这样以后加模块时不必改已有系统。任何时候都不要在事件回调里做重活。

signal sculpture_finished(result: Dictionary)
signal kiln_opened(result: Dictionary)
signal item_sold(income: int, item_id: StringName)
signal item_discovered(item_id: StringName)
signal achievement_unlocked(id: StringName)
signal site_changed(site_id: StringName)
signal coins_changed(coins: int)
signal save_loaded(version: int)

## 一次性事件去重（同一会话内重复触发不重复广播）。
var _fired: Dictionary = {}

func fire_once(key: StringName) -> bool:
	if _fired.has(key):
		return false
	_fired[key] = true
	return true

func reset_session() -> void:
	_fired.clear()
