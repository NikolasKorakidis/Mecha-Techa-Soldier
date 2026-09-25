class_name TitleBackdrop
extends Node3D
## The title screen's 3D shot: the Kestrel cruising close to camera in a slow orbit, the enemy
## warship and two escorts gliding far below, asteroids and dust streaming past, under the
## campaign's space_vista sky. Purely decorative; no gameplay.

## The level's camera (kept as a GameplayCamera so shared systems find one; driven here).
@export var camera: GameplayCamera
@export var world_environment: WorldEnvironment

const SHIP_SPEED := 14.0

var kestrel: KestrelModel

var _warship: WarshipModel
var _escorts: Array[WarshipModel] = []
var _rocks: Array[MeshInstance3D] = []
var _dust: MultiMeshInstance3D
var _dust_pos: PackedVector3Array = []
var _time: float = 0.0
var _travel: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 314
	_setup_environment()
	kestrel = KestrelModel.new()
	kestrel.set_thrust(1.1)
	add_child(kestrel)
	var engine_light := OmniLight3D.new()
	engine_light.light_color = Palette.PLAYER_ENERGY
	engine_light.light_energy = 2.0
	engine_light.omni_range = 4.0
	engine_light.position = Vector3(-2.4, 0.0, 0.0)
	kestrel.add_child(engine_light)
	_warship = WarshipModel.new()
	_warship.runway = true
	_warship.scale = Vector3.ONE * 0.2
	_warship.position = Vector3(46.0, -40.0, -130.0)
	_warship.rotation.y = deg_to_rad(-12.0)
	add_child(_warship)
	for k in 2:
		var escort := WarshipModel.new()
		escort.low_detail = true
		escort.scale = Vector3.ONE * [0.05, 0.035][k]
		escort.position = Vector3([-70.0, 110.0][k], [-10.0, 22.0][k], [-260.0, -340.0][k])
		escort.rotation.y = deg_to_rad(-12.0)
		add_child(escort)
		_escorts.append(escort)
	for k in 14:
		var rock := MeshInstance3D.new()
		rock.mesh = SpaceRocks.mesh(k)
		rock.material_override = SpaceRocks.material()
		var far := k >= 6
		rock.scale = Vector3.ONE * (_rng.randf_range(0.6, 1.6) if not far else _rng.randf_range(3.0, 8.0))
		rock.position = Vector3(_rng.randf_range(-40, 60), _rng.randf_range(-12, 14), -_rng.randf_range(6, 20) if not far else -_rng.randf_range(60, 140))
		rock.set_meta(&"spin", Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4), 0))
		add_child(rock)
		_rocks.append(rock)
	_build_dust()
	if camera:
		camera.rig_override = true
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 38.0
		camera.near = 0.1
		camera.far = 6000.0
	_process(0.0)


func _setup_environment() -> void:
	if world_environment == null or world_environment.environment == null:
		push_error("TitleBackdrop: world_environment must be assigned.")
		return
	var env := world_environment.environment.duplicate() as Environment
	# The ORBIT system seen from a low angle: giant up-left, the blue world's limb below.
	env.sky = SpacePlanets.make_sky(SpacePlanets.Layout.ORBIT, Basis(Vector3.UP, deg_to_rad(8.0)))
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.52, 0.8)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = false
	world_environment.environment = env


func _build_dust() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 260
	_dust = MultiMeshInstance3D.new()
	_dust.multimesh = mm
	_dust.material_override = ModelKit.glow_billboard(Color(0.7, 0.85, 1.0), 0.9)
	_dust.custom_aabb = AABB(Vector3(-1e4, -1e3, -1e3), Vector3(2e4, 2e3, 2e3))
	add_child(_dust)
	_dust_pos.resize(mm.instance_count)
	for i in mm.instance_count:
		_dust_pos[i] = Vector3(_rng.randf_range(-30, 30), _rng.randf_range(-10, 10), _rng.randf_range(-25, 6))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.5, 1.8)), _dust_pos[i]))


func _process(delta: float) -> void:
	_time += delta
	_travel += SHIP_SPEED * delta
	# The ship holds position; the world streams past it (dust, rocks, the fleet).
	var drift := Vector3(-SHIP_SPEED * delta, 0, 0)
	kestrel.position = Vector3(0.0, sin(_time * 0.9) * 0.25, 0.0)
	kestrel.rotation = Vector3(sin(_time * 0.7) * 0.08, 0.0, sin(_time * 0.9 + 0.6) * 0.05)
	var mm := _dust.multimesh
	for i in _dust_pos.size():
		var p := _dust_pos[i] + drift * 1.6
		if p.x < -30.0:
			p.x += 60.0
		_dust_pos[i] = p
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	for rock in _rocks:
		var near := rock.position.z > -30.0
		rock.position += drift * (1.0 if near else 0.12)
		if rock.position.x < -60.0:
			rock.position.x += 130.0
		rock.rotation += rock.get_meta(&"spin") * delta
	_warship.position.x -= SHIP_SPEED * 0.02 * delta
	for escort in _escorts:
		escort.position.x -= SHIP_SPEED * 0.01 * delta
	if camera:
		# Slow cinematic orbit around the Kestrel, drifting between a 3/4 front and a side view.
		var a := deg_to_rad(28.0 + sin(_time * 0.12) * 14.0)
		var dist := 9.5 + sin(_time * 0.09) * 0.8
		var target := kestrel.position + Vector3(0.6, 0.3, 0.0)
		camera.global_position = target + Vector3(sin(a) * dist, 2.3 + sin(_time * 0.15) * 0.5, cos(a) * dist)
		camera.look_at(target + Vector3(-1.5, -0.4, 0.0), Vector3.UP)
