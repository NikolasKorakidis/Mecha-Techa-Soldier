class_name DropCinematic
extends Node3D
## The world of the post-boss boarding dive, shown while the campaign camera goes perspective:
## the warship far below the Kestrel (runway glowing down its spine), the star system's planets
## around the camera and a real space sky. The side-view layers and the Stage 2/3 geometry are
## hidden by the director meanwhile; restore() puts the environment back and frees this.

const DECK_DROP := 200.0

var warship: WarshipModel

var _planets: Node3D
var _world_env: WorldEnvironment
var _saved_env: Environment


## Builds the scene around the Kestrel at `ship_at`.
func setup(ship_at: Vector3) -> void:
	warship = WarshipModel.new()
	warship.clear_lane = 13.0
	warship.runway = true
	warship.position = ship_at + Vector3(330.0, -DECK_DROP, 0.0)
	add_child(warship)
	# The ORBIT layout faces -Z; turn it so the same sky wraps around a camera looking along +X.
	_planets = Node3D.new()
	_planets.rotation_degrees = Vector3(0, -90, 0)
	add_child(_planets)
	SpacePlanets.build(_planets, SpacePlanets.Layout.ORBIT)
	var found := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if found.is_empty():
		return
	_world_env = found[0] as WorldEnvironment
	_saved_env = _world_env.environment
	var env := _saved_env.duplicate() as Environment
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://art/shaders/space_sky.gdshader")
	sky.sky_material = mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = false
	_world_env.environment = env


## World point on the runway where the dive aims (just above the deck).
func landing_point(ship_at: Vector3) -> Vector3:
	return Vector3(ship_at.x + 240.0, warship.position.y + 4.0, 0.0)


func restore() -> void:
	if _world_env and _saved_env:
		_world_env.environment = _saved_env
	queue_free()


func _process(_delta: float) -> void:
	var camera := GameplayCamera.find(get_tree())
	if camera:
		_planets.global_position = camera.global_position
