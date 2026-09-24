@tool
class_name SpaceBackdrop
extends Node3D
## Orbital Riptide backdrop in parallax layers (far → near):
## nebula (drifts), gas giant (near-static), Kharon Ring arc (slow), wreckage (fast).
## Purely visual; nothing here collides or drives gameplay timing.

const NEBULA_SHADER := preload("res://art/shaders/nebula.gdshader")
const PLANET_SHADER := preload("res://art/shaders/gas_giant.gdshader")

@export_group("Palette")
@export var nebula_deep: Color = Color(0.012, 0.035, 0.07)
@export var nebula_teal: Color = Color(0.03, 0.2, 0.26)
@export var nebula_violet: Color = Color(0.16, 0.07, 0.26)
@export var nebula_warm: Color = Color(0.5, 0.22, 0.12)
@export var nebula_scroll: float = 0.006
@export var planet_band_dark: Color = Color(0.05, 0.13, 0.36)
@export var planet_band_mid: Color = Color(0.12, 0.32, 0.66)
@export var planet_band_light: Color = Color(0.36, 0.64, 0.86)
@export var planet_atmosphere: Color = Color(0.45, 0.85, 1.0)
@export var planet_radius: float = 17.0
@export var planet_position: Vector3 = Vector3(6, -25, -60)
@export var show_ring: bool = true
@export var debris_tint: Color = Color("151c2d")

@export_group("Motion")
@export var debris_count: int = 10
@export var debris_speed_range: Vector2 = Vector2(2.5, 6.0)
@export var ring_scroll_speed: float = 0.4

var _debris: Array[MeshInstance3D] = []
var _debris_speeds: PackedFloat32Array = []
var _debris_spins: PackedVector3Array = []
var _ring: Node3D


func _ready() -> void:
	ModelKit.clear(self)
	_debris.clear()
	_build_nebula()
	_build_planet()
	if show_ring:
		_build_ring()
	_build_debris()


func _build_nebula() -> void:
	var material := ShaderMaterial.new()
	material.shader = NEBULA_SHADER
	material.set_shader_parameter(&"deep_color", nebula_deep)
	material.set_shader_parameter(&"teal_color", nebula_teal)
	material.set_shader_parameter(&"violet_color", nebula_violet)
	material.set_shader_parameter(&"warm_color", nebula_warm)
	material.set_shader_parameter(&"scroll_speed", nebula_scroll)
	var nebula := ModelKit.quad(self, Vector2(48, 27), Vector3(0, 0, -80), material)
	nebula.name = "Nebula"


func _build_planet() -> void:
	var material := ShaderMaterial.new()
	material.shader = PLANET_SHADER
	material.set_shader_parameter(&"band_dark", planet_band_dark)
	material.set_shader_parameter(&"band_mid", planet_band_mid)
	material.set_shader_parameter(&"band_light", planet_band_light)
	material.set_shader_parameter(&"atmosphere", planet_atmosphere)
	var planet := ModelKit.sphere(self, planet_radius, planet_position, material)
	planet.name = "GasGiant"
	planet.rotation_degrees = Vector3(0, 0, -12)
	(planet.mesh as SphereMesh).radial_segments = 48
	(planet.mesh as SphereMesh).rings = 24


func _build_ring() -> void:
	# The broken Kharon Ring, far behind the planet and seen almost edge-on: a thin dark
	# arc with sparse lights. Low contrast on purpose — it is scenery, not terrain.
	_ring = Node3D.new()
	_ring.name = "KharonRing"
	_ring.position = Vector3(4, -13, -75)
	_ring.rotation_degrees = Vector3(-9, 0, -6)
	add_child(_ring)
	# Unlit silhouette so scene lights never pull it forward.
	var hull := StandardMaterial3D.new()
	hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull.albedo_color = Color("0e1526")
	var lights := ModelKit.emissive(Color("ff9f4a"), 1.2)
	var torus := TorusMesh.new()
	torus.inner_radius = 58.0
	torus.outer_radius = 58.7
	torus.rings = 160
	torus.ring_segments = 6
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = torus
	ring_mesh.material_override = hull
	_ring.add_child(ring_mesh)
	for i in 72:
		if i % 11 == 5:
			continue  # Broken sections.
		var angle := TAU * float(i) / 72.0
		var pos := Vector3(cos(angle) * 58.35, 0.0, sin(angle) * 58.35)
		var block := ModelKit.box(_ring, Vector3(1.4, 0.9, 2.2), pos, hull, Vector3(0, -rad_to_deg(angle), 0))
		if i % 3 == 0:
			ModelKit.box(block, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.5, 0), lights)


func _build_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var dark := ModelKit.toon(debris_tint, 0.7, 0.7, 0.3)
	var rust := ModelKit.toon(Color("2a2330"), 0.7, 0.7, 0.3)
	for i in debris_count:
		var size := Vector3(rng.randf_range(0.4, 1.6), rng.randf_range(0.3, 1.0), rng.randf_range(0.3, 1.0))
		var pos := Vector3(rng.randf_range(-20, 20), rng.randf_range(-10, 10), rng.randf_range(-14, -8))
		var chunk := ModelKit.box(self, size, pos, dark if i % 3 else rust,
				Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360), rng.randf_range(0, 360)))
		_debris.append(chunk)
		_debris_speeds.append(rng.randf_range(debris_speed_range.x, debris_speed_range.y))
		_debris_spins.append(Vector3(rng.randf_range(-40, 40), rng.randf_range(-40, 40), rng.randf_range(-40, 40)))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _ring:
		_ring.rotate_object_local(Vector3.UP, deg_to_rad(ring_scroll_speed) * delta)
	for i in _debris.size():
		var chunk := _debris[i]
		chunk.position.x -= _debris_speeds[i] * delta
		chunk.rotation_degrees += _debris_spins[i] * delta
		if chunk.position.x < -22.0:
			chunk.position.x += 44.0
