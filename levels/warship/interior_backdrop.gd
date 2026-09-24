class_name InteriorBackdrop
extends Node3D
## Warship interior, parallaxed against the moving camera:
##   far: space + planet seen through the windows (moves with the camera)
##   back wall: ribs, window frames, pipes, warning lights (half speed)
##   foreground: occasional dark girders in front of the play plane (faster than the world)

@export var level_length: float = 330.0
@export var ceiling_y: float = 12.0
@export var floor_y: float = -6.0
## Camera X beyond which foreground girders are hidden (boss arena).
@export var fore_cutoff_x: float = 285.0

var _far: Node3D
var _wall: Node3D
var _fore: Node3D
var _camera: GameplayCamera
var _lights: Array[StandardMaterial3D] = []
var _time: float = 0.0

const WALL_FACTOR := 0.55
const FORE_FACTOR := 1.25


func _ready() -> void:
	_camera = GameplayCamera.find(get_tree())
	_far = ModelKit.group(self, "Far")
	_wall = ModelKit.group(self, "BackWall")
	_fore = ModelKit.group(self, "Foreground")
	_build_far()
	_build_wall()
	_build_foreground()


func _build_far() -> void:
	var nebula := ShaderMaterial.new()
	nebula.shader = preload("res://art/shaders/nebula.gdshader")
	nebula.set_shader_parameter(&"deep_color", Palette.BG_DEEP_NAVY)
	nebula.set_shader_parameter(&"teal_color", Palette.BG_BLUE)
	nebula.set_shader_parameter(&"violet_color", Palette.BG_VIOLET)
	nebula.set_shader_parameter(&"brightness", 0.8)
	ModelKit.quad(_far, Vector2(60, 34), Vector3(0, 0, -70), nebula)
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = preload("res://art/shaders/gas_giant.gdshader")
	planet_mat.set_shader_parameter(&"band_dark", Color(0.02, 0.05, 0.15))
	planet_mat.set_shader_parameter(&"band_mid", Color(0.05, 0.13, 0.32))
	planet_mat.set_shader_parameter(&"band_light", Color(0.13, 0.28, 0.5))
	ModelKit.sphere(_far, 16.0, Vector3(6, -20, -60), planet_mat)
	var stars := Starfield.new()
	stars.star_count = 120
	stars.layer_speeds = PackedFloat32Array([0.0, 0.0])
	stars.extents = Vector2(28, 16)
	stars.depth = -65.0
	stars.star_color = Color(0.55, 0.65, 0.85)
	stars.star_size = 0.06
	stars.stretch_by_speed = false
	_far.add_child(stars)


func _build_wall() -> void:
	var wall := ModelKit.toon(Color("0a0f1c"), 0.15, 0.9, 0.2)
	var rib := ModelKit.toon(Color("111827"), 0.2, 0.8, 0.3)
	var frame := ModelKit.toon(Color("1a2338"), 0.25, 0.7, 0.3)
	var pipe := ModelKit.toon(Color("1b2436"), 0.3, 0.6, 0.4)
	var span := level_length * WALL_FACTOR + 60.0
	var z := -9.0
	var x := -20.0
	var i := 0
	while x < span:
		# Solid panel, then a window bay every third section.
		var window := i % 3 == 1
		if window:
			ModelKit.box(_wall, Vector3(6.0, 3.0, 0.4), Vector3(x + 3.0, ceiling_y * 0.6 - 4.0, z), wall)
			ModelKit.box(_wall, Vector3(6.0, 6.0, 0.4), Vector3(x + 3.0, floor_y + 5.0, z), wall)
			ModelKit.box(_wall, Vector3(6.2, 0.35, 0.6), Vector3(x + 3.0, 2.2, z + 0.1), frame)
			ModelKit.box(_wall, Vector3(6.2, 0.35, 0.6), Vector3(x + 3.0, 7.9, z + 0.1), frame)
			ModelKit.box(_wall, Vector3(0.25, 5.6, 0.5), Vector3(x + 3.0, 5.05, z + 0.1), frame)
		else:
			ModelKit.box(_wall, Vector3(6.0, 22.0, 0.4), Vector3(x + 3.0, 2.0, z), wall)
			ModelKit.box(_wall, Vector3(3.0, 0.8, 0.3), Vector3(x + 3.0, 4.0, z + 0.3), frame)
			if i % 2 == 0:
				var lamp := ModelKit.emissive(Color("ff9f4a"), 1.0)
				_lights.append(lamp)
				ModelKit.box(_wall, Vector3(0.5, 0.25, 0.2), Vector3(x + 3.0, 4.0, z + 0.5), lamp)
		ModelKit.box(_wall, Vector3(0.6, 22.0, 0.8), Vector3(x, 2.0, z + 0.3), rib)
		x += 6.0
		i += 1
	# Long pipe runs.
	for y: float in [9.5, 10.3, -1.2]:
		ModelKit.hex_x(_wall, 0.22, span + 20.0, Vector3(span * 0.5 - 20.0, y, z + 0.9), pipe, 8)


func _build_foreground() -> void:
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("03060f")
	var span := level_length * FORE_FACTOR + 60.0
	var x := 25.0
	while x < span:
		var girder := ModelKit.group(_fore, "Girder", Vector3(x, 0, 6.0))
		ModelKit.box(girder, Vector3(1.0, 30.0, 0.5), Vector3.ZERO, dark)
		for y in range(-8, 14, 3):
			ModelKit.box(girder, Vector3(1.6, 0.25, 0.5), Vector3(0, y, 0), dark)
		x += 38.0


func _process(delta: float) -> void:
	_time += delta
	if _camera == null:
		return
	var cx := _camera.global_position.x
	var cy := _camera.global_position.y
	_far.position = Vector3(cx, cy * 0.9, 0)
	_wall.position.x = cx * (1.0 - WALL_FACTOR)
	_fore.position.x = cx * (1.0 - FORE_FACTOR)
	# Keep the boss arena unobstructed.
	_fore.visible = cx < fore_cutoff_x
	for i in _lights.size():
		_lights[i].emission_energy_multiplier = 0.4 + 0.9 * maxf(0.0, sin(_time * 2.0 + i * 0.8))
