class_name WeaponComponent
extends Node3D
## Fires projectiles from its own position. The owning actor drives it by calling
## tick() every physics frame (held trigger) or fire() directly (scripted shots).

signal fired(projectile: Projectile)

@export var projectile_scene: PackedScene
@export var team: Teams.Team = Teams.Team.PLAYER
@export var damage: int = 1
@export var fire_interval: float = 0.1
@export var projectile_speed: float = 36.0
@export var direction: Vector3 = Vector3.RIGHT

var _cooldown: float = 0.0


func tick(delta: float, trigger_held: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if trigger_held and _cooldown <= 0.0:
		fire()
		_cooldown = fire_interval


func fire() -> Projectile:
	if projectile_scene == null:
		push_error("WeaponComponent '%s' has no projectile scene." % get_path())
		return null
	var root := Projectile.find_root(get_tree())
	if root == null:
		return null
	var projectile := projectile_scene.instantiate() as Projectile
	root.add_child(projectile)
	projectile.global_position = Vector3(global_position.x, global_position.y, 0.0)
	projectile.setup(team, damage, direction.normalized() * projectile_speed)
	fired.emit(projectile)
	return projectile


func reset() -> void:
	_cooldown = 0.0
