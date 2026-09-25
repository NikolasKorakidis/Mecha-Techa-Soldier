class_name PerspectiveBackdrop
extends Node3D
## G-Darius-style background for the side-view shooter: a separate 3D world with its own
## perspective camera flying forward, rendered into a texture on a screen behind the playfield.
## One continuous deep-space flight — no zone switches:
##   the campaign's star system (ringed gas giant, red moon, the blue world, the sun — the same
##   planets as Stage 3, seen from another angle), asteroids and capital ships streaming past;
##   the enemy warship (WarshipModel) creeps in from far away below the flight line over the
##   whole stage, so slowly it is barely noticed, until by the boss you are flying over its top,
##   the Stage 3 runway glowing down its spine.
## The boarding dive ends with set_boarding(), which frames the deck behind the Stage 2 roof.
## Purely visual; nothing here collides or reads gameplay state.

## Director whose boss marks the overflight (the approach finishes early if the boss comes first).
@export var director: LevelDirector
@export var resolution: Vector2i = Vector2i(1280, 720)
@export var flight_speed: float = 38.0
@export var screen_distance: float = 95.0
## Backdrop brightness on screen: kept below gameplay so ships and bullets always pop.
@export var dim: float = 0.62
## Its flat battle-debris layers stay on top of this backdrop.
@export var space_backdrop: SpaceBackdrop
## Stage seconds the warship takes to come from the far distance to the overflight.
@export var approach_time: float = 78.0
## Units per second the deck slides back under the camera during the overflight.
@export var overflight_speed: float = 9.0

## Warship offsets from the backdrop camera: far start, overflight, and boarding (Stage 2 roof).
const SHIP_START := Vector3(1700.0, -620.0, -2500.0)
const SHIP_OVER := Vector3(260.0, -95.0, -190.0)
const SHIP_BOARDING := Vector3(110.0, -64.0, -125.0)
const CAMERA_CRUISE := Vector3(-8.0, -14.0, 0.0)
const CAMERA_OVER := Vector3(-22.0, -12.0, 0.0)
const CAMERA_BOARDING := Vector3(-17.0, -18.0, 0.0)
const SKY := {
	"zenith": Color(0.01, 0.015, 0.05), "horizon": Color(0.05, 0.07, 0.18), "below": Color(0.0, 0.0, 0.02),
	"sun_color": Color(1.0, 0.9, 0.75), "sun_dir": Vector3(-0.55, 0.25, -0.8), "stars": 1.0, "nebula": 0.8,
}

var _viewport: SubViewport
var _camera: Camera3D
var _env: Environment
var _sky_mat: ShaderMaterial
var _planets: Node3D
var _streamers: Array[Node3D] = []
var _next_spawn_x: float = 0.0
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _warship: WarshipModel
var _ship_rel: Vector3 = SHIP_START
var _approach: float = 0.0
var _hurry: bool = false
var _boarding: bool = false
var _slide: float = 0.0


func _ready() -> void:
	_rng.seed = 2049
	_build_viewport()
	_planets = Node3D.new()
	_viewport.add_child(_planets)
	SpacePlanets.build(_planets, SpacePlanets.Layout.ORBIT)
	_warship = WarshipModel.new()
	_warship.clear_lane = 13.0
	_warship.runway = true
	_viewport.add_child(_warship)
	for key: String in SKY:
		_sky_mat.set_shader_parameter(StringName(key), SKY[key])
	if space_backdrop:
		space_backdrop.flat_warship_reveal = false
	if director:
		director.boss_spawned.connect(func(_b: BossBase) -> void: _hurry = true)
	_update_warship(0.0)


## Frame the warship deck behind the Stage 2 roof (after the boarding dive) and hold it there.
func set_boarding() -> void:
	_boarding = true
	_ship_rel = SHIP_BOARDING
	_camera.rotation_degrees = CAMERA_BOARDING
	_warship.position = _camera.position + _ship_rel


## 0 = far away at the stage start, 1 = flying over its top.
func approach_progress() -> float:
	return _approach


## Stops rendering the backdrop world entirely (3D stages never see it).
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	_clock += delta
	_camera.position.x += flight_speed * delta
	var cx := _camera.position.x
	_planets.position = _camera.position
	_update_warship(delta)
	# Stream asteroids and far capital ships; retire what has passed.
	while _next_spawn_x < cx + 420.0:
		_spawn_space(_next_spawn_x)
		_next_spawn_x += 40.0
	for node in _streamers.duplicate():
		if node.position.x < cx - 160.0:
			_streamers.erase(node)
			node.queue_free()
		elif node.has_meta(&"spin"):
			node.rotation += node.get_meta(&"spin") * delta


## The approach is eased so the first half is almost imperceptible: the ship only really grows
## in the last third of the stage. After it, the deck slides slowly back under the camera.
func _update_warship(delta: float) -> void:
	if _boarding:
		_warship.position = _camera.position + _ship_rel
		return
	var rate := 1.0 / approach_time if not _hurry else 1.0 / 6.0
	_approach = minf(1.0, _approach + delta * rate)
	var e := clampf(pow(_approach, 2.2) * (3.0 - 2.0 * _approach), 0.0, 1.0)
	_ship_rel = SHIP_START.lerp(SHIP_OVER, e)
	if _approach >= 1.0:
		_slide = minf(_slide + overflight_speed * delta, 520.0)
		_ship_rel.x -= _slide
	_camera.rotation_degrees = CAMERA_CRUISE.lerp(CAMERA_OVER, smoothstep(0.55, 1.0, _approach))
	_warship.position = _camera.position + _ship_rel


# --- Setup --------------------------------------------------------------------------------

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	var world_env := WorldEnvironment.new()
	_env = Environment.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://art/shaders/zone_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.35, 0.4, 0.6)
	_env.ambient_light_energy = 0.6
	# A light haze keeps the far warship a silhouette until it is close.
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.03, 0.05, 0.12)
	_env.fog_density = 0.00032
	_env.fog_sky_affect = 0.0
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = _env
	_viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.2
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.near = 0.5
	_camera.far = 5000.0
	_camera.rotation_degrees = CAMERA_CRUISE
	_camera.current = true
	_viewport.add_child(_camera)
	# The screen: fills the stage-1 view (32 x 18 at ortho size 18) behind every layer.
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(34.0, 19.2)
	screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_color = Color(dim, dim, dim * 1.05)
	screen.material_override = mat
	screen.position = Vector3(0, 0, -screen_distance)
	add_child(screen)


# --- Streaming scenery ---------------------------------------------------------------------

func _spawn_space(x: float) -> void:
	# Tumbling asteroids at mixed depths; now and then a capital ship far off.
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.2, 0.19, 0.24)
	rock.roughness = 0.95
	for k in 2:
		var a := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var r := _rng.randf_range(2.0, 9.0)
		mesh.radius = r
		mesh.height = r * _rng.randf_range(1.2, 1.9)
		mesh.radial_segments = 7
		mesh.rings = 4
		a.mesh = mesh
		a.material_override = rock
		a.position = Vector3(x + _rng.randf_range(0, 40), _rng.randf_range(-60, 40), _rng.randf_range(-80, -420))
		a.set_meta(&"spin", Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6), 0))
		_add_streamer(a)
	if _rng.randf() < 0.14:
		_add_streamer(_capital_ship(Vector3(x + 200.0, _rng.randf_range(10, 70), _rng.randf_range(-450, -750))))


func _capital_ship(at: Vector3) -> Node3D:
	var ship := Node3D.new()
	ship.position = at
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.14, 0.16, 0.24)
	var engine := StandardMaterial3D.new()
	engine.emission_enabled = true
	engine.emission = Color(0.5, 0.8, 1.0)
	engine.emission_energy_multiplier = 4.0
	var length := _rng.randf_range(60, 120)
	_box(ship, Vector3(length, 8, 16), Vector3.ZERO, hull)
	_box(ship, Vector3(length * 0.4, 10, 8), Vector3(-length * 0.1, 8, 0), hull)
	_box(ship, Vector3(2, 5, 12), Vector3(-length * 0.5 - 1, 0, 0), engine)
	ship.set_meta(&"spin", Vector3.ZERO)
	return ship


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _add_streamer(node: Node3D) -> void:
	_viewport.add_child(node)
	_streamers.append(node)
