class_name Workshop
extends RefCounted
## 经营与烧窑公式。逐函数对照 `legacy/web-demo/src/workshop.js`。
##
## 烧窑是"按住加温、松手降温，把热度压在一条会漂的火候带里"，在带里待的时间
## 决定品级。漂移用 mulberry32 播种，所以 goldens 可以逐值对拍。

const FIRE_DURATION := 12.0
const FIRE_HEAT_RATE := 0.85
const FIRE_COOL_RATE := 0.5
const FIRE_START_HEAT := 0.42
const FIRE_BAND_GOOD := 0.12
const FIRE_BAND_PERFECT := 0.045
const FIRE_RATIO_PERFECT := 0.72
const FIRE_RATIO_GOOD := 0.38
const EFFICIENCY_LIMIT_MS := KilnConstants.EFFICIENCY_LIMIT_MS
const FIRST_PASS_BONUS := KilnConstants.FIRST_PASS_BONUS

const TAU := PI * 2.0


## 窑的等级只放宽火候带，不改变漂移速度。
static func fire_band(level := 1) -> Dictionary:
	var bonus := clampi(int(floor(level)) - 1, 0, 2)
	return {
		"good": FIRE_BAND_GOOD + bonus * 0.012,
		"perfect": FIRE_BAND_PERFECT + bonus * 0.004,
	}


# --- mulberry32：必须是 32 位无符号语义，和 JS 的 >>> / Math.imul 一致 ---


static func _u32(value: int) -> int:
	return value & 0xFFFFFFFF


static func _ushr(value: int, bits: int) -> int:
	return _u32(value) >> bits


static func _imul(a: int, b: int) -> int:
	return _u32(_u32(a) * _u32(b))


## 返回一个可调用的随机序列。
class _Mulberry32:
	var a: int

	func _init(seed_value: int) -> void:
		a = seed_value

	func next() -> float:
		a = Workshop._u32(a + 0x6D2B79F5)
		var t := Workshop._imul(a ^ Workshop._ushr(a, 15), 1 | a)
		var summed := Workshop._u32(t + Workshop._imul(t ^ Workshop._ushr(t, 7), 61 | t))
		t = summed ^ t
		return float(Workshop._ushr(t ^ Workshop._ushr(t, 14), 0)) / 4294967296.0


## 每窑一条缓慢分层漂移 + 1~2 次短阵风。
## 返回 Callable(t) -> 火候带中心（0.48…0.72）。
static func create_fire_drift(seed_value := 1) -> Callable:
	var rng := _Mulberry32.new(_u32(seed_value))
	var base := 0.6 + (rng.next() - 0.5) * 0.024
	var waves := []
	var amp_scale := [0.012, 0.008, 0.004]
	var amp_base := [0.03, 0.016, 0.008]
	var freq_base := [0.08, 0.18, 0.32]
	var freq_scale := [0.06, 0.08, 0.1]
	for i in 3:
		var amp: float = amp_base[i] + rng.next() * amp_scale[i]
		# 注意：JS 里 [.08+rnd()*.06, .18+rnd()*.08, .32+rnd()*.1][i] 会先算完三个元素，
		# 所以无论 i 是多少都会消耗三个随机数。
		var freq_a: float = freq_base[0] + rng.next() * freq_scale[0]
		var freq_b: float = freq_base[1] + rng.next() * freq_scale[1]
		var freq_c: float = freq_base[2] + rng.next() * freq_scale[2]
		var freq: float = [freq_a, freq_b, freq_c][i]
		var phase := rng.next() * TAU
		waves.append({"amp": amp, "freq": freq, "phase": phase})

	var gusts := []
	var gust_count := 1 + (1 if rng.next() < 0.45 else 0)
	for i in gust_count:
		var at := 2.2 + rng.next() * 7.4
		var direction := -1.0 if rng.next() < 0.5 else 1.0
		var amp := direction * (0.015 + rng.next() * 0.015)
		var width := 0.8 + rng.next() * 0.7
		gusts.append({"at": at, "amp": amp, "width": width})

	return func(t: float) -> float:
		var value := base
		for wave in waves:
			value += float(wave["amp"]) * sin(TAU * float(wave["freq"]) * t + float(wave["phase"]))
		for gust in gusts:
			var x := (t - float(gust["at"])) / float(gust["width"])
			if absf(x) < 1.0:
				value += float(gust["amp"]) * (1.0 + cos(x * PI)) / 2.0
		var settle := minf(1.0, maxf(0.0, t / 1.2))
		var target := 0.6 + (value - 0.6) * settle
		return minf(0.72, maxf(0.48, target))


static func fire_ratio(seconds: Dictionary) -> float:
	var perfect := float(seconds.get("perfect", 0.0))
	var good := float(seconds.get("good", 0.0))
	var fair := float(seconds.get("fair", 0.0))
	var total := maxf(1e-9, perfect + good + fair)
	return (perfect + good * 0.5) / total


static func fire_grade(seconds: Dictionary) -> String:
	var ratio := fire_ratio(seconds)
	if ratio >= FIRE_RATIO_PERFECT:
		return "perfect"
	if ratio >= FIRE_RATIO_GOOD:
		return "good"
	return "plain"


## 一单的结算明细。base 是器物基础价，passed 决定效率奖。
static func order_income(base: float, options := {}) -> Dictionary:
	var kiln := int(options.get("kiln", 1))
	var serve := int(options.get("serve", 1))
	var passed := bool(options.get("passed", false))
	var elapsed_ms := float(options.get("elapsedMs", 0.0))
	var eligible := bool(options.get("eligible", false))
	var first_pass := bool(options.get("firstPass", false))
	var kiln_earned := roundi(base * kiln)
	var regular_earned := roundi(base * kiln * serve)
	var efficient := passed and eligible and elapsed_ms <= float(EFFICIENCY_LIMIT_MS)
	var efficiency_bonus := roundi(regular_earned * 0.2) if efficient else 0
	var first_pass_bonus := FIRST_PASS_BONUS if first_pass else 0
	return {
		"regularEarned": regular_earned,
		"kilnBonus": kiln_earned - int(base),
		"serveBonus": regular_earned - kiln_earned,
		"efficiencyBonus": efficiency_bonus,
		"firstPassBonus": first_pass_bonus,
		"earned": regular_earned + efficiency_bonus + first_pass_bonus,
		"efficiency": {
			"elapsedMs": elapsed_ms,
			"limitMs": EFFICIENCY_LIMIT_MS,
			"eligible": eligible,
			"qualified": efficient,
		},
	}


## mm:ss
static func format_elapsed(ms: float) -> String:
	return "%02d:%02d" % [int(floor(ms / 60000.0)), int(floor(ms / 1000.0)) % 60]


## 计时器该不该走。逐条对应旧版的暂停条件。
static func clock_policy(flags := {}) -> Dictionary:
	var started := bool(flags.get("started", false))
	var help_open := bool(flags.get("helpOpen", false))
	var hidden := bool(flags.get("hidden", false))
	var focused := bool(flags.get("focused", true))
	var has_clay := bool(flags.get("hasClay", false))
	var can_work := bool(flags.get("canWork", false))
	var kind := String(flags.get("kind", ""))
	var available := started and not help_open and not hidden and focused
	var paused_kinds := ["citymap", "travel", "upgrades"]
	return {
		"efficiency": available and has_clay and can_work and not paused_kinds.has(kind),
		"kiln": available and kind == "kiln",
	}
