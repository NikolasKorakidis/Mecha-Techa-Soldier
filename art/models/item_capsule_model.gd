class_name ItemCapsuleModel
extends Node3D
## Stage 2 item visuals: medical capsule (health), energy cell, Heart Tank and Energy Tank.
## Upright so the silhouette holds while ItemPickup spins it; a pulsing core material and a
## fresnel energy shell on each. Visual only; ItemPickup owns behaviour.

var _core_mat: StandardMaterial3D
var _core_energy: float = 2.2
var _time: float = 0.0


## Health: white capsule, green glass body with glowing crosses.
func build_medkit(color: Color) -> void:
	_begin(color, 1.4, 1.7)
	var white := ModelKit.hull(Palette.PLAYER_PRIMARY, ArtStyle.OUTLINE_THIN)
	var band := ModelKit.toon(Palette.PLAYER_SECONDARY, 0.5, 0.35, 0.4)
	ModelKit.cylinder(self, 0.22, 0.22, 0.46, Vector3.ZERO, _glass(color), Vector3.ZERO, 16)
	for y: float in [0.29, -0.29]:
		ModelKit.sphere(self, 0.23, Vector3(0, y, 0), white, Vector3(1.0, 0.62, 1.0))
		ModelKit.cylinder(self, 0.235, 0.235, 0.06, Vector3(0, y * 0.82, 0), band, Vector3.ZERO, 16)
	# A cross on all four faces so one always shows while the capsule spins.
	for k in 4:
		var face := ModelKit.group(self, "Cross", Vector3.ZERO)
		face.rotation.y = k * PI * 0.5
		ModelKit.box(face, Vector3(0.24, 0.08, 0.04), Vector3(0, 0, 0.215), _core_mat)
		ModelKit.box(face, Vector3(0.08, 0.24, 0.04), Vector3(0, 0, 0.215), _core_mat)
	_shell(color, Vector3(0.44, 0.58, 0.44))


## Energy: hex battery cell with three glowing bands and a gold terminal.
func build_cell(color: Color) -> void:
	_begin(color, 1.3, 1.7)
	var metal := ModelKit.toon(Palette.PLAYER_SECONDARY.darkened(0.45), 0.5, 0.35, 0.5)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.cylinder(self, 0.2, 0.2, 0.56, Vector3.ZERO, metal, Vector3.ZERO, 6)
	for y: float in [-0.16, 0.0, 0.16]:
		ModelKit.cylinder(self, 0.215, 0.215, 0.07, Vector3(0, y, 0), _core_mat, Vector3.ZERO, 6)
	ModelKit.cylinder(self, 0.22, 0.22, 0.05, Vector3(0, -0.3, 0), gold, Vector3.ZERO, 6)
	ModelKit.cylinder(self, 0.08, 0.1, 0.1, Vector3(0, 0.33, 0), gold, Vector3.ZERO, 12)
	_shell(color, Vector3(0.42, 0.56, 0.42))


## Heart Tank: gold-capped glass tank with a glowing heart on both faces.
func build_heart_tank(color: Color) -> void:
	_begin(color, 1.5, 2.6)
	var gold := ModelKit.with_outline(ModelKit.glossy(Palette.PLAYER_GOLD), ArtStyle.OUTLINE_THIN)
	ModelKit.cylinder(self, 0.3, 0.3, 0.72, Vector3.ZERO, _glass(color), Vector3.ZERO, 16)
	for y: float in [0.41, -0.41]:
		ModelKit.cylinder(self, 0.36, 0.36, 0.12, Vector3(0, y, 0), gold, Vector3.ZERO, 16)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		ModelKit.cylinder(self, 0.035, 0.035, 0.74, Vector3(cos(a), 0, sin(a)) * 0.31, gold, Vector3.ZERO, 6)
	for side: float in [1.0, -1.0]:
		var heart := ModelKit.group(self, "Heart", Vector3(0, 0.02, side * 0.27))
		heart.rotation.y = 0.0 if side > 0.0 else PI
		ModelKit.sphere(heart, 0.11, Vector3(-0.075, 0.06, 0), _core_mat)
		ModelKit.sphere(heart, 0.11, Vector3(0.075, 0.06, 0), _core_mat)
		ModelKit.prism(heart, Vector3(0.28, 0.2, 0.1), Vector3(0, -0.07, 0), _core_mat, Vector3(0, 0, 180))
	_shell(color, Vector3(0.58, 0.68, 0.58))


## Energy Tank: white canister, violet glass window, gold caps, "E" on all four faces.
func build_energy_tank(color: Color) -> void:
	_begin(color, 1.0, 2.6)
	var white := ModelKit.hull(Palette.PLAYER_PRIMARY, ArtStyle.OUTLINE_THIN)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.cylinder(self, 0.3, 0.3, 0.7, Vector3.ZERO, white, Vector3.ZERO, 16)
	ModelKit.cylinder(self, 0.31, 0.31, 0.36, Vector3.ZERO, _core_mat, Vector3.ZERO, 16)
	for y: float in [0.38, -0.38]:
		ModelKit.cylinder(self, 0.32, 0.32, 0.08, Vector3(0, y, 0), gold, Vector3.ZERO, 16)
	for k in 4:
		var face := ModelKit.group(self, "Label", Vector3.ZERO)
		face.rotation.y = k * PI * 0.5
		var label := Label3D.new()
		label.text = "E"
		label.font = UiStyle.DISPLAY_FONT
		label.font_size = 64
		label.pixel_size = 0.0055
		label.outline_size = 18
		label.outline_modulate = Color(0.02, 0.04, 0.1)
		label.position = Vector3(0, 0, 0.33)
		face.add_child(label)
	_shell(color, Vector3(0.56, 0.66, 0.56))


func _process(delta: float) -> void:
	if _core_mat == null:
		return
	_time += delta
	_core_mat.emission_energy_multiplier = _core_energy * (1.0 + 0.22 * sin(_time * 4.5))


func _begin(color: Color, core_energy: float, halo: float) -> void:
	ModelKit.clear(self)
	_core_energy = core_energy
	_core_mat = ModelKit.emissive(color, core_energy)
	# Camera-facing: a flat halo would turn edge-on as the item spins.
	ModelKit.quad(self, Vector2.ONE * halo, Vector3.ZERO, ModelKit.glow_billboard(color, 0.9))


## Dark tinted glass lit from inside, in the Kestrel canopy's style.
static func _glass(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.82)
	m.metallic = 0.6
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.55
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	return m


func _shell(color: Color, size: Vector3) -> void:
	var shell := ModelKit.sphere(self, 1.0, Vector3.ZERO, ModelKit.fresnel_shell(color, 1.0, 2.4), size)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
