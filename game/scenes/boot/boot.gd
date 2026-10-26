extends Node
## 启动自检。
##
## 职责只有三件：
##   1) 读 data/catalog.json 并校验（站点/器物/成就字段齐全、顺序正确）；
##   2) 读 assets/models/maps/manifest.json 并校验（4 个 glTF 都在、bounds 合法）；
##   3) 打印一行版本摘要，然后进资产实验室。
##
## 故意不在这里加载大资源：以后加"下载进度""版本公告"时，Boot 是唯一的插入点。

func _ready() -> void:
	var problems: Array[String] = []
	problems.append_array(Catalog.validate(Catalog.load_catalog()))

	var manifest := AssetManifest.validate()
	problems.append_array(manifest["errors"])

	print("[Boot] 开窑啦！Kiln Day · Godot %s" % Engine.get_version_info().get("string", "?"))
	print("[Boot] 内容包=%s 站点=%d 清单条目=%d" % [
		"demo" if ContentPack.is_demo() else "full",
		ContentPack.available_site_ids().size(),
		(manifest["entries"] as Dictionary).size(),
	])

	if problems.is_empty():
		# ASCII 标记供无头冒烟脚本 grep（脚本本身是 ASCII-only，无法匹配中文）。
		print("[Boot] BOOT_OK 自检通过，进入资产实验室")
		# 必须在 _ready 里延后一帧切场景，否则父节点正忙于装载子节点。
		get_tree().change_scene_to_file.call_deferred("res://scenes/lab/AssetLab.tscn")
		return

	for p in problems:
		push_error("[Boot] " + p)
	print("[Boot] BOOT_FAIL 自检失败 %d 项，停在 Boot（详见上方错误）" % problems.size())
