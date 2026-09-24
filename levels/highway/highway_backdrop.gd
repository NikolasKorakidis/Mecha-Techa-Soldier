class_name HighwayBackdrop
extends Node3D
## Night megacity seen from an elevated highway, parallaxed against the camera:
##   sky: dusk nebula + the burning warship falling behind (fixed to the camera)
##   far: tower silhouettes with lit windows (slow)   mid: highway pylons + signs (faster)
## Plus the chasing explosion glow at the left edge of the screen.

@export var level_length: float = 1100.0

const FAR_FACTOR := 0.12
const MID_FACTOR := 0.5

var _sky: Node3D
var _far: Node3D
var _mid: Node3D
var _chase: MeshInstance3D
var _camera: GameplayCamera
var _time: float = 0.0


func _ready() -> void:
	_camera = GameplayCamera.find(get_tree())
	_sky = ModelKit.group(self, "Sky")
	_far = ModelKit.group(self, "Far")
	_mid = ModelKit.group(self, "Mid")
	_build_sky()
	_build_far()
	_build_mid()


func _build_sky() -> void:
	var nebula := ShaderMaterial.new()
	nebula.shader = preload("res://art/shaders/nebula.gdshader")
	nebula.set_shader_parameter(&"deep_color", Color("0a0716"))
	nebula.set_shader_parameter(&"teal_color", Color("1a1233"))
	nebula.set_shader_parameter(&"violet_color", Color("3a1840"))
	nebula.set_shader_parameter(&"warm_color", Color("7a2e1a"))
	nebula.set_shader_parameter(&"brightness", 0.9)
	ModelKit.quad(_sky, Vector2(70, 40), Vector3(0, 0, -80), nebula)
	# The warship, burning on the horizon.
	var hull := StandardMaterial3D.new()
	hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull.albedo_color = Color("140c18")
	var wreck := ModelKit.group(_sky, "Warship", Vector3(-10, 5, -70))
	wreck.rotation_degrees.z = -14
	ModelKit.box(wreck, Vector3(22, 3.2, 1), Vector3.ZERO, hull)
	ModelKit.prism(wreck, Vector3(3.2, 6, 1), Vector3(13.8, 0, 0), hull, Vector3(0, 0, -90))
	ModelKit.box(wreck, Vector3(6, 2.2, 1), Vector3(-4, 2.4, 0), hull)
	for x: float in [-7.0, -1.0, 5.0]:
		ModelKit.quad(wreck, Vector2.ONE * 5.0, Vector3(x, 0.5, 0.5), ModelKit.glow(Color(1.0, 0.45, 0.2), 1.2))
	var stars := Starfield.new()
	stars.star_count = 70
	stars.layer_speeds = PackedFloat32Array([0.0])
	stars.extents = Vector2(30, 16)
	stars.depth = -75.0
	stars.star_color = Color(0.9, 0.8, 1.0)
	stars.star_size = 0.05
	stars.stretch_by_speed = false
	_sky.add_child(stars)
	_chase = ModelKit.quad(_sky, Vector2(10, 22), Vector3(-16, 0, 8), ModelKit.glow(Color(1.0, 0.45, 0.15), 1.4))


func _build_far() -> void:
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("0d0b1d")
	var windows := [ModelKit.emissive(Color("ffc46b"), 1.2), ModelKit.emissive(Color("5fd3ff"), 1.2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var span := level_length * FAR_FACTOR + 80.0
	var x := -40.0
	while x < span:
		var w := rng.randf_range(3.0, 6.0)
		var h := rng.randf_range(8.0, 22.0)
		var tower := ModelKit.group(_far, "Tower", Vector3(x, -8.0 + h * 0.5, -40))
		ModelKit.box(tower, Vector3(w, h, 2), Vector3.ZERO, dark)
		for i in rng.randi_range(3, 9):
			ModelKit.box(tower, Vector3(0.3, 0.2, 0.1), Vector3(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(-h * 0.45, h * 0.45), 1.05), windows[i % 2])
		x += w + rng.randf_range(0.5, 3.0)


func _build_mid() -> void:
	var pylon := ModelKit.toon(Color("1c1a33"), 0.25, 0.8, 0.3)
	var span := level_length * MID_FACTOR + 60.0
	var x := -20.0
	var i := 0
	while x < span:
		ModelKit.box(_mid, Vector3(1.4, 20.0, 1.4), Vector3(x, -12.0, -14), pylon)
		ModelKit.box(_mid, Vector3(9.0, 0.8, 1.6), Vector3(x, -2.2, -14), pylon)
		if i % 3 == 0:
			ModelKit.box(_mid, Vector3(4.0, 1.4, 0.3), Vector3(x + 2.0, 6.0, -13.5), pylon)
			ModelKit.box(_mid, Vector3(3.4, 0.2, 0.1), Vector3(x + 2.0, 6.0, -13.3), ModelKit.emissive(Palette.PLAYER_ENERGY if i % 2 == 0 else Color("ff5aa0"), 1.6))
		x += 14.0
		i += 1


func _process(delta: float) -> void:
	_time += delta
	if _camera == null:
		return
	var cx := _camera.global_position.x
	var cy := _camera.global_position.y
	_sky.position = Vector3(cx, cy, 0)
	_far.position = Vector3(cx * (1.0 - FAR_FACTOR), cy * 0.8, 0)
	_mid.position.x = cx * (1.0 - MID_FACTOR)
	var pulse := 1.1 + 0.4 * sin(_time * 7.0) + 0.2 * sin(_time * 17.0)
	(_chase.material_override as ShaderMaterial).set_shader_parameter(&"energy", pulse * ArtStyle.flash_scale())
