class_name SculptSession
extends RefCounted
## 一件作品的一次编辑过程：像素、撤销栈、计时、评分。
##
## 不碰节点，纯逻辑，方便无头测试。渲染与输入在 SculptCanvas 里。

const MAX_UNDO := 30
const DEFAULT_RADIUS := 18.0

var design_id: StringName = &"band-pot"
var level := 1
var tool := "push"
var color := 2
var radius := DEFAULT_RADIUS
var target := PackedByteArray()
var pixels := PackedByteArray()
var elapsed_ms := 0.0

var _undo: Array[PackedByteArray] = []
var _redo: Array[PackedByteArray] = []
var _before_stroke := PackedByteArray()
var _last_point := Vector2.ZERO
var _grab: Variant = null
var _stroking := false


func _init(p_design_id: StringName = &"band-pot", p_level := 1) -> void:
	design_id = p_design_id
	level = p_level
	reset()


## 每个工位用什么工具。与旧版 STATION_TOOLS 一致，clay 也走拉坯。
static func station_tool(station: String) -> String:
	match station:
		"carve":
			return "cut"
		"paint":
			return "paint"
		"add":
			return "add"
		_:
			return "push"


func reset() -> void:
	target = Sculpture.create_target(design_id)
	pixels = Sculpture.supplied_clay(target, level)
	_undo.clear()
	_redo.clear()
	elapsed_ms = 0.0
	_stroking = false
	_grab = null


func advance(delta_ms: float) -> void:
	elapsed_ms += delta_ms


func stroke_begin(point: Vector2, p_tool: String) -> void:
	if _stroking:
		stroke_end()
	tool = p_tool
	_before_stroke = pixels.duplicate()
	_last_point = point
	_stroking = true
	_grab = null
	if tool == "push":
		_grab = Sculpture.clay_edge(pixels, point.x, point.y, radius)


## 返回这一小段是否真的改动了像素；界面据此决定要不要重画。
func stroke_move(point: Vector2) -> bool:
	if not _stroking:
		return false
	var changed := false
	match tool:
		"push":
			changed = Sculpture.push_clay(
				pixels,
				_last_point.x,
				_last_point.y,
				point.x,
				point.y,
				radius,
				_grab,
				{"target": target, "level": level, "symmetric": true}
			)
			# 每段都重新抓边：玩家可以顺着泥边一路推。
			_grab = Sculpture.clay_edge(pixels, point.x, point.y, radius)
		_:
			changed = Sculpture.apply_brush(
				pixels, _last_point.x, _last_point.y, point.x, point.y, radius, tool, color
			)
	_last_point = point
	return changed


func stroke_end() -> void:
	if not _stroking:
		return
	_stroking = false
	_grab = null
	if pixels == _before_stroke:
		return
	_undo.append(_before_stroke)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(pixels)
	pixels = _undo.pop_back()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(pixels)
	pixels = _redo.pop_back()
	return true


func score() -> Dictionary:
	return Sculpture.compare(pixels, target)


func to_dict() -> Dictionary:
	return {
		"design": String(design_id),
		"level": level,
		"elapsedMs": elapsed_ms,
		"pixels": Marshalls.raw_to_base64(pixels),
	}


static func from_dict(data: Dictionary) -> SculptSession:
	var session := SculptSession.new(StringName(String(data.get("design", "band-pot"))), int(data.get("level", 1)))
	var raw := Marshalls.base64_to_raw(String(data.get("pixels", "")))
	if raw.size() == session.pixels.size():
		session.pixels = raw
	session.elapsed_ms = float(data.get("elapsedMs", 0.0))
	return session
