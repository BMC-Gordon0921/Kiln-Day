extends Node3D
## 资产实验室：S0 的验收场，也是后续换模型/调光的第一现场。
##
## 同时验证两条管线：
##   3D  → assets/models/maps/*.glb 能否在 Godot 里正常实例化并按 bounds 落地；
##   2D  → 112×112 像素画布在最近邻放大后是否依然是硬边（不模糊）。
##
## 运行：编辑器里 F6 或 scripts\run.ps1；数字键 1-4 切换站点（完整版）。

@export var site_id: StringName = &"guyao"
@export var spin_speed := 0.12

var _model: Node3D
var _sites: PackedStringArray = []
var _label: Label

func _ready() -> void:
	_build_environment()
	_build_model()
	_build_pixel_preview()
	_build_hud()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe0ea")
	env.ambient_light_energy = 0.9
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.position = Vector3(16.0, 8.5, 16.0)
	add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 2.0, 0.0), Vector3.UP)

func _build_model() -> void:
	_sites = ContentPack.available_site_ids()
	if _sites.is_empty():
		push_error("[AssetLab] 内容包里没有可用站点")
		return
	_show_site(_sites[0])

func _show_site(id: StringName) -> void:
	var manifest := AssetManifest.load_manifest()
	var entry: Dictionary = manifest.get(String(id), {})
	if entry.is_empty():
		push_error("[AssetLab] 清单里没有站点 %s" % id)
		return

	var path := AssetManifest.scene_path(entry)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[AssetLab] 无法加载 %s（先跑 scripts\\godot-import.ps1）" % path)
		return

	if _model != null:
		_model.queue_free()
	_model = packed.instantiate()
	add_child(_model)

	# 把模型按清单里的 bounds 居中、按 groundY 落地。
	var bounds: Dictionary = entry.get("bounds", {})
	var lo: Array = bounds.get("min", [0.0, 0.0, 0.0])
	var hi: Array = bounds.get("max", [0.0, 0.0, 0.0])
	var center := Vector3(
		(float(lo[0]) + float(hi[0])) * 0.5,
		float(entry.get("groundY", 0.0)),
		(float(lo[2]) + float(hi[2])) * 0.5,
	)
	_model.position = -center

	if _label != null:
		_label.text = "%s · %s · batches=%d" % [id, path.get_file(), int(entry.get("batches", 0))]
	print("[AssetLab] ASSETLAB_OK 已加载 %s" % path)

func _build_pixel_preview() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var size := KilnConstants.SIZE
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color("f2efe5"))
	# 1px 外框 + 一条对角：专门用来看最近邻放大后是否出现模糊/半像素。
	for i in size:
		image.set_pixel(i, 0, Color("e2703a"))
		image.set_pixel(i, size - 1, Color("e2703a"))
		image.set_pixel(0, i, Color("e2703a"))
		image.set_pixel(size - 1, i, Color("e2703a"))
		image.set_pixel(i, i, Color("315fa9"))

	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(size * 4, size * 4)
	rect.size = rect.custom_minimum_size
	rect.position = Vector2(32.0, 32.0)
	layer.add_child(rect)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.position = Vector2(32.0, 32.0 + KilnConstants.SIZE * 4 + 12.0)
	_label.text = "加载中…"
	layer.add_child(_label)

	var hint := Label.new()
	hint.position = Vector2(32.0, 32.0 + KilnConstants.SIZE * 4 + 40.0)
	hint.text = "1-4 切换站点 · %s · %s" % [
		"试玩版" if ContentPack.is_demo() else "完整版",
		OS.get_name(),
	]
	hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	layer.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := int(event.keycode) - int(KEY_1)
	if index >= 0 and index < _sites.size():
		_show_site(_sites[index])

func _process(delta: float) -> void:
	if _model != null:
		_model.rotate_y(delta * spin_speed)
