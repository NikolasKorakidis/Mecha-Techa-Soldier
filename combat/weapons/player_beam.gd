class_name PlayerBeam
extends Node3D
## SUPER: Resonance Beam. A short charge flash, then a thick violet-cyan beam that shreds
## everything in its path (continuous damage every physics tick) and erases hostile shots.
## Follows its anchor so a moving ship keeps firing it.

const CHARGE_TIME := 0.22

@export var length: float = 32.0
@export var thickness: float = 2.2
@export var duration: float = 1.35

var anchor: Node3D
var direction: float = 1.0

var _age: float = 0.0
var _hitbox: HitboxComponent
var _eraser: Area3D
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _charge: MeshInstance3D


static func create(from: Node3D, facing: float, beam_duration: float = 1.35) -> PlayerBeam:
	var beam := PlayerBeam.new()
	beam.anchor = from
	beam.direction = signf(facing) if facing != 0.0 else 1.0
	beam.duration = beam_duration
	return beam


func _ready() -> void:
	_follow()
	var half := length * 0.5 * direction
	_charge = ModelKit.quad(self, Vector2.ONE * 3.0, Vector3(0, 0, 0.8), ModelKit.glow(Color.WHITE, ArtStyle.GLOW_HOT * ArtStyle.flash_scale()))
	_glow = ModelKit.quad(self, Vector2(length, thickness * 1.9), Vector3(half, 0, 0.6), ModelKit.glow(Palette.RESONANCE_VIOLET, ArtStyle.GLOW_STANDARD))
	_core = ModelKit.quad(self, Vector2(length, thickness * 0.8), Vector3(half, 0, 0.7), ModelKit.glow(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.5), ArtStyle.GLOW_HOT))
	_glow.visible = false
	_core.visible = false
	_hitbox = HitboxComponent.new()
	_hitbox.payload = DamagePayload.create(1, Teams.Team.PLAYER)
	_hitbox.payload.damage_type = &"resonance"
	_hitbox.single_hit = false
	_hitbox.continuous = true
	_hitbox.source = self
	_hitbox.add_child(_box_shape())
	_hitbox.position = Vector3(half, 0, 0)
	add_child(_hitbox)
	_hitbox.set_deferred(&"monitoring", false)
	_eraser = Area3D.new()
	_eraser.collision_layer = 0
	_eraser.collision_mask = PhysicsLayers.HITBOX
	_eraser.monitorable = false
	_eraser.add_child(_box_shape())
	_eraser.position = Vector3(half, 0, 0)
	_eraser.monitoring = false
	add_child(_eraser)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.add_trauma(ArtStyle.SHAKE_MAJOR)


func _box_shape() -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, thickness, 2.0)
	shape.shape = box
	return shape


func is_firing() -> bool:
	return _age >= CHARGE_TIME and _age < duration


func _physics_process(delta: float) -> void:
	_age += delta
	_follow()
	if _age < CHARGE_TIME:
		_charge.scale = Vector3.ONE * (0.4 + _age / CHARGE_TIME)
		return
	if not _core.visible:
		_charge.visible = false
		_core.visible = true
		_glow.visible = true
		_hitbox.monitoring = true
		_eraser.monitoring = true
	var fade := clampf((duration - _age) / 0.2, 0.0, 1.0)
	_core.scale.y = (0.85 + 0.15 * sin(_age * 50.0)) * fade
	_glow.scale.y = (0.9 + 0.1 * sin(_age * 23.0)) * fade
	for area in _eraser.get_overlapping_areas():
		var hitbox := area as HitboxComponent
		if hitbox and hitbox.payload and hitbox.payload.team == Teams.Team.ENEMY and hitbox.get_parent() is Projectile:
			hitbox.get_parent().queue_free()
	if _age >= duration:
		queue_free()


func _follow() -> void:
	if is_instance_valid(anchor):
		global_position = Vector3(anchor.global_position.x, anchor.global_position.y, 0.0)
