@tool
class_name SpaceBackdrop
extends Node3D
## Space environment in five parallax layers (far → near), each scrolling at its own speed:
##   1 Distant stars   2 Nebula   3 Orbital structures   4 Midground wreckage   5 Foreground
## plus the planet as the compositional anchor and a few authored background moments.
## Purely visual: nothing here collides, spawns gameplay, or reads gameplay timing.

const NEBULA_SHADER := preload("res://art/shaders/nebula.gdshader")
const PLANET_SHADER := preload("res://art/shaders/gas_giant.gdshader")
const LAYER_NAMES: Array[String] = ["L1_DistantStars", "L2_Nebula", "L3_Structures", "L4_Wreckage", "L5_Foreground"]
const WRAP_X := 26.0

@export_group("Palette")
@export var nebula_deep: Color = Palette.BG_DEEP_NAVY
@export var nebula_teal: Color = Palette.BG_BLUE.lightened(0.08)
@export var nebula_violet: Color = Palette.BG_VIOLET
@export var nebula_warm: Color = Color(0.22, 0.1, 0.2)
@export var nebula_scroll: float = 0.004
# Kept dim: the planet anchors the composition but must never outshine gameplay.
@export var planet_band_dark: Color = Color(0.02, 0.05, 0.15)
@export var planet_band_mid: Color = Color(0.05, 0.13, 0.32)
@export var planet_band_light: Color = Color(0.13, 0.28, 0.5)
@export var planet_atmosphere: Color = Color(0.25, 0.6, 0.9)
@export var planet_cloud: Color = Color(0.36, 0.5, 0.7)
@export var planet_radius: float = 13.0
@export var planet_position: Vector3 = Vector3(12.5, -12.5, -62)
@export var show_ring: bool = true
@export var debris_tint: Color = Color("18203a")
## Unlit silhouettes of distant structures; tint to the stage's shadow hue.
@export var structure_color: Color = Color("0d1628")

@export_group("Motion")
@export var debris_count: int = 9
@export var debris_speed_range: Vector2 = Vector2(2.2, 4.2)
@export var structure_speed: float = 0.45
@export var foreground_interval: float = 11.0
@export var ring_scroll_speed: float = 0.4
## Scripted scenery beats (solar array pass, orbital support, distant blasts, light chase).
@export var authored_moments: bool = true
## Extra depth: distant fleet battle, asteroid belt, sun with light shafts, warship reveal.
@export var cinematic_depth: bool = true
@export var fleet_speed: float = 0.35
## Off when a PerspectiveBackdrop provides the far sky (stars, nebula, planet, orbital structures).
@export var far_layers: bool = true

var _layers: Array[Node3D] = []
var _structures: Array[Node3D] = []
var _wreckage: Array[Node3D] = []
var _wreck_speeds: PackedFloat32Array = []
var _wreck_spins: PackedVector3Array = []
var _foreground: Array[Node3D] = []
var _ring: Node3D
var _time: float = 0.0
var _fg_timer: float = 4.0
var _fg_index: int = 0
var _events: Array[Dictionary] = []
var _chase_lights: Array[StandardMaterial3D] = []
var _blast_timer: float = 3.0
var _rng := RandomNumberGenerator.new()
var _fleet: Array[Node3D] = []
var _asteroids: Array[Node3D] = []
var _asteroid_speeds: PackedFloat32Array = []
var _asteroid_spins: PackedVector3Array = []
var _volley_timer: float = 2.0
var _sun_rays: Array[MeshInstance3D] = []
var _warship: Node3D


func _ready() -> void:
	ModelKit.clear(self)
	_layers.clear()
	_structures.clear()
	_wreckage.clear()
	_foreground.clear()
	_chase_lights.clear()
	_rng.seed = 42
	for layer_name in LAYER_NAMES:
		_layers.append(ModelKit.group(self, layer_name))
	_build_stars(_layers[0])
	_build_nebula(_layers[1])
	_build_planet(_layers[1])
	_build_structures(_layers[2])
	_build_wreckage(_layers[3])
	_build_foreground(_layers[4])
	if cinematic_depth:
		_build_sun(_layers[1])
		_build_fleet(_layers[2])
		_build_asteroids(_layers[3])
	if authored_moments and not Engine.is_editor_hint():
		_schedule_moments()
	if not far_layers:
		for k in 3:
			_layers[k].visible = false


## Debug (visual test room): show/hide a layer by index 0..4.
func toggle_layer(index: int) -> void:
	if index >= 0 and index < _layers.size():
		_layers[index].visible = not _layers[index].visible


func is_layer_visible(index: int) -> bool:
	return _layers[index].visible


# --- Layer 1: distant stars ---------------------------------------------------------

func _build_stars(layer: Node3D) -> void:
	var far := Starfield.new()
	far.star_count = 170
	far.layer_speeds = PackedFloat32Array([0.25, 0.5, 0.9])
	far.extents = Vector2(22, 11)
	far.depth = -70.0
	far.star_color = Color(0.5, 0.6, 0.8)
	far.star_size = 0.055
	far.stretch_by_speed = false
	far.random_seed = 3
	layer.add_child(far)


# --- Layer 2: nebula + planet -------------------------------------------------------

func _build_nebula(layer: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = NEBULA_SHADER
	material.set_shader_parameter(&"deep_color", nebula_deep)
	material.set_shader_parameter(&"teal_color", nebula_teal)
	material.set_shader_parameter(&"violet_color", nebula_violet)
	material.set_shader_parameter(&"warm_color", nebula_warm)
	material.set_shader_parameter(&"scroll_speed", nebula_scroll)
	material.set_shader_parameter(&"brightness", 0.9)
	var nebula := ModelKit.quad(layer, Vector2(52, 30), Vector3(0, 0, -80), material)
	nebula.name = "Nebula"


func _build_planet(layer: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = PLANET_SHADER
	material.set_shader_parameter(&"band_dark", planet_band_dark)
	material.set_shader_parameter(&"band_mid", planet_band_mid)
	material.set_shader_parameter(&"band_light", planet_band_light)
	material.set_shader_parameter(&"atmosphere", planet_atmosphere)
	material.set_shader_parameter(&"cloud_color", planet_cloud)
	material.set_shader_parameter(&"rotation_speed", 0.002)
	var planet := ModelKit.sphere(layer, planet_radius, planet_position, material)
	planet.name = "Planet"
	planet.rotation_degrees = Vector3(0, 0, -14)
	(planet.mesh as SphereMesh).radial_segments = 64
	(planet.mesh as SphereMesh).rings = 32
	# Soft atmospheric halo behind the limb.
	var halo := ModelKit.quad(layer, Vector2.ONE * planet_radius * 2.5, planet_position + Vector3(0, 0, -1.0),
			ModelKit.glow(planet_atmosphere, ArtStyle.GLOW_SUBTLE * 0.35))
	halo.name = "PlanetHalo"


# --- Layer 3: orbital structures (dark silhouettes) ---------------------------------

func _silhouette(color: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	if color.a == 0.0:
		color = structure_color
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func _build_structures(layer: Node3D) -> void:
	if show_ring:
		_build_ring(layer)
	var dark := _silhouette()
	var lights := ModelKit.emissive(Color("ff9f4a"), 1.1)
	# Antenna mast.
	var mast := ModelKit.group(layer, "AntennaMast", Vector3(-8, 4.5, -45))
	ModelKit.box(mast, Vector3(0.35, 7.0, 0.3), Vector3.ZERO, dark)
	for i in 4:
		ModelKit.box(mast, Vector3(2.2 - i * 0.4, 0.14, 0.3), Vector3(0, 2.8 - i * 1.3, 0), dark)
	ModelKit.box(mast, Vector3(0.2, 0.2, 0.2), Vector3(0, 3.6, 0.2), lights)
	_structures.append(mast)
	# Rail gantry with a lit window strip (also the station-light chase).
	var rail := ModelKit.group(layer, "RailGantry", Vector3(10, 6.8, -45))
	ModelKit.box(rail, Vector3(11.0, 0.5, 0.4), Vector3.ZERO, dark)
	ModelKit.box(rail, Vector3(11.0, 0.18, 0.4), Vector3(0, -0.9, 0), dark)
	for i in 8:
		ModelKit.box(rail, Vector3(0.18, 1.0, 0.4), Vector3(-5.0 + i * 1.43, -0.45, 0), dark)
		var lamp_mat := ModelKit.emissive(Color("ffd08a"), 0.3)
		_chase_lights.append(lamp_mat)
		ModelKit.box(rail, Vector3(0.22, 0.22, 0.2), Vector3(-5.0 + i * 1.43, 0.0, 0.3), lamp_mat)
	_structures.append(rail)
	# Broken station section.
	var section := ModelKit.group(layer, "StationSection", Vector3(22, -3.5, -45))
	ModelKit.box(section, Vector3(4.5, 2.4, 1.0), Vector3.ZERO, dark, Vector3(0, 0, 8))
	ModelKit.prism(section, Vector3(2.0, 1.5, 1.0), Vector3(2.8, 0.6, 0), dark, Vector3(0, 0, -70))
	ModelKit.box(section, Vector3(3.0, 0.16, 0.3), Vector3(-0.4, 0.3, 0.55), ModelKit.emissive(Color("6fb8ff"), 0.6))
	_structures.append(section)


func _build_ring(layer: Node3D) -> void:
	# The broken Kharon Ring, far behind everything and seen almost edge-on.
	_ring = Node3D.new()
	_ring.name = "KharonRing"
	_ring.position = Vector3(4, -13, -75)
	_ring.rotation_degrees = Vector3(-9, 0, -6)
	layer.add_child(_ring)
	var hull := _silhouette(Color("0b1324"))
	var lights := ModelKit.emissive(Color("ff9f4a"), 1.0)
	var torus := TorusMesh.new()
	torus.inner_radius = 58.0
	torus.outer_radius = 58.6
	torus.rings = 160
	torus.ring_segments = 6
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = torus
	ring_mesh.material_override = hull
	_ring.add_child(ring_mesh)
	for i in 72:
		if i % 11 == 5:
			continue
		var angle := TAU * float(i) / 72.0
		var pos := Vector3(cos(angle) * 58.3, 0.0, sin(angle) * 58.3)
		var block := ModelKit.box(_ring, Vector3(1.4, 0.9, 2.2), pos, hull, Vector3(0, -rad_to_deg(angle), 0))
		if i % 3 == 0:
			ModelKit.box(block, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.5, 0), lights)


# --- Layer 4: midground wreckage (recognizable pieces) ------------------------------

func _build_wreckage(layer: Node3D) -> void:
	var hull := ModelKit.toon(debris_tint, 0.55, 0.7, 0.3)
	var hull_dark := ModelKit.toon(debris_tint.darkened(0.3), 0.5, 0.7, 0.3)
	var panel_glass := ModelKit.toon(debris_tint.lightened(0.12), 0.7, 0.2, 0.6)
	var builders: Array[Callable] = [_wreck_panel, _wreck_beam, _wreck_solar_fin, _wreck_pipe, _wreck_chunk]
	for i in debris_count:
		var piece := ModelKit.group(layer, "Wreck%d" % i)
		builders[i % builders.size()].call(piece, hull, hull_dark, panel_glass)
		piece.position = Vector3(_rng.randf_range(-WRAP_X, WRAP_X), _rng.randf_range(-8.5, 8.5), _rng.randf_range(-15, -9))
		piece.rotation_degrees = Vector3(_rng.randf_range(0, 360), _rng.randf_range(0, 360), _rng.randf_range(0, 360))
		piece.scale = Vector3.ONE * _rng.randf_range(0.7, 1.4)
		_wreckage.append(piece)
		_wreck_speeds.append(_rng.randf_range(debris_speed_range.x, debris_speed_range.y))
		_wreck_spins.append(Vector3(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18), _rng.randf_range(-25, 25)))


func _wreck_panel(p: Node3D, hull: Material, dark: Material, _glass: Material) -> void:
	ModelKit.box(p, Vector3(1.6, 1.1, 0.12), Vector3.ZERO, hull)
	for x: float in [-0.8, 0.8]:
		ModelKit.box(p, Vector3(0.1, 1.2, 0.2), Vector3(x, 0, 0), dark)
	ModelKit.box(p, Vector3(1.7, 0.1, 0.2), Vector3(0, 0.55, 0), dark)


func _wreck_beam(p: Node3D, hull: Material, dark: Material, _glass: Material) -> void:
	ModelKit.box(p, Vector3(3.2, 0.14, 0.14), Vector3(0, 0.3, 0), hull)
	ModelKit.box(p, Vector3(3.2, 0.14, 0.14), Vector3(0, -0.3, 0), hull)
	for i in 5:
		ModelKit.box(p, Vector3(0.1, 0.75, 0.1), Vector3(-1.4 + i * 0.7, 0, 0), dark, Vector3(0, 0, 35.0 if i % 2 else -35.0))


func _wreck_solar_fin(p: Node3D, _hull: Material, dark: Material, glass: Material) -> void:
	ModelKit.box(p, Vector3(2.4, 1.0, 0.06), Vector3.ZERO, glass)
	for i in 3:
		ModelKit.box(p, Vector3(0.05, 1.02, 0.08), Vector3(-0.6 + i * 0.6, 0, 0), dark)
	ModelKit.box(p, Vector3(0.9, 0.12, 0.12), Vector3(-1.6, 0, 0), dark)


func _wreck_pipe(p: Node3D, hull: Material, dark: Material, _glass: Material) -> void:
	ModelKit.hex_x(p, 0.22, 2.4, Vector3.ZERO, hull, 8)
	for x: float in [-1.2, 0.0, 1.2]:
		ModelKit.hex_x(p, 0.3, 0.14, Vector3(x, 0, 0), dark, 8)


func _wreck_chunk(p: Node3D, hull: Material, dark: Material, _glass: Material) -> void:
	ModelKit.box(p, Vector3(1.2, 0.9, 0.8), Vector3.ZERO, hull)
	ModelKit.prism(p, Vector3(0.8, 0.6, 0.8), Vector3(0.9, 0.1, 0), dark, Vector3(0, 0, -70))
	ModelKit.box(p, Vector3(0.9, 0.12, 0.05), Vector3(0, 0.2, 0.42), ModelKit.emissive(Color("6fb8ff"), 0.4))


# --- Layer 5: foreground silhouettes ------------------------------------------------

func _build_foreground(layer: Node3D) -> void:
	var dark := _silhouette(Color("03060f"))
	# Two large shapes that sweep along the top or bottom edge, one at a time.
	var girder := ModelKit.group(layer, "ForeGirder")
	ModelKit.box(girder, Vector3(9.0, 1.4, 0.6), Vector3.ZERO, dark)
	for i in 6:
		ModelKit.box(girder, Vector3(0.3, 2.2, 0.6), Vector3(-3.8 + i * 1.5, 0.6, 0), dark, Vector3(0, 0, 30.0 if i % 2 else -30.0))
	var hulk := ModelKit.group(layer, "ForeHulk")
	ModelKit.box(hulk, Vector3(6.0, 2.6, 1.0), Vector3.ZERO, dark, Vector3(0, 0, -6))
	ModelKit.prism(hulk, Vector3(3.0, 2.0, 1.0), Vector3(-4.0, 0.3, 0), dark, Vector3(0, 0, 80))
	for fg in [girder, hulk]:
		fg.position = Vector3(99, 0, 8)
		fg.visible = false
		_foreground.append(fg)
	# Sparse fast dust for speed.
	var dust := Starfield.new()
	dust.star_count = 14
	dust.layer_speeds = PackedFloat32Array([16.0, 22.0])
	dust.extents = Vector2(22, 10)
	dust.depth = 6.0
	dust.star_color = Color(0.32, 0.42, 0.58)
	dust.star_size = 0.05
	dust.random_seed = 11
	layer.add_child(dust)


# --- Cinematic depth ---------------------------------------------------------------------

func _build_sun(layer: Node3D) -> void:
	var sun := ModelKit.group(layer, "Sun", Vector3(-19, 9.5, -84))
	ModelKit.sphere(sun, 1.1, Vector3.ZERO, ModelKit.emissive(Color(1.0, 0.93, 0.8), 4.0))
	ModelKit.quad(sun, Vector2.ONE * 9.0, Vector3(0, 0, 0.5), ModelKit.glow(Color(1.0, 0.8, 0.55), 0.9 * ArtStyle.flash_scale()))
	ModelKit.quad(sun, Vector2.ONE * 22.0, Vector3(0, 0, 0.4), ModelKit.glow(Color(1.0, 0.55, 0.35), 0.25))
	# Anamorphic streak + god rays fanning toward the play area.
	ModelKit.quad(sun, Vector2(40.0, 0.7), Vector3(0, 0, 0.6), ModelKit.glow(Color(0.7, 0.85, 1.0), 0.5, ModelKit.GlowShape.RADIAL))
	for k in 5:
		var ray := ModelKit.quad(sun, Vector2(38.0, 3.5 + k), Vector3(0, 0, 0.3), ModelKit.glow(Color(1.0, 0.85, 0.6), 0.06, ModelKit.GlowShape.STREAK))
		ray.rotation.z = deg_to_rad(-18.0 - k * 9.0) + PI
		ray.position = Vector3(cos(ray.rotation.z) * -19.0, sin(ray.rotation.z) * -19.0, 0.3)
		_sun_rays.append(ray)


func _build_fleet(layer: Node3D) -> void:
	var hull := _silhouette(Color("0e1527"))
	var hull_light := _silhouette(Color("141d33"))
	var windows := ModelKit.emissive(Color("ffd9a0"), 0.7)
	var engine := Color("7fc8ff")
	for k in 3:
		var ship := ModelKit.group(layer, "CapitalShip%d" % k, Vector3(-18.0 + k * 19.0, [8.6, -8.2, 6.4][k], -40.0 - k * 5.0))
		var length := 14.0 - k * 2.5
		ModelKit.box(ship, Vector3(length, 1.3, 1.0), Vector3.ZERO, hull)
		ModelKit.prism(ship, Vector3(1.3, 4.0, 1.0), Vector3(-length * 0.5 - 1.9, 0, 0), hull, Vector3(0, 0, 90))
		ModelKit.box(ship, Vector3(length * 0.7, 0.6, 1.0), Vector3(length * 0.1, -0.9, 0), hull_light)
		ModelKit.box(ship, Vector3(2.0, 1.6, 1.0), Vector3(length * 0.3, 1.3, 0), hull)
		ModelKit.box(ship, Vector3(3.2, 0.5, 1.0), Vector3(length * 0.3, 2.3, 0), hull_light)
		for w in int(length):
			if w % 3 != 1:
				ModelKit.box(ship, Vector3(0.35, 0.1, 0.1), Vector3(-length * 0.5 + 0.6 + w, 0.2, 0.55), windows)
		for e in 2:
			ModelKit.quad(ship, Vector2(2.6, 0.9), Vector3(length * 0.5 + 1.2, 0.3 - e * 0.7, 0.6), ModelKit.glow(engine, 0.9, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
		ship.scale = Vector3.ONE * (0.6 - k * 0.1)
		_fleet.append(ship)


func _build_asteroids(layer: Node3D) -> void:
	var rock := ModelKit.toon(Color("1d1b26"), 0.3, 0.95, 0.05)
	var rock_dark := ModelKit.toon(Color("131219"), 0.25, 0.95, 0.05)
	for k in 8:
		var a := ModelKit.group(layer, "Asteroid%d" % k)
		var r := _rng.randf_range(0.45, 1.3)
		var m := ModelKit.sphere(a, r, Vector3.ZERO, rock if k % 3 else rock_dark,
				Vector3(_rng.randf_range(0.8, 1.4), _rng.randf_range(0.6, 1.0), _rng.randf_range(0.7, 1.2)))
		(m.mesh as SphereMesh).radial_segments = 7
		(m.mesh as SphereMesh).rings = 4
		for c in 3:
			ModelKit.sphere(a, r * 0.35, Vector3(_rng.randf_range(-r, r) * 0.6, _rng.randf_range(-r, r) * 0.5, r * 0.5), rock_dark, Vector3(1, 1, 0.5))
		a.position = Vector3(_rng.randf_range(-WRAP_X, WRAP_X), _rng.randf_range(-9.0, 9.0), _rng.randf_range(-30.0, -19.0))
		_asteroids.append(a)
		_asteroid_speeds.append(_rng.randf_range(1.0, 2.2))
		_asteroid_spins.append(Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-30, 30), _rng.randf_range(-15, 15)))


## A turbolaser exchange between two capital ships, with a flak burst at the target.
func _fleet_volley() -> void:
	if _fleet.size() < 2:
		return
	var a := _fleet[_rng.randi() % _fleet.size()]
	var b := _fleet[(_fleet.find(a) + 1 + _rng.randi() % (_fleet.size() - 1)) % _fleet.size()]
	var from := a.position + Vector3(0, 0.8, 0.8)
	var to := b.position + Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-0.5, 1.0), 0.8)
	var color := Color(0.4, 1.0, 0.5) if _rng.randf() < 0.5 else Color(1.0, 0.35, 0.3)
	for k in 3:
		var bolt := ModelKit.quad(_layers[2], Vector2(2.6, 0.22), from, ModelKit.glow(color, 1.4, ModelKit.GlowShape.STREAK))
		bolt.rotation.z = atan2(to.y - from.y, to.x - from.x)
		var tween := create_tween()
		tween.tween_interval(k * 0.12)
		tween.tween_property(bolt, "position", to, 0.5)
		tween.tween_callback(bolt.queue_free)
	var flash := ModelKit.quad(_layers[2], Vector2.ONE * 1.8, to, ModelKit.glow(Color(1.0, 0.7, 0.35), 0.0))
	var ft := create_tween()
	ft.tween_interval(0.55)
	ft.tween_property(flash.material_override, "shader_parameter/energy", 1.2 * ArtStyle.flash_scale(), 0.05)
	ft.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.4)
	ft.parallel().tween_property(flash.material_override, "shader_parameter/energy", 0.0, 0.45)
	ft.tween_callback(flash.queue_free)


## The enemy warship looms in from the right late in the stage — the next destination.
func reveal_warship() -> void:
	if _warship:
		return
	var hull := _silhouette(Color("0e1526"))
	var edge := _silhouette(Color("1a2440"))
	_warship = ModelKit.group(_layers[2], "WarshipReveal", Vector3(46, -8.5, -36))
	_warship.scale = Vector3.ONE * 0.7
	ModelKit.box(_warship, Vector3(30.0, 3.2, 1.0), Vector3.ZERO, hull)
	ModelKit.prism(_warship, Vector3(3.2, 8.0, 1.0), Vector3(-19.0, 0, 0), hull, Vector3(0, 0, 90))
	ModelKit.box(_warship, Vector3(22.0, 1.0, 1.0), Vector3(2.0, -2.0, 0), edge)
	ModelKit.box(_warship, Vector3(6.0, 3.0, 1.0), Vector3(6.0, 3.0, 0), hull)
	ModelKit.box(_warship, Vector3(4.0, 2.0, 1.0), Vector3(6.0, 5.4, 0), edge)
	for w in 26:
		ModelKit.box(_warship, Vector3(0.5, 0.14, 0.1), Vector3(-13.0 + w, 0.6, 0.55), ModelKit.emissive(Color("ff9f4a"), 0.8))
	for e in 3:
		ModelKit.quad(_warship, Vector2(6.0, 1.6), Vector3(18.0, 1.0 - e * 1.2, 0.6), ModelKit.glow(Color("ff5a4e"), 1.2, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
	var tween := create_tween()
	tween.tween_property(_warship, "position:x", 16.0, 40.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Campaign transitions: drop the wreckage/foreground layers once the ship leaves the battle.
func set_battle_layers_visible(enabled: bool) -> void:
	if _layers.size() < 5:
		return
	_layers[3].visible = enabled
	_layers[4].visible = enabled


# --- Authored moments -----------------------------------------------------------------

func _schedule_moments() -> void:
	_events = [
		{"t": 14.0, "kind": "solar_array"},
		{"t": 32.0, "kind": "light_chase"},
		{"t": 46.0, "kind": "orbital_support"},
		{"t": 60.0, "kind": "warship_reveal"},
		{"t": 70.0, "kind": "solar_array"},
	]


func _run_moment(kind: String) -> void:
	match kind:
		"solar_array":
			# A big broken solar array drifts past in the midground.
			var array := ModelKit.group(_layers[3], "SolarArrayPass", Vector3(30, 5.5, -12))
			var glass := ModelKit.toon(debris_tint.lightened(0.12), 0.8, 0.2, 0.6)
			var frame := ModelKit.toon(debris_tint.darkened(0.2), 0.5)
			for i in 5:
				ModelKit.box(array, Vector3(1.8, 3.2, 0.08), Vector3(i * 2.0 - 4.0, 0, 0), glass, Vector3(0, 0, -8.0 if i == 3 else 0.0))
			ModelKit.box(array, Vector3(10.5, 0.2, 0.2), Vector3(0, -1.7, 0.05), frame)
			array.rotation_degrees = Vector3(18, 0, -10)
			_moving_prop(array, 3.2, 70.0)
		"orbital_support":
			# A tall support column in front of the play plane — narrow and quick.
			var support := ModelKit.group(_layers[4], "OrbitalSupport", Vector3(28, 0, 7))
			var mat := _silhouette(Color("03060f"))
			ModelKit.box(support, Vector3(1.1, 26.0, 0.6), Vector3.ZERO, mat)
			for y in range(-10, 11, 4):
				ModelKit.box(support, Vector3(1.8, 0.3, 0.6), Vector3(0, y, 0), mat)
			_moving_prop(support, 26.0, 60.0)
		"light_chase":
			_chase_lights_on(true)
		"warship_reveal":
			if cinematic_depth:
				reveal_warship()


func _moving_prop(node: Node3D, speed: float, distance: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "position:x", node.position.x - distance, distance / speed)
	tween.tween_callback(node.queue_free)


func _chase_lights_on(enabled: bool) -> void:
	for mat in _chase_lights:
		mat.emission_energy_multiplier = 0.3
	if not enabled:
		return
	var tween := create_tween().set_loops(4)
	for mat in _chase_lights:
		tween.tween_property(mat, "emission_energy_multiplier", 2.4, 0.08)
		tween.tween_property(mat, "emission_energy_multiplier", 0.3, 0.12)


func _distant_blast() -> void:
	var at := Vector3(_rng.randf_range(-16, 16), _rng.randf_range(2, 8), -52)
	var flash := ModelKit.quad(_layers[2], Vector2.ONE * _rng.randf_range(1.2, 2.2), at,
			ModelKit.glow(Color(1.0, 0.62, 0.25), 0.7 * ArtStyle.flash_scale()))
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.5)
	tween.tween_property(flash.material_override, "shader_parameter/energy", 0.0, 0.6)
	tween.chain().tween_callback(flash.queue_free)


# --- Motion -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if _ring:
		_ring.rotate_object_local(Vector3.UP, deg_to_rad(ring_scroll_speed) * delta)
	for s in _structures:
		s.position.x -= structure_speed * delta
		if s.position.x < -WRAP_X - 6.0:
			s.position.x += WRAP_X * 2.0 + 12.0
	for i in _wreckage.size():
		var piece := _wreckage[i]
		piece.position.x -= _wreck_speeds[i] * delta
		piece.rotation_degrees += _wreck_spins[i] * delta
		if piece.position.x < -WRAP_X:
			piece.position.x += WRAP_X * 2.0
	_update_foreground(delta)
	for ship in _fleet:
		ship.position.x -= fleet_speed * delta
		if ship.position.x < -WRAP_X - 14.0:
			ship.position.x += WRAP_X * 2.0 + 28.0
	for i in _asteroids.size():
		var a := _asteroids[i]
		a.position.x -= _asteroid_speeds[i] * delta
		a.rotation_degrees += _asteroid_spins[i] * delta
		if a.position.x < -WRAP_X - 3.0:
			a.position.x += WRAP_X * 2.0 + 6.0
	for i in _sun_rays.size():
		(_sun_rays[i].material_override as ShaderMaterial).set_shader_parameter(&"energy", 0.05 + 0.03 * sin(_time * 0.7 + i * 1.3))
	if cinematic_depth:
		_volley_timer -= delta
		if _volley_timer <= 0.0:
			_volley_timer = _rng.randf_range(2.5, 5.0)
			_fleet_volley()
	if authored_moments:
		while not _events.is_empty() and _time >= float(_events[0]["t"]):
			_run_moment(_events.pop_front()["kind"])
		_blast_timer -= delta
		if _blast_timer <= 0.0:
			_blast_timer = _rng.randf_range(6.0, 11.0)
			_distant_blast()


func _update_foreground(delta: float) -> void:
	for fg in _foreground:
		if fg.visible:
			fg.position.x -= 15.0 * delta
			if fg.position.x < -WRAP_X - 6.0:
				fg.visible = false
	_fg_timer -= delta
	if _fg_timer > 0.0:
		return
	_fg_timer = foreground_interval
	var fg := _foreground[_fg_index % _foreground.size()]
	_fg_index += 1
	# Only along the very top or bottom edge so gameplay stays readable.
	var top := _fg_index % 2 == 0
	fg.position = Vector3(WRAP_X + 6.0, 10.2 if top else -10.2, 8)
	fg.visible = true
