class_name BeamHazard
extends Node3D
## Horizontal lightning line across the play area: a thin flashing warning, then a
## damaging beam, then gone. Tests positioning and dash timing.

const GROUP := &"hostile_hazard"

var warn_time: float = 1.0
var active_time: float = 0.5
var thickness: float = 1.0
var color: Color = Color(0.75, 0.55, 1.0)

var _age: float = 0.0
var _warning: MeshInstance3D
var _beam: MeshInstance3D
var _hitbox: HitboxComponent


static func create(y: float, warn: float, active: float, beam_color: Color, beam_thickness: float = 1.0) -> BeamHazard:
	var hazard := BeamHazard.new()
	hazard.position = Vector3(0, y, 0)
	hazard.warn_time = warn
	hazard.active_time = active
	hazard.color = beam_color
	hazard.thickness = beam_thickness
	return hazard


func _ready() -> void:
	add_to_group(GROUP)
	var camera := GameplayCamera.find(get_tree())
	var width := camera.get_play_rect().size.x + 4.0 if camera else 40.0
	position.x = camera.global_position.x if camera else 0.0
	_warning = ModelKit.quad(self, Vector2(width, 0.12), Vector3(0, 0, 0.6), ModelKit.glow(Color(1, 0.3, 0.35), 2.5))
	_beam = ModelKit.quad(self, Vector2(width, thickness * 2.2), Vector3(0, 0, 0.6), ModelKit.glow(color, 2.6))
	_beam.visible = false
	_hitbox = HitboxComponent.new()
	_hitbox.payload = DamagePayload.create(1, Teams.Team.ENEMY)
	_hitbox.single_hit = false
	_hitbox.continuous = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, 1.0)
	shape.shape = box
	_hitbox.add_child(shape)
	_hitbox.monitoring = false
	add_child(_hitbox)
	_hitbox.set_deferred(&"monitoring", false)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < warn_time:
		# Blink faster as the strike approaches.
		var rate := lerpf(6.0, 22.0, _age / warn_time)
		_warning.visible = fmod(_age * rate, 1.0) < 0.6
		return
	if not _beam.visible:
		_warning.visible = false
		_beam.visible = true
		_hitbox.set_deferred(&"monitoring", true)
		var camera := GameplayCamera.find(get_tree())
		if camera:
			camera.add_trauma(0.2)
	var t := (_age - warn_time) / active_time
	_beam.scale.y = 1.0 + 0.15 * sin(_age * 60.0)
	if t >= 1.0:
		queue_free()


func is_damaging() -> bool:
	return _beam != null and _beam.visible
