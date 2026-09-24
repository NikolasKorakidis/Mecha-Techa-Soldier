class_name Vfx
extends RefCounted
## Spawns one-shot effects into the level's effects node (group "vfx_root").

const ROOT_GROUP := &"vfx_root"


static func spawn(tree: SceneTree, scene: PackedScene, at: Vector3, size: float = 1.0, props: Dictionary = {}) -> Node3D:
	if scene == null:
		return null
	var root := tree.get_first_node_in_group(ROOT_GROUP)
	if root == null:
		push_error("No node in group '%s'; add an Effects node to the level." % ROOT_GROUP)
		return null
	var effect := scene.instantiate() as Node3D
	if &"size" in effect:
		effect.set(&"size", size)
	for key: StringName in props:
		effect.set(key, props[key])
	# Positioned before entering the tree so particles start at the right spot.
	effect.position = at - (root as Node3D).global_position if root is Node3D else at
	root.add_child(effect)
	return effect
