extends RefCounted
## glTF 清单：这是"美术管线真的接通了"的唯一证据，所以校验得细一点。

func run(t: TestReport) -> void:
	var result := AssetManifest.validate()
	var errors: Array = result["errors"]
	t.ok(errors.is_empty(), "清单校验无错误", str(errors))

	var entries: Dictionary = result["entries"]
	t.eq(entries.size(), 4, "清单含 4 个场景")
	t.ok(
		AssetManifest.ids(AssetManifest.load_manifest()) == PackedStringArray(
			["guyao", "imperial", "museum", "taoxichuan"]
		),
		"id 排序稳定且齐全"
	)

	var guyao: Dictionary = entries.get("guyao", {})
	t.eq(
		AssetManifest.scene_path(guyao),
		"res://assets/models/maps/guyao.glb",
		"场景路径拼接"
	)
	t.eq(guyao.get("groundY", 0.0), 0.09, "groundY = 0.09")
	t.ok(AssetManifest.vertical_span(guyao) > 6.0, "古窑竖向跨度 > 6m（含烟囱）")

	var museum: Dictionary = entries.get("museum", {})
	t.ok(museum.get("chimney", "missing") == null, "博物馆没有烟囱锚点")
	t.ok(int(museum.get("batches", 0)) > 0, "博物馆 batches 为正")
