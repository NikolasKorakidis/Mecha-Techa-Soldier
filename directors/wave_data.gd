class_name WaveData
extends Resource
## One authored wave: which enemy, how many, when, and where they enter.
## Times are seconds of stage time (accumulated physics delta), never frames.

@export var start_time: float = 0.0
@export var enemy_scene: PackedScene
@export var count: int = 1
## Seconds between units of the same wave.
@export var interval: float = 0.5
## Entry heights, cycled per unit.
@export var spawn_y: PackedFloat32Array = PackedFloat32Array([0.0])
## Entry X relative to the camera center (just past the right edge by default).
@export var spawn_x: float = 19.0
## Optional per-unit parking X for HOLD enemies, cycled.
@export var hold_x: PackedFloat32Array = PackedFloat32Array()
@export var speed_scale: float = 1.0
## Awarded when every unit of the wave is destroyed (none escape).
@export var completion_bonus: int = 0
## Short prompt shown when the wave starts (tutorial beats).
@export var prompt: String = ""
