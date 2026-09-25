@tool
class_name KestrelModel
extends Node3D
## Kestrel interceptor (faces +X, ~3.6 units long). Hero craft built for a 2.5D three-quarter
## view: everything hangs off a rig tilted toward the camera, so the swept delta wings, canopy
## and dorsal armour read even from the side-view gameplay camera.
##   long faceted nose with a red-tipped probe, glass canopy in a gold frame, forward canards,
##   white armoured fuselage with side intakes and energy trim, the violet-cyan echo core,
##   swept delta wings with wingtip pods (blinking nav lights), twin nacelles with petal
##   nozzles and flames, canted twin tail fins and a ventral fin. White / blue / gold, red accents.
## Built as named part groups so the death breakup throws recognisable pieces.

const PART_NAMES: Array[String] = ["Nose", "Fuselage", "WingLeft", "WingRight", "EngineLeft", "EngineRight", "Tail"]
## Rig attitude: roll toward the camera shows the top; a little yaw shows the nose side.
const RIG_ROLL := 0.38
const RIG_YAW := -0.22

const WHITE := Color("e8eef8")
const BLUE := Color("2a62e6")
const DEEP := Color("15296e")
const METAL := Color("262e46")
const RED := Color("e0344a")

## Overall size multiplier (set by the ship from its tuning).
var base_scale: float = 1.0
var _rig: Node3D
var _flames: Array[MeshInstance3D] = []
var _flame_materials: Array[ShaderMaterial] = []
var _nozzles: Array[StandardMaterial3D] = []
var _nav_lights: Array[StandardMaterial3D] = []
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
	_nav_lights.clear()
	var t := ArtStyle.OUTLINE_THIN
	var white := ModelKit.hull(WHITE, t, 0.6)
	var blue := ModelKit.hull(BLUE, t, 0.55)
	var deep := ModelKit.hull(DEEP, t, 0.45)
	var metal := ModelKit.hull(METAL, t, 0.35)
	var red := ModelKit.hull(RED, t, 0.5)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, t)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.4)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.1, 0.16)
	glass.metallic = 0.7
	glass.roughness = 0.08
	glass.emission_enabled = true
	glass.emission = Color(0.15, 0.45, 0.65)
	glass.emission_energy_multiplier = 0.45
	glass.rim_enabled = true
	glass.rim = 0.8
	glass.rim_tint = 0.2
	ModelKit.with_outline(glass, t)

	_rig = ModelKit.group(self, "Rig")
	_rig.rotation = Vector3(RIG_ROLL, RIG_YAW, 0.0)

	# Nose: long faceted spike, blue collar band, red tip stripe and a pitot probe.
	var nose := ModelKit.group(_rig, "Nose", Vector3(1.0, 0.0, 0.0))
	ModelKit.cone_x(nose, 0.3, 1.1, Vector3(0.55, 0.0, 0.0), white, 8)
	ModelKit.hex_x(nose, 0.31, 0.12, Vector3(0.0, 0.0, 0.0), blue, 8)
	ModelKit.hex_x(nose, 0.12, 0.08, Vector3(0.84, 0.0, 0.0), red, 8)
	ModelKit.cylinder(nose, 0.018, 0.018, 0.5, Vector3(1.2, 0.0, 0.0), metal, Vector3(0, 0, 90), 6)
	ModelKit.box(nose, Vector3(0.55, 0.03, 0.02), Vector3(0.35, -0.12, 0.2), energy)

	# Fuselage: armoured body with dorsal spine, side intakes, belly keel, panel seams, trim.
	var body := ModelKit.group(_rig, "Fuselage")
	ModelKit.hex_x(body, 0.34, 1.9, Vector3(-0.05, 0.0, 0.0), white, 8, 0.9)
	ModelKit.box(body, Vector3(1.5, 0.12, 0.22), Vector3(-0.2, 0.3, 0.0), blue)
	ModelKit.box(body, Vector3(1.7, 0.14, 0.44), Vector3(-0.15, -0.28, 0.0), deep)
	for side: float in [1.0, -1.0]:
		ModelKit.box(body, Vector3(0.5, 0.22, 0.12), Vector3(0.25, -0.06, 0.34 * side), metal)
		ModelKit.box(body, Vector3(0.06, 0.18, 0.1), Vector3(0.5, -0.06, 0.36 * side), ModelKit.emissive(Palette.PLAYER_ENERGY.darkened(0.3), 1.2))
		ModelKit.box(body, Vector3(1.3, 0.025, 0.02), Vector3(-0.15, 0.06, 0.35 * side), energy)
		for k in 3:
			ModelKit.box(body, Vector3(0.015, 0.4, 0.02), Vector3(-0.55 + k * 0.28, 0.02, 0.345 * side), metal)
	# Canopy in a gold frame.
	ModelKit.sphere(body, 0.24, Vector3(0.55, 0.26, 0.0), glass, Vector3(2.1, 0.7, 0.85))
	ModelKit.box(body, Vector3(0.9, 0.05, 0.36), Vector3(0.45, 0.17, 0.0), gold)
	ModelKit.box(body, Vector3(0.04, 0.18, 0.3), Vector3(0.35, 0.3, 0.0), gold)
	# Echo core on the camera side: violet-cyan energy in a gold ring.
	var core_at := Vector3(-0.35, -0.02, 0.36)
	ModelKit.sphere(body, 0.14, core_at, ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.2))
	ModelKit.cylinder(body, 0.19, 0.19, 0.04, core_at - Vector3(0, 0, 0.03), gold, Vector3(90, 0, 0), 16)
	_core_glow = ModelKit.quad(body, Vector2.ONE * 0.9, core_at + Vector3(0, 0, 0.1), ModelKit.glow(Palette.PLAYER_ENERGY, ArtStyle.GLOW_STANDARD * 0.6))
	# Canards.
	for side: float in [1.0, -1.0]:
		_wing_plate(body, Vector3(0.45, 0.05, 0.42), Vector3(0.95, 0.02, 0.28 * side), side, blue, 0.2)

	# Swept delta wings with wingtip pods and nav lights (red port / green starboard).
	for side: float in [1.0, -1.0]:
		var wing := ModelKit.group(_rig, "WingLeft" if side > 0 else "WingRight", Vector3(-0.35, -0.05, 0.3 * side))
		_wing_plate(wing, Vector3(1.35, 0.07, 1.25), Vector3(0.0, 0.0, 0.0), side, white, 0.05)
		_wing_plate(wing, Vector3(1.1, 0.05, 1.0), Vector3(-0.1, -0.05, 0.0), side, blue, 0.05)
		var tip := Vector3(-0.55, 0.0, 1.22 * side)
		ModelKit.hex_x(wing, 0.055, 0.45, tip, deep, 8)
		var nav := ModelKit.emissive(Color("ff4a5a") if side > 0 else Color("4dff9a"), 3.0)
		_nav_lights.append(nav)
		ModelKit.sphere(wing, 0.05, tip + Vector3(0.3, 0, 0), nav)

	# Twin nacelles: intake ring, blue shell, gold band, petal nozzle, glowing core and flame.
	for side: float in [1.0, -1.0]:
		var engine := ModelKit.group(_rig, "EngineLeft" if side > 0 else "EngineRight", Vector3(-1.15, 0.02, 0.3 * side))
		ModelKit.hex_x(engine, 0.25, 1.05, Vector3.ZERO, blue, 12, 0.92)
		ModelKit.hex_x(engine, 0.27, 0.1, Vector3(0.5, 0.0, 0.0), white, 12)
		ModelKit.cylinder(engine, 0.17, 0.17, 0.02, Vector3(0.56, 0.0, 0.0), metal, Vector3(0, 0, 90), 12)
		ModelKit.hex_x(engine, 0.26, 0.06, Vector3(0.1, 0.0, 0.0), gold, 12)
		ModelKit.hex_x(engine, 0.23, 0.16, Vector3(-0.58, 0.0, 0.0), metal, 12, 1.1)
		for p in 6:
			var a := TAU * p / 6.0
			ModelKit.box(engine, Vector3(0.14, 0.05, 0.02), Vector3(-0.7, cos(a) * 0.2, sin(a) * 0.2), metal, Vector3(rad_to_deg(a), 0, 0))
		var nozzle := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
		_nozzles.append(nozzle)
		ModelKit.cylinder(engine, 0.17, 0.17, 0.03, Vector3(-0.68, 0.0, 0.0), nozzle, Vector3(0, 0, 90), 12)
		var flame_material := ModelKit.glow(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.25), 2.2, ModelKit.GlowShape.STREAK)
		_flame_materials.append(flame_material)
		var flame := ModelKit.quad(engine, Vector2(1.0, 0.34), Vector3(-1.2, 0.0, 0.02), flame_material)
		_flames.append(flame)

	# Tail: canted twin fins, a ventral fin.
	var tail := ModelKit.group(_rig, "Tail", Vector3(-1.2, 0.2, 0.0))
	for side: float in [1.0, -1.0]:
		ModelKit.prism(tail, Vector3(0.55, 0.5, 0.05), Vector3(0.0, 0.2, 0.16 * side), blue, Vector3(18 * side, 0, 0))
	ModelKit.prism(tail, Vector3(0.4, 0.3, 0.04), Vector3(0.1, -0.62, 0.0), deep, Vector3(0, 0, 180))

	_dash_streak = ModelKit.quad(self, Vector2(4.2, 1.5), Vector3(-2.6, 0.0, -0.4),
			ModelKit.glow(Palette.PLAYER_SECONDARY.lerp(Palette.PLAYER_ENERGY, 0.5), 1.3, ModelKit.GlowShape.STREAK))
	_dash_streak.visible = false


## A swept wing plate lying in the XZ plane: root chord along X at the body, the tip swept back
## toward -X and out along ±Z (side). `sweep_front` trims the leading edge forward.
func _wing_plate(parent: Node3D, size: Vector3, at: Vector3, side: float, mat: Material, sweep_front: float) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	# Triangle in XY (apex over the rear end), extruded along Z; rotated so the apex points out.
	mesh.size = Vector3(size.x, size.z, size.y)
	mesh.left_to_right = sweep_front
	return ModelKit._add(parent, mesh, at + Vector3(0, 0, size.z * 0.5 * side), mat, Vector3(90 * side, 0, 0))


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
		var part := _rig.get_node_or_null(NodePath(part_name)) as Node3D if _rig else null
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
		flame.position.x = -0.72 - length * 0.5
		_nozzles[i].emission_energy_multiplier = (0.6 if cut else 2.6)
	# Nav lights blink in turn.
	for i in _nav_lights.size():
		_nav_lights[i].emission_energy_multiplier = 4.0 if fmod(_time + i * 0.5, 1.0) < 0.12 else 0.8
	if _core_glow:
		(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
				&"energy", ArtStyle.GLOW_STANDARD * (0.5 + 0.15 * sin(_time * 4.0)))
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 7.0)
	position.x = -_recoil * 0.22
	scale = Vector3(1.0 - _recoil * 0.08, 1.0 + _recoil * 0.05, 1.0) * base_scale if not _dash_streak.visible else scale
