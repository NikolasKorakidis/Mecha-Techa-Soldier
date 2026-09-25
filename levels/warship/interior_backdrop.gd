class_name InteriorBackdrop
extends Node3D
## Warship interior depth, parallaxed against the moving camera (side view):
##   back wall  (x0.55, z -9): hull panels, ribs, window bays onto space (space_window glass: the
##                             Stage 1 planets and nebula with fake perspective), pipe runs with flanges,
##                             flickering screens, rotating beacons, spinning vent fans,
##                             generator blocks with pulsing coils
##   mid layer  (x0.8,  z -5): pillars with cross braces, hanging cables, crate stacks, catwalks
##   foreground (x1.25, z +6): dark girders and cable clumps passing in front of the action
## Only shown while the camera is inside the ship (the campaign flies past it from space).
## Every section has its own colour zone (WarshipZones): tinted wall panels, pools of accent
## light along the play plane, signature machinery (ZoneSetPieces) and a depth fog that tints
## the far layers — while inside, the environment fog follows the camera's zone.

@export var level_length: float = 330.0
## Camera X range in which the interior is drawn.
@export var interior_x: Vector2 = Vector2(-40.0, 345.0)
## Above this camera Y the camera is outside on the roof deck.
@export var interior_max_y: float = 25.0
## Camera X beyond which foreground girders are hidden (boss arena approach).
@export var fore_cutoff_x: float = 285.0
## Standalone levels have no campaign sky; build a simple one.
@export var own_sky: bool = true

const WALL_FACTOR := 0.55
const MID_FACTOR := 0.8
const FORE_FACTOR := 1.25

var _sky: Node3D
var _wall: Node3D
var _mid: Node3D
var _fore: Node3D
var _camera: GameplayCamera
var _lights: Array[StandardMaterial3D] = []
var _screens: Array[StandardMaterial3D] = []
var _beacons: Array[Node3D] = []
var _fans: Array[Node3D] = []
var _coils: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _zone_lights: Node3D
var _env: Environment
var _zone_mats: Dictionary = {}
var _key_light: DirectionalLight3D
var _key_color: Color
var _rim_light: DirectionalLight3D
var _rim_color: Color


func _ready() -> void:
	_rng.seed = 9
	_camera = GameplayCamera.find(get_tree())
	_wall = ModelKit.group(self, "BackWall")
	_mid = ModelKit.group(self, "MidLayer")
	_fore = ModelKit.group(self, "Foreground")
	if own_sky:
		_sky = ModelKit.group(self, "Sky")
		_build_sky()
	_build_wall()
	_build_mid()
	_build_foreground()
	var pieces := ZoneSetPieces.new()
	pieces.factor = MID_FACTOR
	_mid.add_child(pieces)
	_build_zone_lights()
	_bind_environment()


func _build_sky() -> void:
	var nebula := ShaderMaterial.new()
	nebula.shader = preload("res://art/shaders/nebula.gdshader")
	nebula.set_shader_parameter(&"deep_color", Palette.BG_DEEP_NAVY)
	nebula.set_shader_parameter(&"teal_color", Palette.BG_BLUE)
	nebula.set_shader_parameter(&"violet_color", Palette.BG_VIOLET)
	nebula.set_shader_parameter(&"brightness", 0.8)
	ModelKit.quad(_sky, Vector2(60, 34), Vector3(0, 0, -70), nebula)
	var stars := Starfield.new()
	stars.star_count = 120
	stars.layer_speeds = PackedFloat32Array([0.0, 0.0])
	stars.extents = Vector2(28, 16)
	stars.depth = -65.0
	stars.star_color = Color(0.55, 0.65, 0.85)
	stars.star_size = 0.06
	stars.stretch_by_speed = false
	_sky.add_child(stars)


func _build_wall() -> void:
	var panel_a := ModelKit.toon(Color("0c1322"), 0.15, 0.9, 0.2)
	var panel_b := ModelKit.toon(Color("101a2c"), 0.18, 0.85, 0.25)
	var inset_base := ModelKit.toon(Color("15213a"), 0.25, 0.7, 0.35)
	var inset := inset_base
	var rib := ModelKit.toon(Color("18233a"), 0.25, 0.7, 0.4)
	var bolt := ModelKit.toon(Color("3a4866"), 0.4, 0.5, 0.6)
	var frame := ModelKit.toon(Color("22304f"), 0.3, 0.6, 0.4)
	var pipe := ModelKit.toon(Color("27324e"), 0.45, 0.45, 0.6)
	var flange := ModelKit.toon(Color("3b4a6c"), 0.5, 0.4, 0.7)
	var stripe := ModelKit.toon(Palette.INTERACTABLE.darkened(0.45), 0.2, 0.7, 0.2)
	# Window glass looks out onto the same star system as Stage 1 (space_window shader).
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://art/shaders/space_window.gdshader")
	SpacePlanets.apply(glass, SpacePlanets.Layout.ORBIT)
	glass.set_shader_parameter(&"pixel_angle", 0.0006)
	# Travelling through the ship pans the view from the gas giant past the red moon.
	glass.set_shader_parameter(&"view_offset", Vector2(-0.4, 0.06))
	glass.set_shader_parameter(&"drift", 0.0028)
	glass.set_shader_parameter(&"brightness", 1.5)
	var z := -9.0
	var x := -240.0
	var i := 0
	while x < 400.0:
		var cx := x + 3.0
		var window := i % 4 == 1
		var zone_x := cx / WALL_FACTOR
		var mat := _zone_mat(panel_a if i % 2 == 0 else panel_b, zone_x)
		inset = _zone_mat(inset_base, zone_x, 0.2)
		if window:
			ModelKit.box(_wall, Vector3(6.0, 15.0, 0.4), Vector3(cx, -4.5, z), mat)
			ModelKit.box(_wall, Vector3(6.0, 12.0, 0.4), Vector3(cx, 16.0, z), mat)
			ModelKit.quad(_wall, Vector2(6.0, 7.0), Vector3(cx, 6.5, z - 0.1), glass)
			# Heavy frame with a central mullion and corner gussets.
			ModelKit.box(_wall, Vector3(6.2, 0.5, 0.8), Vector3(cx, 3.1, z + 0.2), frame)
			ModelKit.box(_wall, Vector3(6.2, 0.5, 0.8), Vector3(cx, 9.9, z + 0.2), frame)
			ModelKit.box(_wall, Vector3(0.3, 6.8, 0.6), Vector3(cx, 6.5, z + 0.2), frame)
			for gx: float in [-2.6, 2.6]:
				ModelKit.prism(_wall, Vector3(0.8, 0.8, 0.6), Vector3(cx + gx, 3.7, z + 0.2), frame, Vector3(0, 0, 45))
		else:
			ModelKit.box(_wall, Vector3(6.0, 34.0, 0.4), Vector3(cx, 5.0, z), mat)
			# Inset armour plates with seams and bolts.
			for py: float in [1.0, 7.5, 14.0]:
				ModelKit.box(_wall, Vector3(4.6, 5.2, 0.2), Vector3(cx, py, z + 0.3), inset)
				for bx: float in [-2.0, 2.0]:
					for by: float in [-2.2, 2.2]:
						ModelKit.box(_wall, Vector3(0.14, 0.14, 0.1), Vector3(cx + bx, py + by, z + 0.45), bolt)
			var feature := i % 8
			if feature == 0:
				_screen(Vector3(cx, 7.5, z + 0.5), Color("5fd3ff"))
			elif feature == 4:
				_screen(Vector3(cx, 7.5, z + 0.5), Color("ffb454"))
			elif feature == 2:
				_fan(Vector3(cx, 14.0, z + 0.5))
			elif feature == 6:
				_generator(Vector3(cx, -1.0, z + 0.9))
		# Rib column with a vertical conduit and a lamp.
		ModelKit.box(_wall, Vector3(0.7, 34.0, 0.9), Vector3(x, 5.0, z + 0.35), rib)
		ModelKit.box(_wall, Vector3(0.18, 34.0, 0.2), Vector3(x + 0.5, 5.0, z + 0.9), pipe)
		ModelKit.box(_wall, Vector3(6.0, 0.6, 0.3), Vector3(cx, -2.2, z + 0.4), stripe)
		if i % 2 == 0:
			var lamp := ModelKit.emissive(WarshipZones.accent_at(zone_x), 1.0)
			_lights.append(lamp)
			ModelKit.box(_wall, Vector3(0.45, 0.2, 0.2), Vector3(x, 11.0, z + 0.9), lamp)
		if i % 6 == 3:
			_beacon(Vector3(x, 18.5, z + 1.0))
		x += 6.0
		i += 1
	# Long pipe runs with flanges and the odd valve wheel.
	for run: Array in [[18.5, 0.3], [19.4, 0.22], [-0.8, 0.26], [12.2, 0.18]]:
		ModelKit.hex_x(_wall, run[1], 640.0, Vector3(80.0, run[0], z + 1.1), pipe, 8)
		var fx := -240.0
		while fx < 400.0:
			ModelKit.hex_x(_wall, run[1] * 1.4, 0.2, Vector3(fx, run[0], z + 1.1), flange, 8)
			fx += 9.0
	for vx in range(-230, 400, 37):
		ModelKit.cylinder(_wall, 0.45, 0.45, 0.08, Vector3(vx, 18.5, z + 1.5), flange, Vector3(90, 0, 0), 10)


## Wall material tinted toward the zone accent (cached per zone).
func _zone_mat(base: StandardMaterial3D, zone_x: float, amount: float = 0.14) -> StandardMaterial3D:
	var key := "%d_%d_%d" % [base.get_instance_id(), WarshipZones.index_at(zone_x), int(amount * 100)]
	if not _zone_mats.has(key):
		var m := base.duplicate() as StandardMaterial3D
		m.albedo_color = WarshipZones.tint(base.albedo_color, zone_x, amount)
		_zone_mats[key] = m
	return _zone_mats[key]


## Pools of zone-coloured light between the back wall and the play plane.
func _build_zone_lights() -> void:
	_zone_lights = ModelKit.group(self, "ZoneLights")
	var x := interior_x.x + 4.0
	while x < interior_x.y:
		for ly: float in [4.0, 15.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(x, ly, -4.0)
			light.light_color = WarshipZones.accent_at(x)
			light.omni_range = 13.0
			light.light_energy = 1.3 if ly < 10.0 else 0.8
			light.omni_attenuation = 1.4
			light.shadow_enabled = false
			_zone_lights.add_child(light)
		x += 11.0


## The level's environment gets its own copy so the interior fog never leaks elsewhere.
func _bind_environment() -> void:
	var found := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if found.is_empty():
		return
	var world_env := found[0] as WorldEnvironment
	if world_env.environment == null:
		return
	_env = world_env.environment.duplicate() as Environment
	world_env.environment = _env
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 33.0
	_env.fog_depth_end = 48.0
	_env.fog_depth_curve = 1.4
	_env.fog_density = 0.85
	_env.fog_sky_affect = 0.0
	_env.fog_enabled = false
	# Scene lights take on each zone's mood while inside.
	for light in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if light.name == &"KeyLight" and _key_light == null:
			_key_light = light
			_key_color = _key_light.light_color
		elif light.name == &"RimLight" and _rim_light == null:
			_rim_light = light
			_rim_color = _rim_light.light_color


func _screen(at: Vector3, color: Color) -> void:
	var frame := ModelKit.toon(Color("1b2640"), 0.3, 0.6, 0.4)
	ModelKit.box(_wall, Vector3(3.6, 2.4, 0.2), at, frame)
	var mat := ModelKit.emissive(color, 1.2)
	_screens.append(mat)
	ModelKit.box(_wall, Vector3(3.2, 2.0, 0.1), at + Vector3(0, 0, 0.12), mat)
	# Readout bars.
	for k in 4:
		ModelKit.box(_wall, Vector3(_rng.randf_range(0.8, 2.6), 0.12, 0.05), at + Vector3(-0.2, 0.6 - k * 0.4, 0.2), ModelKit.emissive(color.lightened(0.4), 2.0))


func _fan(at: Vector3) -> void:
	var frame := ModelKit.toon(Color("1b2640"), 0.3, 0.6, 0.4)
	ModelKit.cylinder(_wall, 2.1, 2.1, 0.3, at, frame, Vector3(90, 0, 0), 16)
	ModelKit.cylinder(_wall, 1.8, 1.8, 0.32, at + Vector3(0, 0, 0.05), ModelKit.toon(Color("05080f"), 0.1, 0.9, 0.1), Vector3(90, 0, 0), 16)
	var rotor := ModelKit.group(_wall, "Fan", at + Vector3(0, 0, 0.3))
	for b in 5:
		ModelKit.box(rotor, Vector3(0.35, 1.7, 0.05), Vector3(0, 0.85, 0), ModelKit.toon(Color("2d3a5a"), 0.4, 0.5, 0.6), Vector3(20, 0, 0)).rotation.z = TAU * b / 5.0
	for b in rotor.get_children():
		var n := b as Node3D
		var ang := n.rotation.z
		n.position = Vector3(-sin(ang) * 0.85, cos(ang) * 0.85, 0)
	_fans.append(rotor)


func _generator(at: Vector3) -> void:
	var body := ModelKit.toon(Color("1a2540"), 0.35, 0.6, 0.5)
	ModelKit.box(_wall, Vector3(4.8, 6.0, 1.4), at, body)
	ModelKit.box(_wall, Vector3(5.0, 0.4, 1.6), at + Vector3(0, 3.1, 0), ModelKit.toon(Color("2a3858"), 0.4, 0.5, 0.6))
	for k in 3:
		var coil := ModelKit.emissive(Color("8f6bff"), 1.5)
		_coils.append(coil)
		ModelKit.cylinder(_wall, 0.45, 0.45, 4.2, at + Vector3(-1.4 + k * 1.4, 0.2, 0.75), coil, Vector3.ZERO, 8)
		ModelKit.cylinder(_wall, 0.6, 0.6, 0.3, at + Vector3(-1.4 + k * 1.4, 2.4, 0.75), body, Vector3.ZERO, 8)
		ModelKit.cylinder(_wall, 0.6, 0.6, 0.3, at + Vector3(-1.4 + k * 1.4, -2.0, 0.75), body, Vector3.ZERO, 8)


func _beacon(at: Vector3) -> void:
	var node := ModelKit.group(_wall, "Beacon", at)
	ModelKit.cylinder(node, 0.3, 0.35, 0.4, Vector3.ZERO, ModelKit.emissive(Palette.DANGER, 2.0), Vector3.ZERO, 8)
	var spin := ModelKit.group(node, "Spin")
	ModelKit.quad(spin, Vector2(6.0, 1.2), Vector3(3.0, 0, 0.1), ModelKit.glow(Palette.DANGER, 0.6, ModelKit.GlowShape.STREAK))
	_beacons.append(spin)


func _build_mid() -> void:
	var dark := ModelKit.toon(Color("0a0f1c"), 0.25, 0.8, 0.3)
	var steel := ModelKit.toon(Color("141d31"), 0.35, 0.7, 0.4)
	var crate := ModelKit.toon(Color("3a2f24"), 0.3, 0.8, 0.2)
	var z := -5.0
	var x := -230.0
	var i := 0
	while x < 420.0:
		match i % 5:
			0:
				# Pillar with cross braces.
				ModelKit.box(_mid, Vector3(1.0, 30.0, 0.8), Vector3(x, 7.0, z), steel)
				ModelKit.box(_mid, Vector3(1.0, 30.0, 0.8), Vector3(x + 3.0, 7.0, z), steel)
				for by in range(-6, 22, 4):
					ModelKit.box(_mid, Vector3(0.18, 4.3, 0.3), Vector3(x + 1.5, by, z), dark, Vector3(0, 0, 45 if by % 8 == 0 else -45))
			1:
				# Hanging cable bundle (sagging segments).
				for k in 6:
					var t := float(k) / 5.0
					ModelKit.box(_mid, Vector3(1.4, 0.16, 0.16), Vector3(x + k * 1.2, 20.5 - sin(t * PI) * 2.2, z), dark, Vector3(0, 0, cos(t * PI) * 28))
			2:
				# Crate stack.
				for k in 3:
					ModelKit.box(_mid, Vector3(1.6, 1.6, 1.6), Vector3(x + k * 1.7, 0.8, z), crate)
				ModelKit.box(_mid, Vector3(1.6, 1.6, 1.6), Vector3(x + 0.85, 2.4, z), crate)
			3:
				# Catwalk with railing.
				ModelKit.box(_mid, Vector3(9.0, 0.25, 1.2), Vector3(x + 4.5, 12.0, z), steel)
				ModelKit.box(_mid, Vector3(9.0, 0.08, 0.1), Vector3(x + 4.5, 13.0, z + 0.5), steel)
				for k in 7:
					ModelKit.box(_mid, Vector3(0.08, 1.0, 0.08), Vector3(x + 0.6 + k * 1.3, 12.5, z + 0.5), steel)
			4:
				ModelKit.hex_x(_mid, 0.35, 7.0, Vector3(x + 3.5, 16.0, z), steel, 8)
				ModelKit.box(_mid, Vector3(0.3, 16.0, 0.3), Vector3(x + 1.0, 8.0, z), dark)
		x += _rng.randf_range(9.0, 15.0)
		i += 1


func _build_foreground() -> void:
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("03060f")
	var x := 25.0
	var i := 0
	while x < level_length * FORE_FACTOR + 60.0:
		var girder := ModelKit.group(_fore, "Girder", Vector3(x, 0, 6.0))
		if i % 2 == 0:
			ModelKit.box(girder, Vector3(1.0, 30.0, 0.5), Vector3.ZERO, dark)
			for y in range(-8, 14, 3):
				ModelKit.box(girder, Vector3(1.6, 0.25, 0.5), Vector3(0, y, 0), dark)
		else:
			# Cable clump hanging from the ceiling (top edge only).
			for k in 4:
				ModelKit.box(girder, Vector3(0.14, 3.0 + k, 0.14), Vector3(k * 0.35, 18.0 - (3.0 + k) * 0.5, 0), dark)
		x += 38.0
		i += 1


func _process(delta: float) -> void:
	_time += delta
	if _camera == null:
		_camera = GameplayCamera.find(get_tree())
		if _camera == null:
			return
	var cx := _camera.global_position.x
	var cy := _camera.global_position.y
	var inside := cx > interior_x.x and cx < interior_x.y and cy < interior_max_y and _camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	_wall.visible = inside
	_mid.visible = inside
	_zone_lights.visible = inside
	if _env:
		_env.fog_enabled = inside
		if inside:
			_env.fog_light_color = WarshipZones.fog_at(cx)
	var target_key := _key_color.lerp(WarshipZones.accent_at(cx), 0.28) if inside else _key_color
	var target_rim := WarshipZones.secondary_at(cx) if inside else _rim_color
	if _key_light:
		_key_light.light_color = _key_light.light_color.lerp(target_key, clampf(delta * 2.0, 0.0, 1.0))
	if _rim_light:
		_rim_light.light_color = _rim_light.light_color.lerp(target_rim, clampf(delta * 2.0, 0.0, 1.0))
	# Locked arenas (mid-boss, boss) keep the fight view clear of foreground girders.
	_fore.visible = inside and cx < fore_cutoff_x and not _camera.is_locked()
	if _sky:
		_sky.position = Vector3(cx, cy * 0.9, 0)
	if not inside:
		return
	_wall.position.x = cx * (1.0 - WALL_FACTOR)
	_mid.position.x = cx * (1.0 - MID_FACTOR)
	_fore.position.x = cx * (1.0 - FORE_FACTOR)
	for i in _lights.size():
		_lights[i].emission_energy_multiplier = 0.4 + 0.9 * maxf(0.0, sin(_time * 2.0 + i * 0.8))
	for i in _screens.size():
		_screens[i].emission_energy_multiplier = 1.0 + 0.25 * sin(_time * 13.0 + i * 3.1) + (0.6 if fmod(_time + i, 4.3) < 0.07 else 0.0)
	for b in _beacons:
		b.rotation.z += delta * 4.0
	for f in _fans:
		f.rotation.z -= delta * 5.0
	for i in _coils.size():
		_coils[i].emission_energy_multiplier = 1.2 + 1.1 * maxf(0.0, sin(_time * 3.0 - i * 0.7))
