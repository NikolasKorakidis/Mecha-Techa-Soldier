@tool
class_name KestrelModel
extends Node3D
## Kestrel interceptor (faces +X). Chunk-tech hero craft: faceted white fuselage, strong nose,
## dark underside, gold cockpit, blue wing blocks with cyan edge accents, a visible echo core,
## and two large rear wing/engine blocks (the mech's future shoulders).
## Built as named part groups so the death breakup can throw recognizable pieces.

const PART_NAMES: Array[String] = ["Nose", "Fuselage", "WingUpper", "WingLower", "EngineUpper", "EngineLower"]

## Overall size multiplier (set by the ship from its tuning).
var base_scale: float = 1.0
var _flames: Array[MeshInstance3D] = []
var _flame_materials: Array[ShaderMaterial] = []
var _nozzles: Array[StandardMaterial3D] = []
var _core_glow: MeshInstance3D
var _dash_streak: MeshInstance3D
var _thrust: float = 0.6
var _health_ratio: float = 1.0
var _time: float = 0.0
var _recoil: float = 0.0
var _sputter: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	_flames.clear()
	_flame_materials.clear()
	_nozzles.clear()
	var white := ModelKit.hull(Palette.PLAYER_PRIMARY)
	var blue := ModelKit.hull(Palette.PLAYER_SECONDARY)
	var blue_dark := ModelKit.hull(Palette.PLAYER_SHADOW, ArtStyle.OUTLINE_THIN)
	var under := ModelKit.hull(Palette.PLAYER_SHADOW.darkened(0.25), ArtStyle.OUTLINE_THIN, 0.3)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var edge := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.2)
	var metal := ModelKit.hull(Color("2b3550"), ArtStyle.OUTLINE_THIN, 0.35)

	# Nose: faceted cone with a blue tip band.
	var nose := ModelKit.group(self, "Nose", Vector3(1.05, 0.0, 0.0))
	ModelKit.cone_x(nose, 0.34, 0.95, Vector3(0.25, 0.0, 0.0), white, 6)
	ModelKit.hex_x(nose, 0.345, 0.14, Vector3(-0.25, 0.0, 0.0), blue, 6)

	# Fuselage: faceted body, dark underside keel, gold cockpit, cyan spine line.
	var body := ModelKit.group(self, "Fuselage")
	ModelKit.hex_x(body, 0.36, 1.7, Vector3(0.05, 0.0, 0.0), white, 6, 0.92)
	ModelKit.box(body, Vector3(1.5, 0.16, 0.5), Vector3(0.0, -0.3, 0.0), under)
	ModelKit.sphere(body, 0.26, Vector3(0.45, 0.24, 0.08), gold, Vector3(1.9, 0.75, 1.0))
	ModelKit.box(body, Vector3(1.1, 0.04, 0.05), Vector3(-0.1, 0.05, 0.37), edge)
	# Echo core on the camera side, violet-cyan so it reads as energy, not armor.
	ModelKit.sphere(body, 0.15, Vector3(-0.3, -0.02, 0.36), ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.0))
	_core_glow = ModelKit.quad(body, Vector2.ONE * 0.9, Vector3(-0.3, -0.02, 0.45), ModelKit.glow(Palette.PLAYER_ENERGY, ArtStyle.GLOW_STANDARD * 0.6))

	# Wing blocks: chunky, swept, white top strip, cyan leading edge, dark underside.
	for side: float in [1.0, -1.0]:
		var wing := ModelKit.group(self, "WingUpper" if side > 0 else "WingLower", Vector3(-0.2, 0.52 * side, 0.0))
		ModelKit.box(wing, Vector3(1.15, 0.34, 1.0), Vector3(-0.1, 0.0, 0.0), blue)
		ModelKit.prism(wing, Vector3(0.34, 0.55, 1.0), Vector3(0.74, 0.0, 0.0), blue, Vector3(0, 0, -90))
		ModelKit.box(wing, Vector3(1.2, 0.07, 1.02), Vector3(-0.1, 0.19 * side, 0.0), white)
		ModelKit.box(wing, Vector3(0.9, 0.05, 0.06), Vector3(0.15, 0.0, 0.52), edge)
		ModelKit.box(wing, Vector3(0.2, 0.36, 1.03), Vector3(0.22, 0.0, 0.0), gold)
		ModelKit.box(wing, Vector3(1.1, 0.08, 0.9), Vector3(-0.12, -0.18 * side, 0.0), blue_dark)

	# Rear wing/engine blocks — large, rounded, future mech shoulders.
	for side: float in [1.0, -1.0]:
		var engine := ModelKit.group(self, "EngineUpper" if side > 0 else "EngineLower", Vector3(-1.0, 0.36 * side, -0.05))
		ModelKit.hex_x(engine, 0.3, 0.8, Vector3.ZERO, blue, 8, 0.9)
		ModelKit.box(engine, Vector3(0.7, 0.12, 0.7), Vector3(0.05, 0.26 * side, 0.0), white)
		ModelKit.prism(engine, Vector3(0.5, 0.45, 0.25), Vector3(-0.1, 0.42 * side, 0.0), blue_dark,
				Vector3(0, 0, 0.0 if side > 0 else 180.0))
		ModelKit.hex_x(engine, 0.24, 0.18, Vector3(-0.48, 0.0, 0.0), metal, 8)
		var nozzle := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
		_nozzles.append(nozzle)
		ModelKit.cylinder(engine, 0.2, 0.2, 0.05, Vector3(-0.58, 0.0, 0.0), nozzle, Vector3(0, 0, 90), 8)
		var flame_material := ModelKit.glow(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.25), 2.2, ModelKit.GlowShape.STREAK)
		_flame_materials.append(flame_material)
		var flame := ModelKit.quad(engine, Vector2(1.0, 0.36), Vector3(-1.1, 0.0, 0.05), flame_material)
		_flames.append(flame)

	_dash_streak = ModelKit.quad(self, Vector2(4.2, 1.5), Vector3(-2.6, 0.0, -0.4),
			ModelKit.glow(Palette.PLAYER_SECONDARY.lerp(Palette.PLAYER_ENERGY, 0.5), 1.3, ModelKit.GlowShape.STREAK))
	_dash_streak.visible = false


## 0 = idle, 1 = cruising forward, >1 = dash burst.
func set_thrust(value: float) -> void:
	_thrust = value


func set_dashing(dashing: bool) -> void:
	if _dash_streak:
		_dash_streak.visible = dashing


## Backward kick + squash on strong shots (0..1).
func recoil(strength: float = 1.0) -> void:
	_recoil = maxf(_recoil, clampf(strength, 0.0, 1.0))


## Below ~25% the engines sputter and smoke.
func set_health_ratio(ratio: float) -> void:
	_health_ratio = ratio


## World-space copies of the major parts for the death breakup.
func make_fragments() -> Array[Node3D]:
	var pieces: Array[Node3D] = []
	for part_name in PART_NAMES:
		var part := get_node_or_null(NodePath(part_name)) as Node3D
		if part == null:
			continue
		var copy := part.duplicate() as Node3D
		copy.transform = part.global_transform
		pieces.append(copy)
	return pieces


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var damaged := _health_ratio <= 0.25
	if damaged:
		# Irregular engine cut-outs.
		_sputter -= delta
		if _sputter <= -0.12:
			_sputter = randf_range(0.2, 0.7)
	var cut := damaged and _sputter < 0.0
	for i in _flames.size():
		var flicker := 0.85 + 0.15 * sin(_time * 55.0 + i * 1.7)
		if damaged:
			flicker *= randf_range(0.5, 1.1)
		var length := (0.55 + _thrust * 0.75) * flicker * (0.25 if cut else 1.0)
		var flame := _flames[i]
		flame.scale = Vector3(length, 0.8 + 0.2 * flicker, 1.0)
		flame.position.x = -0.62 - length * 0.5
		_nozzles[i].emission_energy_multiplier = (0.6 if cut else 2.6)
	if _core_glow:
		(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
				&"energy", ArtStyle.GLOW_STANDARD * (0.5 + 0.15 * sin(_time * 4.0)))
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 7.0)
	position.x = -_recoil * 0.22
	scale = Vector3(1.0 - _recoil * 0.08, 1.0 + _recoil * 0.05, 1.0) * base_scale if not _dash_streak.visible else scale
