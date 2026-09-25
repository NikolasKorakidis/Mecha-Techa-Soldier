class_name MidBossZone
extends Node3D
## Sealed mid-boss room (Mega Man style): walking in shuts both blast doors, locks the camera,
## drops the boss in; beating it opens the way on and leaves a Heart Tank. If the player dies
## in here the room resets (doors open, boss gone) so the fight restarts from the checkpoint.
## Built in code by WarshipLayout; finds player, camera and UI by group at runtime.

signal cleared

enum State { ARMED, WARNING, FIGHT, CLEARED }

const WARNING_TIME := 1.6
const SENTINEL := preload("res://enemies/bosses/sentinel.tscn")

@export var left_x: float = 245.5
@export var right_x: float = 270.5
@export var floor_y: float = 0.0
@export var trigger_x: float = 250.0
@export var camera_center: Vector2 = Vector2(258.0, 6.0)
@export var enemy_root: Node3D
@export var pickup_root: Node3D

var state: State = State.ARMED
var boss: BossBase

var _gates: Array[StaticBody3D] = []
var _state_time: float = 0.0
var _player: Node3D


func _ready() -> void:
	add_to_group(&"mid_boss_zones")
	for x: float in [left_x, right_x]:
		_gates.append(_build_gate(x))
	_set_gates(false)


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.ARMED:
			_player = Players.find(get_tree())
			if _player and _player.visible and _player.global_position.x >= trigger_x \
					and _player.global_position.x < right_x and _player.global_position.y < floor_y + 12.0:
				_seal()
		State.WARNING:
			if _state_time >= WARNING_TIME:
				_spawn_boss()


## Test/debug entry: seal and start immediately.
func start() -> void:
	if state == State.ARMED:
		_player = Players.find(get_tree())
		_seal()


func _seal() -> void:
	if _player == null:
		push_error("MidBossZone: no player to fight.")
		return
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_set_gates(true)
	AudioService.play(&"door")
	AudioService.stop_music(0.8)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.lock_to(camera_center)
	var ui := StageUI.find(get_tree())
	if ui:
		ui.show_warning(WARNING_TIME)
	_set_state(State.WARNING)


func _spawn_boss() -> void:
	var sentinel := SENTINEL.instantiate() as SentinelBoss
	sentinel.arena_left = left_x + 0.6
	sentinel.arena_right = right_x - 0.6
	sentinel.floor_y = floor_y
	boss = sentinel
	boss.summon_root = enemy_root
	enemy_root.get_parent().add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	var ui := StageUI.find(get_tree())
	if ui:
		ui.track_boss(boss)
	AudioService.play_music(&"boss", 0.3)
	_set_state(State.FIGHT)


func _on_boss_defeated() -> void:
	boss = null
	_set_gates(false)
	AudioService.play(&"door")
	AudioService.play_jingle(&"stage_clear")
	AudioService.play_music(&"stage2", 1.0)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.unlock()
	var ui := StageUI.find(get_tree())
	if ui:
		ui.show_banner("SENTINEL DOWN", "THE WAY IS OPEN", 2.2)
	var heart := ItemPickup.new()
	heart.kind = ItemPickup.Kind.HEART
	heart.position = Vector3(camera_center.x, floor_y + 1.4, 0) - pickup_root.global_position
	pickup_root.add_child.call_deferred(heart)
	_set_state(State.CLEARED)
	cleared.emit()


## Death mid-fight: tear the encounter down; walking back in restarts it.
func _on_player_died() -> void:
	if state != State.WARNING and state != State.FIGHT:
		return
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null
	BossBase.clear_hostile_projectiles(get_tree())
	_set_gates(false)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.unlock()
	var ui := StageUI.find(get_tree())
	if ui:
		ui.hide_generic()
	AudioService.play_music(&"stage2", 1.0)
	_set_state(State.ARMED)


func _set_gates(closed: bool) -> void:
	for gate in _gates:
		gate.visible = closed
		for child in gate.find_children("*", "CollisionShape3D", true, false):
			(child as CollisionShape3D).set_deferred(&"disabled", not closed)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0


func _build_gate(x: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = Vector3(x, floor_y, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 22.0, LevelKit.DEPTH)
	shape.shape = box
	shape.position = Vector3(0, 11.0, 0)
	body.add_child(shape)
	ModelKit.box(body, Vector3(1.0, 22.0, 2.6), Vector3(0, 11.0, 0), ModelKit.hull(Color("3d4a66")))
	for y in range(1, 22, 3):
		LevelKit.stripes(body, -0.5, float(y), 1.0)
	ModelKit.box(body, Vector3(0.25, 22.0, 0.2), Vector3(0, 11.0, 1.2), LevelKit.material(&"red_light"))
	add_child(body)
	return body
