class_name Players
extends RefCounted
## Lookup for whichever player avatar is active (ship, mech or bike). Every avatar joins
## GROUP and exposes: hurtbox, health, collect_echo(id), can_collect(), grant_invulnerability(s).

const GROUP := &"player"


static func find(tree: SceneTree) -> Node3D:
	return tree.get_first_node_in_group(GROUP) as Node3D


## Visible, alive avatar or null.
static func find_active(tree: SceneTree) -> Node3D:
	var p := find(tree)
	return p if p and p.visible else null


## Where enemies should aim (body center, not feet) for any avatar.
static func aim_point(player: Node3D) -> Vector3:
	var offset: Vector3 = player.get(&"aim_offset") if &"aim_offset" in player else Vector3.ZERO
	return player.global_position + offset
