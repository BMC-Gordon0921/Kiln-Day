extends Node
## 玩家偏好。与存档分离：settings.cfg 是设备级配置，save_v1.json 是进度。

const CONFIG_PATH := "user://settings.cfg"

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var locale: String = "zh"
var reduced_motion: bool = false
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	locale = String(cfg.get_value("ui", "locale", locale))
	reduced_motion = bool(cfg.get_value("ui", "reduced_motion", reduced_motion))
	fullscreen = bool(cfg.get_value("ui", "fullscreen", fullscreen))

func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("ui", "locale", locale)
	cfg.set_value("ui", "reduced_motion", reduced_motion)
	cfg.set_value("ui", "fullscreen", fullscreen)
	return cfg.save(CONFIG_PATH) == OK

func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	TranslationServer.set_locale(locale)

func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
