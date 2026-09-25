class_name PerspectiveBackdrop
extends Node3D
## G-Darius-style background for the side-view shooter: a separate 3D world with its own
## perspective camera flying forward, rendered into a texture on a screen behind the playfield.
## One continuous deep-space flight — no zone switches:
##   the space_vista sky (nebula, galactic band, the campaign's star system — ringed gas giant,
##   red moon, the blue ocean world, the sun — ray-traced, the same planets as Stage 3 seen from
##   another angle), lumpy asteroids and fine dust streaming past, distant capital ships;
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
var _viewport: SubViewport
var _camera: Camera3D
var _env: Environment
var _streamers: Array[Node3D] = []
var _dust: MultiMeshInstance3D
var _dust_pos: PackedVector3Array = []
var _cruisers: Array[WarshipModel] = []
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
	_build_dust()
	_build_cruisers()
	_warship = WarshipModel.new()
	_warship.clear_lane = 13.0
	_warship.runway = true
	_viewport.add_child(_warship)
	if space_backdrop:
		space_backdrop.flat_warship_reveal = false
		# The flat debris layers read as cut-outs against this backdrop; the 3D rocks replace them.
		space_backdrop.set_battle_layers_visible.call_deferred(false)
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
	_update_warship(delta)
	_update_dust()
	_update_cruisers(delta)
	# Stream asteroids; retire what has passed.
	while _next_spawn_x < cx + 420.0:
		_spawn_rocks(_next_spawn_x)
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
	_viewport.size = _render_size()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X if Settings.high_graphics else Viewport.MSAA_2X
	_viewport.use_debanding = true
	add_child(_viewport)
	get_viewport().size_changed.connect(func() -> void: _viewport.size = _render_size())
	var world_env := WorldEnvironment.new()
	_env = Environment.new()
	_env.sky = SpacePlanets.make_sky(SpacePlanets.Layout.ORBIT)
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
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.1
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = Color(dim, dim, dim * 1.05)
	screen.material_override = mat
	screen.position = Vector3(0, 0, -screen_distance)
	add_child(screen)


# --- Streaming scenery ---------------------------------------------------------------------

## Renders at the window's resolution (never below the authored one) so the backdrop is sharp.
func _render_size() -> Vector2i:
	var window := Vector2i(get_viewport().get_visible_rect().size)
	return Vector2i(maxi(window.x, resolution.x), maxi(window.y, resolution.y))


func _spawn_rocks(x: float) -> void:
	# Lumpy asteroids at mixed depths, sometimes a cluster, now and then a big one close by.
	var count := _rng.randi_range(1, 3)
	if _rng.randf() < 0.18:
		count += 4
	var cluster := Vector3(x + _rng.randf_range(0, 40), _rng.randf_range(-60, 40), _rng.randf_range(-90, -420))
	for k in count:
		var rock := MeshInstance3D.new()
		rock.mesh = SpaceRocks.mesh(_rng.randi())
		rock.material_override = SpaceRocks.material()
		var r := _rng.randf_range(1.5, 7.0) if k > 0 else _rng.randf_range(3.0, 10.0)
		rock.scale = Vector3.ONE * r
		rock.position = cluster + Vector3(_rng.randf_range(-18, 18), _rng.randf_range(-10, 10), _rng.randf_range(-20, 20)) * (0.0 if k == 0 else 1.0)
		rock.rotation = Vector3(_rng.randf_range(0, TAU), _rng.randf_range(0, TAU), 0)
		rock.set_meta(&"spin", Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.3)))
		_add_streamer(rock)
	if _rng.randf() < 0.12:
		var big := MeshInstance3D.new()
		big.mesh = SpaceRocks.mesh(_rng.randi())
		big.material_override = SpaceRocks.material()
		big.scale = Vector3.ONE * _rng.randf_range(10.0, 16.0)
		big.position = Vector3(x + 20.0, _rng.randf_range(-35, 25), _rng.randf_range(-55, -80))
		big.set_meta(&"spin", Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2), 0))
		_add_streamer(big)


## Fine dust and ice glinting past the camera: the sense of speed at every depth.
func _build_dust() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 320
	_dust = MultiMeshInstance3D.new()
	_dust.multimesh = mm
	_dust.material_override = ModelKit.glow_billboard(Color(0.7, 0.8, 1.0), 0.9)
	_dust.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e4), Vector3(2e5, 2e4, 2e4))
	_viewport.add_child(_dust)
	_dust_pos.resize(mm.instance_count)
	for i in mm.instance_count:
		_dust_pos[i] = Vector3(_rng.randf_range(-60, 160), _rng.randf_range(-45, 35), _rng.randf_range(-8, -140))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.5, 1.6)), _dust_pos[i]))


func _update_dust() -> void:
	var mm := _dust.multimesh
	var cx := _camera.position.x
	for i in _dust_pos.size():
		var p := _dust_pos[i]
		if p.x < cx - 60.0:
			p.x += 220.0
			p.y = _camera.position.y + _rng.randf_range(-45, 35)
			_dust_pos[i] = p
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.5, 1.6)), p))


## Distant capital ships (the real warship model, small and far) cruising the same way.
func _build_cruisers() -> void:
	for k in 3:
		var ship := WarshipModel.new()
		ship.low_detail = true
		ship.scale = Vector3.ONE * [0.09, 0.06, 0.12][k]
		ship.hull_color = [Color("1f2a44"), Color("2a2a3a"), Color("22304c")][k]
		ship.position = Vector3(260.0 + k * 420.0, _rng.randf_range(15, 80), _rng.randf_range(-520, -820))
		ship.set_meta(&"speed", _rng.randf_range(8.0, 16.0))
		_viewport.add_child(ship)
		_cruisers.append(ship)


func _update_cruisers(delta: float) -> void:
	var cx := _camera.position.x
	for ship in _cruisers:
		ship.position.x += float(ship.get_meta(&"speed")) * delta
		if ship.position.x < cx - 420.0:
			ship.position = Vector3(cx + _rng.randf_range(700, 1100), _rng.randf_range(15, 80), _rng.randf_range(-520, -820))


func _add_streamer(node: Node3D) -> void:
	_viewport.add_child(node)
	_streamers.append(node)
