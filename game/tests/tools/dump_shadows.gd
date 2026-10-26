extends SceneTree

## Print cast_shadow for the first meshes of one GLB (shadow debugging).

func _initialize() -> void:
	var path := "res://assets/models/workbenches/clay.glb"
	var packed := load(path)
	if packed == null:
		print("LOAD_FAIL")
		quit(1)
		return
	var root: Node = packed.instantiate()
	var shown := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty() and shown < 6:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			print("MESH %s cast=%d" % [mi.name, mi.cast_shadow])
			shown += 1
		for child in node.get_children():
			stack.append(child)
	print("MESHES %d" % shown)
	root.free()
	quit(0)
