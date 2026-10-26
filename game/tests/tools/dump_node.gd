extends SceneTree

## Debug helper: print node transforms and mesh AABBs for names matching a filter.
## usage: --script res://tests/tools/dump_node.gd -- <glb> <substring>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/models/maps/guyao.glb"
	var needle := args[1] if args.size() > 1 else "island"
	var packed := load(path)
	if packed == null:
		print("LOAD_FAIL")
		quit(1)
		return
	var root: Node = packed.instantiate()
	_walk(root, Transform3D.IDENTITY, "", needle)
	root.free()
	quit(0)


func _walk(node: Node, parent_xform: Transform3D, path: String, needle: String) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var here := path + "/" + node.name
	if node is MeshInstance3D and needle.to_lower() in node.name.to_lower():
		var mi := node as MeshInstance3D
		var local: AABB = mi.get_aabb()
		var world: AABB = xform * local
		print("NODE %s" % here)
		print("  xform.origin=%s scale=%s" % [xform.origin, xform.basis.get_scale()])
		print("  local aabb=(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)" % [
			local.position.x, local.position.y, local.position.z,
			local.end.x, local.end.y, local.end.z])
		print("  world aabb=(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)" % [
			world.position.x, world.position.y, world.position.z,
			world.end.x, world.end.y, world.end.z])
	for child in node.get_children():
		_walk(child, xform, here, needle)
