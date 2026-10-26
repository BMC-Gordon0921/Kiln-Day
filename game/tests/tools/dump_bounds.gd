extends SceneTree

## Debug helper: print the largest mesh AABBs of an imported GLB (res:// path in args).

var rows := []


func _initialize() -> void:
	var path := "res://assets/models/maps/guyao.glb"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		path = args[0]
	var packed := load(path)
	if packed == null:
		print("LOAD_FAIL " + path)
		quit(1)
		return
	var root: Node = packed.instantiate()
	_walk(root, Transform3D.IDENTITY, "")
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(14, rows.size()):
		print("%10.3f  %s" % [rows[i][0], rows[i][1]])
	var total := AABB()
	var first := true
	for row in rows:
		var box: AABB = row[2]
		if first:
			total = box
			first = false
		else:
			total = total.merge(box)
	print("TOTAL (%.3f, %.3f, %.3f)-(%.3f, %.3f, %.3f) meshes=%d" % [
		total.position.x, total.position.y, total.position.z,
		total.end.x, total.end.y, total.end.z, rows.size()])
	root.free()
	quit(0)


func _walk(node: Node, parent_xform: Transform3D, path: String) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var here := path + "/" + node.name
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var box: AABB = xform * mi.get_aabb()
			var volume: float = box.size.x * box.size.y * box.size.z
			rows.append([volume, here, box])
	for child in node.get_children():
		_walk(child, xform, here)
