class_name ForwardBeam
extends Node3D
## SUPER in the 3D chase view: a long Resonance Beam straight down the track (+X). Crossed
## glow planes read from behind and from the side; shreds everything in the corridor and
## erases hostile bolts. Follows its anchor.

const CHARGE_TIME := 0.2

var anchor: Node3D
var length: float = 110.0
var width: float = 4.0
var duration: float = 1.4

var _age: float = 0.0
var _hitbox: HitboxComponent
var _eraser: Area3D
var _planes: Array[MeshInstance3D] = []
var _charge: MeshInstance3D


static func create(from: Node3D, beam_duration: float) -> ForwardBeam:
	var beam := ForwardBeam.new()
	beam.anchor = from
	beam.duration = beam_duration
	return beam


func _ready() -> void:
	_follow()
	_charge = MeshInstance3D.new()
	_charge.mesh = QuadMesh.new()
	_charge.material_override = ModelKit.glow_billboard(Color.WHITE, ArtStyle.GLOW_HOT * ArtStyle.flash_scale())
	_charge.scale = Vector3.ONE * 3.0
	add_child(_charge)
	for rot: Vector3 in [Vector3.ZERO, Vector3(90, 0, 0)]:
		var outer := ModelKit.quad(self, Vector2(length, width * 1.8), Vector3(length * 0.5, 0, 0), ModelKit.glow(Palette.RESONANCE_VIOLET, ArtStyle.GLOW_STANDARD), rot)
		var core := ModelKit.quad(self, Vector2(length, width * 0.7), Vector3(length * 0.5, 0, 0), ModelKit.glow(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.5), ArtStyle.GLOW_HOT), rot)
		outer.visible = false
		core.visible = false
		_planes.append(outer)
		_planes.append(core)
	_hitbox = HitboxComponent.new()
	_hitbox.payload = DamagePayload.create(1, Teams.Team.PLAYER)
	_hitbox.payload.damage_type = &"resonance"
	_hitbox.single_hit = false
	_hitbox.continuous = true
	_hitbox.source = self
	_hitbox.add_child(_shape())
	_hitbox.position = Vector3(length * 0.5, 0, 0)
	add_child(_hitbox)
	_hitbox.set_deferred(&"monitoring", false)
	_eraser = Area3D.new()
	_eraser.collision_layer = 0
	_eraser.collision_mask = PhysicsLayers.HITBOX
	_eraser.monitorable = false
	_eraser.add_child(_shape())
	_eraser.position = Vector3(length * 0.5, 0, 0)
	_eraser.monitoring = false
	add_child(_eraser)
	AudioService.play(&"beam", 0.0, 0.0)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.add_trauma(ArtStyle.SHAKE_MAJOR)


func _shape() -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, width, width * 1.4)
	shape.shape = box
	return shape


func _physics_process(delta: float) -> void:
	_age += delta
	_follow()
	if _age < CHARGE_TIME:
		_charge.scale = Vector3.ONE * (1.0 + 3.0 * _age / CHARGE_TIME)
		return
	if not _planes[0].visible:
		_charge.visible = false
		for p in _planes:
			p.visible = true
		_hitbox.monitoring = true
		_eraser.monitoring = true
	var fade := clampf((duration - _age) / 0.2, 0.0, 1.0)
	for i in _planes.size():
		var wobble := 0.85 + 0.15 * sin(_age * (50.0 if i % 2 else 23.0))
		if i < 2:
			_planes[i].scale.y = wobble * fade
		else:
			_planes[i].scale.z = wobble * fade
	for area in _eraser.get_overlapping_areas():
		var hb := area as HitboxComponent
		if hb and hb.payload and hb.payload.team == Teams.Team.ENEMY and hb.get_parent() is Bolt3D:
			hb.get_parent().queue_free()
	if _age >= duration:
		queue_free()


func _follow() -> void:
	if is_instance_valid(anchor):
		global_position = anchor.global_position
