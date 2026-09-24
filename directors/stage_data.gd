class_name StageData
extends Resource
## A whole stage: waves, then a boss, then where to go next.

@export var stage_name: String = "STAGE"
@export var subtitle: String = ""
@export var waves: Array[WaveData] = []
@export var boss_scene: PackedScene
@export var boss_warning_time: float = 3.2
@export var clear_bonus: int = 10000
## Level scene loaded after the stage is cleared. Empty = final stage.
@export_file("*.tscn") var next_level: String = ""
## Where a final stage returns to after MISSION COMPLETE.
@export_file("*.tscn") var restart_level: String = ""
