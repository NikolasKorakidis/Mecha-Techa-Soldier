class_name PerspectiveBackdrop
extends Node3D
## G-Darius-style background for the side-view shooter: a separate 3D world with its own
## perspective camera flying forward, rendered into a texture on a screen behind the playfield.
## Near scenery streams past fast, far scenery slowly, everything recedes toward a horizon —
## real depth the orthographic gameplay camera cannot give. Three zones blend over the stage:
##   SPACE     planet, orbital ring, capital ships, asteroids streaming past
##   STATION   flying low over a colossal megastructure (towers, domes, arches, light strips)
##   SUNSET    above an endless cloud sea at dusk, rock spires rising through the clouds (boss)
## The enemy warship (WarshipModel) cruises into view far off late in the stage — the next
## destination — and approach_warship() dives the camera down onto its deck for the boarding.
## Purely visual; nothing here collides or reads gameplay state.

enum Zone { SPACE, STATION, SUNSET }

## Seconds into the stage when the megastructure zone begins (visual timeline only).
@export var station_time: float = 30.0
## Director whose boss starts the sunset zone (optional).
@export var director: LevelDirector
@export var resolution: Vector2i = Vector2i(1280, 720)
@export var flight_speed: float = 38.0
@export var screen_distance: float = 95.0
## Backdrop brightness on screen: kept below gameplay so ships and bullets always pop.
@export var dim: float = 0.62
## Its battle-debris layers (flat silhouettes) are hidden over the cloud sea.
@export var space_backdrop: SpaceBackdrop
## Stage seconds when the warship first shows up in the distance.
@export var warship_cameo_time: float = 16.0

## Warship offsets from the backdrop camera: far cameo, and the boarding view above its deck.
const SHIP_FAR_START := Vector3(1200.0, -200.0, -1300.0)
const SHIP_FAR := Vector3(430.0, -115.0, -820.0)
const SHIP_BOARDING := Vector3(120.0, -38.0, -150.0)
const CAMERA_CRUISE := Vector3(-8.0, -14.0, 0.0)
const CAMERA_BOARDING := Vector3(-24.0, -20.0, 0.0)

var zone: Zone = Zone.SPACE

var _viewport: SubViewport
var _camera: Camera3D
var _env: Environment
var _sky_mat: ShaderMaterial
var _space: Node3D
var _station: Node3D
var _sunset: Node3D
var _clouds: MeshInstance3D
var _streamers: Array[Node3D] = []
var _next_spawn_x: float = 0.0
var _clock: float = 0.0
var _sky_tween: Tween
var _rng := RandomNumberGenerator.new()
var _warship: WarshipModel
var _ship_rel: Vector3 = SHIP_FAR_START
var _ship_tween: Tween
var _screen_mat: StandardMaterial3D

const PRESETS := {
	Zone.SPACE: {
		"zenith": Color(0.01, 0.015, 0.05), "horizon": Color(0.05, 0.07, 0.18), "below": Color(0.0, 0.0, 0.02),
		"sun_color": Color(1.0, 0.9, 0.75), "sun_dir": Vector3(0.55, 0.25, -0.8), "stars": 1.0, "nebula": 0.7,
		"fog": Color(0.03, 0.05, 0.12), "fog_density": 0.0004,
	},
	Zone.STATION: {
		"zenith": Color(0.01, 0.02, 0.06), "horizon": Color(0.08, 0.13, 0.28), "below": Color(0.02, 0.03, 0.07),
		"sun_color": Color(0.8, 0.9, 1.0), "sun_dir": Vector3(0.4, 0.35, -0.85), "stars": 0.7, "nebula": 0.4,
		"fog": Color(0.07, 0.1, 0.22), "fog_density": 0.0022,
	},
	Zone.SUNSET: {
		"zenith": Color(0.22, 0.07, 0.2), "horizon": Color(1.0, 0.55, 0.3), "below": Color(0.55, 0.22, 0.2),
		"sun_color": Color(1.0, 0.75, 0.45), "sun_dir": Vector3(0.25, 0.06, -1.0), "stars": 0.04, "nebula": 0.0,
		"fog": Color(0.95, 0.5, 0.32), "fog_density": 0.0016,
	},
}


func _ready() -> void:
	_rng.seed = 2049
	_build_viewport()
	_build_space()
	_build_station_root()
	_build_sunset()
	_build_warship()
	_apply_preset(PRESETS[Zone.SPACE])
	if space_backdrop:
		space_backdrop.flat_warship_reveal = false
	_set_zone_visibility()
	if director:
		director.boss_spawned.connect(func(_b: BossBase) -> void: set_zone(Zone.SUNSET))


## Blend to a zone (sky colours ease over `blend` seconds; scenery changes stream in).
func set_zone(next: Zone, blend: float = 5.0) -> void:
	if next == zone:
		return
	zone = next
	if _sky_tween:
		_sky_tween.kill()
	var from := _current_preset()
	var to: Dictionary = PRESETS[next]
	_sky_tween = create_tween()
	_sky_tween.tween_method(func(k: float) -> void: _apply_preset(_lerp_preset(from, to, k)), 0.0, 1.0, blend)
	_next_spawn_x = _camera.position.x + 60.0
	get_tree().create_timer(blend * 0.5, false).timeout.connect(_set_zone_visibility)


## The warship slides into the far distance and cruises alongside (the next destination).
func show_warship(blend: float = 20.0) -> void:
	if _warship.visible:
		return
	_warship.visible = true
	_ship_rel = SHIP_FAR_START
	_tween_ship(SHIP_FAR, CAMERA_CRUISE, blend, Tween.EASE_OUT)


## Quick fade-through that clears the streamed scenery and snaps to open space (used when
## the boarding run starts, so the station or cloud sea does not linger around the warship).
func cut_to_open_space(fade: float = 0.5) -> void:
	var lit := _screen_mat.albedo_color
	var tween := create_tween()
	tween.tween_property(_screen_mat, "albedo_color", Color.BLACK, fade)
	tween.tween_callback(func() -> void:
		for node in _streamers:
			node.queue_free()
		_streamers.clear()
		zone = Zone.SPACE
		if _sky_tween:
			_sky_tween.kill()
		_apply_preset(PRESETS[Zone.SPACE])
		_set_zone_visibility()
		_next_spawn_x = _camera.position.x + 60.0)
	tween.tween_property(_screen_mat, "albedo_color", lit, fade * 2.0)


## Boarding run: the camera closes on the warship and tips down until its deck fills the
## lower half of the view, framed like the side-view roof the mech lands on.
func approach_warship(duration: float) -> void:
	if not _warship.visible:
		_warship.visible = true
		_ship_rel = SHIP_FAR
	_tween_ship(SHIP_BOARDING, CAMERA_BOARDING, duration, Tween.EASE_IN_OUT)


func warship_visible() -> bool:
	return _warship.visible


func _tween_ship(rel: Vector3, camera_rot: Vector3, duration: float, ease: Tween.EaseType) -> void:
	if _ship_tween:
		_ship_tween.kill()
	_ship_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(ease)
	_ship_tween.tween_property(self, "_ship_rel", rel, duration)
	_ship_tween.tween_property(_camera, "rotation_degrees", camera_rot, duration)


## Stops rendering the backdrop world entirely (3D stages never see it).
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	_clock += delta
	if zone == Zone.SPACE and _clock >= station_time and director != null and director.state == LevelDirector.State.WAVES:
		set_zone(Zone.STATION)
	if not _warship.visible and _clock >= warship_cameo_time:
		show_warship()
	_camera.position.x += flight_speed * delta
	var cx := _camera.position.x
	if _warship.visible:
		_warship.position = _camera.position + _ship_rel
	_space.position.x = cx
	_clouds.position.x = cx
	_sunset.get_node("Horizon").position.x = cx
	# Stream scenery for the active zone and retire what has passed.
	while _next_spawn_x < cx + 420.0:
		_spawn_row(_next_spawn_x)
		_next_spawn_x += 26.0 if zone == Zone.STATION else 40.0
	for node in _streamers.duplicate():
		if node.position.x < cx - 160.0:
			_streamers.erase(node)
			node.queue_free()
		elif node.has_meta(&"spin"):
			node.rotation += node.get_meta(&"spin") * delta


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
	_env.fog_enabled = true
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = _env
	_viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 1.2
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 3000.0
	_camera.rotation_degrees = Vector3(-8.0, -14.0, 0.0)
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
	_screen_mat = mat
	screen.material_override = mat
	screen.position = Vector3(0, 0, -screen_distance)
	add_child(screen)


func _build_space() -> void:
	_space = Node3D.new()
	_viewport.add_child(_space)
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = preload("res://art/shaders/gas_giant.gdshader")
	planet_mat.set_shader_parameter(&"band_dark", Color(0.03, 0.08, 0.22))
	planet_mat.set_shader_parameter(&"band_mid", Color(0.08, 0.22, 0.5))
	planet_mat.set_shader_parameter(&"band_light", Color(0.25, 0.5, 0.8))
	var planet := ModelKit.sphere(_space, 420.0, Vector3(180, -520, -900), planet_mat)
	(planet.mesh as SphereMesh).radial_segments = 64
	(planet.mesh as SphereMesh).rings = 32
	planet.rotation_degrees = Vector3(0, 0, 70)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 560.0
	torus.outer_radius = 575.0
	torus.rings = 128
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("1c2742")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.6, 0.3)
	ring_mat.emission_energy_multiplier = 0.15
	ring.material_override = ring_mat
	ring.position = planet.position
	ring.rotation_degrees = Vector3(78, 10, -8)
	_space.add_child(ring)


func _build_warship() -> void:
	_warship = WarshipModel.new()
	_warship.scale = Vector3.ONE * 0.5
	_warship.visible = false
	_viewport.add_child(_warship)


func _build_station_root() -> void:
	_station = Node3D.new()
	_viewport.add_child(_station)


func _build_sunset() -> void:
	_sunset = Node3D.new()
	_viewport.add_child(_sunset)
	_clouds = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000, 5000)
	_clouds.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://art/shaders/cloud_sea.gdshader")
	_clouds.material_override = mat
	_clouds.position = Vector3(0, -55, -1500)
	_sunset.add_child(_clouds)
	var horizon := Node3D.new()
	horizon.name = "Horizon"
	_sunset.add_child(horizon)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.3, 0.1, 0.16)
	for k in 9:
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = _rng.randf_range(60, 140)
		cone.height = _rng.randf_range(90, 220)
		cone.radial_segments = 5
		peak.mesh = cone
		peak.material_override = dark
		peak.position = Vector3(-900 + k * 230 + _rng.randf_range(-60, 60), -40, -1800)
		horizon.add_child(peak)


# --- Streaming scenery -----------------------------------------------------------------

func _spawn_row(x: float) -> void:
	match zone:
		Zone.SPACE:
			_spawn_space(x)
		Zone.STATION:
			_spawn_station(x)
		Zone.SUNSET:
			_spawn_spire(x)


func _spawn_space(x: float) -> void:
	# Tumbling asteroids at mixed depths; now and then a capital ship far off.
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.22, 0.2, 0.26)
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
		a.position = Vector3(x + _rng.randf_range(0, 40), _rng.randf_range(-70, 30), _rng.randf_range(-80, -420))
		a.set_meta(&"spin", Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6), 0))
		_add_streamer(a)
	if _rng.randf() < 0.18:
		_add_streamer(_capital_ship(Vector3(x + 200.0, _rng.randf_range(-20, 50), _rng.randf_range(-400, -700))))


func _spawn_station(x: float) -> void:
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.16, 0.2, 0.32)
	hull.metallic = 0.4
	hull.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.1, 0.17)
	var lights := StandardMaterial3D.new()
	lights.albedo_color = Color(1.0, 0.75, 0.4)
	lights.emission_enabled = true
	lights.emission = Color(1.0, 0.7, 0.35)
	lights.emission_energy_multiplier = 1.4
	var cyan := StandardMaterial3D.new()
	cyan.emission_enabled = true
	cyan.emission = Color(0.4, 0.85, 1.0)
	cyan.emission_energy_multiplier = 3.0
	var row := Node3D.new()
	row.position = Vector3(x, -95, 0)
	# Deck plate strip across depth with a glowing lane.
	_box(row, Vector3(24, 4, 700), Vector3(0, 0, -400), dark)
	_box(row, Vector3(1.0, 0.3, 700), Vector3(0, 2.2, -400), cyan)
	for k in 5:
		var z := -140.0 - k * _rng.randf_range(70, 130)
		var kind := _rng.randi() % 4
		match kind:
			0:
				var h := _rng.randf_range(20, 70)
				_box(row, Vector3(14, h, 14), Vector3(_rng.randf_range(-6, 6), h * 0.5, z), hull)
				for w in int(h / 10.0):
					_box(row, Vector3(14.2, 0.8, 1.2), Vector3(0, 6 + w * 10.0, z + 7.0), lights)
			1:
				var dome := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = _rng.randf_range(12, 26)
				s.height = s.radius
				s.is_hemisphere = true
				dome.mesh = s
				dome.material_override = hull
				dome.position = Vector3(0, 2, z)
				row.add_child(dome)
			2:
				_box(row, Vector3(4, 60, 4), Vector3(-8, 30, z), dark)
				_box(row, Vector3(4, 60, 4), Vector3(8, 30, z), dark)
				_box(row, Vector3(24, 5, 6), Vector3(0, 62, z), hull)
				_box(row, Vector3(24, 0.6, 6.2), Vector3(0, 60, z), cyan)
			_:
				_box(row, Vector3(20, 10, 30), Vector3(0, 5, z), hull)
				_box(row, Vector3(20.2, 1.0, 1.0), Vector3(0, 8, z + 15.0), lights)
	# Occasional giant arch spanning over the flight path.
	if _rng.randf() < 0.12:
		_box(row, Vector3(10, 190, 10), Vector3(0, 30, -150), dark)
		_box(row, Vector3(12, 6, 600), Vector3(0, 125, -430), hull)
		_box(row, Vector3(12.2, 0.6, 600), Vector3(0, 122, -430), cyan)
	_add_streamer(row)


func _spawn_spire(x: float) -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.32, 0.14, 0.17)
	rock.roughness = 1.0
	for k in 2:
		var spire := Node3D.new()
		spire.position = Vector3(x + _rng.randf_range(0, 30), -60, _rng.randf_range(-170, -700))
		var h := _rng.randf_range(40, 130)
		var r := _rng.randf_range(8, 22)
		for s in 3:
			var seg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = r * (0.7 - s * 0.2)
			cyl.bottom_radius = r * (1.0 - s * 0.25)
			cyl.height = h / 3.0
			cyl.radial_segments = 6
			seg.mesh = cyl
			seg.material_override = rock
			seg.position = Vector3(_rng.randf_range(-2, 2), h / 6.0 + s * h / 3.0, 0)
			seg.rotation_degrees = Vector3(0, _rng.randf_range(0, 60), _rng.randf_range(-6, 6))
			spire.add_child(seg)
		_add_streamer(spire)
	if _rng.randf() < 0.15:
		_add_streamer(_capital_ship(Vector3(x + 180.0, _rng.randf_range(10, 60), _rng.randf_range(-300, -600))))


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


func _set_zone_visibility() -> void:
	_space.visible = zone != Zone.SUNSET
	_sunset.visible = zone == Zone.SUNSET
	if space_backdrop:
		space_backdrop.set_battle_layers_visible(zone != Zone.SUNSET)


# --- Sky presets -----------------------------------------------------------------------

func _current_preset() -> Dictionary:
	return {
		"zenith": _sky_mat.get_shader_parameter(&"zenith"), "horizon": _sky_mat.get_shader_parameter(&"horizon"),
		"below": _sky_mat.get_shader_parameter(&"below"), "sun_color": _sky_mat.get_shader_parameter(&"sun_color"),
		"sun_dir": _sky_mat.get_shader_parameter(&"sun_dir"), "stars": _sky_mat.get_shader_parameter(&"stars"),
		"nebula": _sky_mat.get_shader_parameter(&"nebula"), "fog": _env.fog_light_color, "fog_density": _env.fog_density,
	}


func _lerp_preset(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key: String in b:
		out[key] = lerp(a[key], b[key], k)
	return out


func _apply_preset(p: Dictionary) -> void:
	for key: String in ["zenith", "horizon", "below", "sun_color", "sun_dir", "stars", "nebula"]:
		_sky_mat.set_shader_parameter(StringName(key), p[key])
	_env.fog_light_color = p["fog"]
	_env.fog_density = p["fog_density"]
