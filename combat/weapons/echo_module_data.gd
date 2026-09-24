class_name EchoModuleData
extends Resource
## One echo weapon: what an elite drops and the ship fires while ammo lasts.

@export var id: StringName
@export var display_name: String
@export var module_color: Color = Color.WHITE
## Shots (volleys) granted per pickup.
@export var ammo: int = 100
@export var fire_interval: float = 0.1
@export var damage: int = 1
