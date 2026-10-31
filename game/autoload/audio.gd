extends Node
## 背景音乐与音效。尽量少占内存：BGM 一条、音效复用 6 个播放器。

const BGM_PATH := "res://assets/audio/pottery-background.wav"
const SFX := {
	"click": "res://assets/audio/sfx_click.wav",
	"confirm": "res://assets/audio/sfx_confirm.wav",
	"coin": "res://assets/audio/sfx_coin.wav",
	"fire": "res://assets/audio/sfx_fire.wav",
}

var muted := false
var _bgm: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "Bgm"
	var track := load(BGM_PATH) as AudioStreamWAV
	if track != null:
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_end = track.data.size() / (2 * (2 if track.stereo else 1))
		_bgm.stream = track
	_bgm.volume_db = -16.0
	add_child(_bgm)
	_bgm.play()

	_fire = AudioStreamPlayer.new()
	_fire.name = "KilnFire"
	var fire := load(SFX["fire"]) as AudioStreamWAV
	if fire != null:
		fire.loop_mode = AudioStreamWAV.LOOP_FORWARD
		fire.loop_end = fire.data.size() / (2 * (2 if fire.stereo else 1))
		_fire.stream = fire
	_fire.volume_db = -12.0
	add_child(_fire)

	for i in 6:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		add_child(player)
		_players.append(player)


func play(name: String) -> void:
	if muted or not SFX.has(name):
		return
	var stream := load(SFX[name]) as AudioStream
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


func set_fire(active: bool) -> void:
	if _fire == null:
		return
	if active and not muted:
		if not _fire.playing:
			_fire.play()
	elif _fire.playing:
		_fire.stop()


func toggle_mute() -> bool:
	muted = not muted
	if _bgm != null:
		_bgm.stream_paused = muted
	if muted:
		set_fire(false)
	return muted
