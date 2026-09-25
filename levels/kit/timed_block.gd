class_name TimedBlock
extends StaticBody3D
## Mega Man "appearing block": solid for `on_time`, gone for `off_time`, repeating; `offset`
## staggers a row into a rhythm. It flickers for `warn_time` before vanishing so the beat can
## be read, and pops in with a flash.

@export var width: float = 3.0
@export var on_time: float = 1.8
@export var off_time: float = 1.4
@export var offset: float = 0.0
@export var warn_time: float = 0.45
@export var color: Color = Color(1.0, 0.55, 0.2)

var solid: bool = true

var _time: float = 0.0
var _shape: CollisionShape3D
var _visual: Node3D
var _flash: MeshInstance3D


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, LevelKit.DEPTH)
	_shape.shape = box
	add_child(_shape)
	_visual = ModelKit.group(self, "Visual")
	ModelKit.box(_visual, Vector3(width, 1.0, 2.4), Vector3.ZERO, ModelKit.hull(color.darkened(0.55), ArtStyle.OUTLINE_THIN))
	ModelKit.box(_visual, Vector3(width - 0.3, 0.7, 2.44), Vector3.ZERO, ModelKit.emissive(color, 1.2))
	ModelKit.box(_visual, Vector3(width, 0.16, 2.5), Vector3(0, 0.46, 0), LevelKit.material(&"trim"))
	_flash = ModelKit.quad(self, Vector2(width * 1.8, 2.4), Vector3(0, 0, 1.4), ModelKit.glow(color, 1.4))
	_flash.visible = false
	_time = -offset
	_apply(_cycle_time())


func _cycle_time() -> float:
	return fposmod(_time, on_time + off_time)


func _physics_process(delta: float) -> void:
	_time += delta
	_apply(_cycle_time())


func _apply(t: float) -> void:
	var on := t < on_time
	if on != solid:
		solid = on
		_shape.set_deferred(&"disabled", not on)
		if on:
			_flash.visible = true
			get_tree().create_timer(0.08, false).timeout.connect(func() -> void: _flash.visible = false)
	# Warning flicker before it disappears.
	var warning := on and t > on_time - warn_time
	_visual.visible = on and (not warning or fmod(t * 14.0, 1.0) < 0.6)
