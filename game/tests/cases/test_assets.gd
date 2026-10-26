extends RefCounted
## 资产验收：站点场景 + 六个工作台 GLB 必须真的能实例化。
## 这是"美术管线接通"的证据，也是减面后防止资产悄悄坏掉的护栏。


func run(t: TestReport) -> void:
	_check_sites(t)
	_check_workbenches(t)
	_check_tier_visibility(t)


func _check_sites(t: TestReport) -> void:
	var entries := AssetManifest.load_manifest()
	t.eq(entries.size(), 4, "站点清单 4 条")
	var total := 0
	for id in AssetManifest.ids(entries):
		var entry: Dictionary = entries[id]
		var path := AssetManifest.scene_path(entry)
		var packed := load(path) as PackedScene
		t.ok(packed != null, "站点 GLB 可加载：" + String(id))
		if packed == null:
			continue
		var node := packed.instantiate()
		t.ok(node != null and node.get_child_count() > 0, "站点实例化有子节点：" + String(id))
		if node != null:
			node.free()
		var tris := int(entry.get("triangles", 0))
		t.ok(tris > 0 and tris < 60000, "%s 三角面在预算内（%d）" % [id, tris])
		total += tris
	t.ok(total < 140000, "四站三角面合计 %d < 140000" % total)


func _check_workbenches(t: TestReport) -> void:
	var entries := WorkbenchAssets.entries()
	t.eq(entries.size(), 6, "工作台清单 6 条")
	t.ok(
		WorkbenchAssets.ids() == PackedStringArray(
			["carve", "clay", "kiln", "paint", "serve", "wheel"]
		),
		"工作台 id 排序稳定且齐全"
	)

	for id in WorkbenchAssets.ids():
		var entry: Dictionary = entries[id]
		var path := WorkbenchAssets.scene_path(entry)
		var packed := load(path) as PackedScene
		t.ok(packed != null, "工作台 GLB 可加载：" + String(id))
		if packed == null:
			continue
		var node := packed.instantiate()
		var meshes := 0
		if node != null:
			meshes = _count_meshes(node)
			node.free()
		t.ok(meshes > 0, "%s 实例化后有 %d 个网格" % [id, meshes])
		t.ok(int(entry.get("triangles", 0)) > 0, "%s 三角面统计为正" % id)
		for tier in WorkbenchAssets.TIER_KEYS:
			t.ok(
				WorkbenchAssets.tier_count(entry, tier) > 0,
				"%s 含 %s 层级" % [id, tier]
			)


func _check_tier_visibility(t: TestReport) -> void:
	t.ok(WorkbenchAssets.tier_visible("base", 1), "1 级可见底座")
	t.ok(not WorkbenchAssets.tier_visible("upgrade1", 1), "1 级不显示升级件 1")
	t.ok(WorkbenchAssets.tier_visible("upgrade1", 2), "2 级显示升级件 1")
	t.ok(WorkbenchAssets.tier_visible("upgrade2", 3), "3 级显示升级件 2")


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count
