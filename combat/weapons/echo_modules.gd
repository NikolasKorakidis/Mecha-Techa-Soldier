class_name EchoModules
extends RefCounted
## Lookup for the three echo modules. Exactly three by design — no fourth in the slice.

const BURST := &"burst"
const ARC := &"arc"
const GUARD := &"guard"
const ALL: Array[StringName] = [BURST, ARC, GUARD]

const _PATHS := {
	BURST: "res://combat/weapons/echoes/burst.tres",
	ARC: "res://combat/weapons/echoes/arc.tres",
	GUARD: "res://combat/weapons/echoes/guard.tres",
}


static func get_data(id: StringName) -> EchoModuleData:
	if not _PATHS.has(id):
		return null
	return load(_PATHS[id]) as EchoModuleData
