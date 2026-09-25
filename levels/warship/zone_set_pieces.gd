class_name ZoneSetPieces
extends Node3D
## Signature background machinery for each Stage 2 zone, placed in the backdrop's mid layer
## (behind the play plane, parallax factor `factor`): parked fighters and a gantry crane in
## the hangar, molten vats in the foundry, tesla coils arcing in the corridor, lift cables with
## moving counterweights in the shaft, the reactor column with spinning rings, alarm pistons,
## the security emblem, violet conduits at the core. Animates itself; purely visual.

@export var factor: float = 0.8
@export var z: float = -4.5

var _arcs: Array[MeshInstance3D] = []
var _rings: Array[Node3D] = []
var _weights: Array[Node3D] = []
var _pistons: Array[Node3D] = []
var _pulses: Array[StandardMaterial3D] = []
var _molten: Array[StandardMaterial3D] = []
var _eye: StandardMaterial3D
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 314
	_hangar()
	_foundry()
	_arc_corridor()
	_shaft()
	_reactor()
	_alarm_hall()
	_security()
	_core_conduits()
	for i in WarshipZones.ZONES.size():
		_zone_dressing(i)


## Local position for something meant to sit behind world x when the camera is centred there.
func _at(world_x: float, y: float, dz: float = 0.0) -> Vector3:
	return Vector3(world_x * factor, y, z + dz)


func _mat(color: Color, rim: float = 0.35) -> StandardMaterial3D:
	return ModelKit.toon(color, rim, 0.6, 0.45)


func _hangar() -> void:
	var accent := WarshipZones.accent_at(0.0)
	var hull := _mat(Color("252a38"))
	var dark := _mat(Color("12151f"), 0.2)
	# Parked interceptors on cradles, lit from below by the deck lamps.
	for fx: float in [-4.0, 21.0]:
		var ship := ModelKit.group(self, "ParkedFighter", _at(fx, 3.2, -1.0))
		ModelKit.box(ship, Vector3(5.0, 1.0, 1.4), Vector3.ZERO, hull)
		ModelKit.prism(ship, Vector3(1.0, 2.2, 1.2), Vector3(3.1, 0, 0), hull, Vector3(0, 0, -90))
		ModelKit.box(ship, Vector3(2.4, 0.2, 4.0), Vector3(-0.8, 0, 0), dark, Vector3(0, 0, 4))
		ModelKit.box(ship, Vector3(1.2, 0.5, 0.8), Vector3(0.6, 0.6, 0), ModelKit.emissive(accent.lerp(Color.WHITE, 0.4), 1.0))
		ModelKit.box(ship, Vector3(0.4, 0.8, 1.6), Vector3(-2.6, 0, 0), ModelKit.emissive(Color("ff5a3c"), 1.2))
		for cx: float in [-1.5, 1.5]:
			ModelKit.box(ship, Vector3(0.3, 3.2, 0.3), Vector3(cx, -2.1, 0), dark)
		ModelKit.box(ship, Vector3(5.0, 0.3, 1.8), Vector3(0, -3.6, 0), dark)
	# Gantry crane over the bay with a hanging hook.
	ModelKit.box(self, Vector3(40.0, 0.8, 1.0), _at(10.0, 17.0), dark)
	ModelKit.box(self, Vector3(2.4, 1.4, 1.4), _at(8.0, 16.0), hull)
	ModelKit.box(self, Vector3(0.1, 6.0, 0.1), _at(8.0, 12.6), dark)
	ModelKit.prism(self, Vector3(0.8, 0.8, 0.4), _at(8.0, 9.4), hull, Vector3(0, 0, 180))
	# Warm floodlights along the ceiling.
	for lx in range(-12, 34, 8):
		ModelKit.box(self, Vector3(1.8, 0.3, 0.6), _at(lx, 15.0, 0.4), ModelKit.emissive(accent, 2.0))
		var cone := ModelKit.quad(self, Vector2(12.0, 3.4), _at(lx, 9.0, 0.6), ModelKit.glow(accent, 0.22, ModelKit.GlowShape.STREAK))
		cone.rotation_degrees = Vector3(0, 0, 90)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _foundry() -> void:
	var accent := WarshipZones.accent_at(50.0)
	var iron := _mat(Color("2a1f1c"), 0.3)
	var dark := _mat(Color("140d0c"), 0.2)
	for vx: float in [44.0, 66.0, 86.0]:
		var vat := ModelKit.group(self, "Vat", _at(vx, 6.0, -1.0))
		ModelKit.cylinder(vat, 2.6, 2.1, 4.0, Vector3.ZERO, iron, Vector3.ZERO, 12)
		var molten := ModelKit.emissive(accent.lerp(Color(1, 0.85, 0.4), 0.3), 2.4)
		_molten.append(molten)
		ModelKit.cylinder(vat, 2.3, 2.3, 0.2, Vector3(0, 2.0, 0), molten, Vector3.ZERO, 12)
		ModelKit.quad(vat, Vector2(9.0, 5.0), Vector3(0, 2.6, 0.8), ModelKit.glow(accent, 0.9))
		for sx: float in [-1.6, 1.6]:
			ModelKit.box(vat, Vector3(0.14, 9.0, 0.14), Vector3(sx, 6.5, 0), dark)
		# Pour stream into the pit below.
		ModelKit.box(vat, Vector3(0.5, 10.0, 0.5), Vector3(2.8, -5.0, 0), molten)
		ModelKit.box(vat, Vector3(1.4, 0.4, 0.6), Vector3(2.4, 1.6, 0), iron, Vector3(0, 0, -25))
	# The pit glows from below.
	var glow := ModelKit.quad(self, Vector2(40.0, 10.0), _at(60.0, -3.0, 1.0), ModelKit.glow(accent, 1.1))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _arc_corridor() -> void:
	var accent := WarshipZones.accent_at(100.0)
	var metal := _mat(Color("1c2240"))
	for cx: float in [97.0, 109.0, 121.0]:
		var coil := ModelKit.group(self, "TeslaCoil", _at(cx, 0.0, -0.5))
		ModelKit.cylinder(coil, 0.6, 1.0, 6.5, Vector3(0, 3.25, 0), metal, Vector3.ZERO, 10)
		for ry in range(1, 6):
			ModelKit.cylinder(coil, 0.9, 0.9, 0.18, Vector3(0, ry * 1.1, 0), ModelKit.emissive(accent, 1.2), Vector3.ZERO, 12)
		ModelKit.sphere(coil, 0.9, Vector3(0, 7.0, 0), ModelKit.emissive(accent.lerp(Color.WHITE, 0.5), 2.6))
		ModelKit.quad(coil, Vector2.ONE * 5.0, Vector3(0, 7.0, 0.5), ModelKit.glow(accent, 1.2))
	# Arcs jumping between neighbouring coils (flicker in _process).
	for k in 2:
		var mid := 97.0 + 6.0 + k * 12.0
		for n in 2:
			var arc := ModelKit.quad(self, Vector2(12.0 * factor, 0.9), _at(mid, 7.0 + n * 0.3, 0.1), ModelKit.glow(accent.lerp(Color.WHITE, 0.4), 2.0, ModelKit.GlowShape.STREAK))
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arcs.append(arc)


func _shaft() -> void:
	var accent := WarshipZones.accent_at(140.0)
	var dark := _mat(Color("0e1a1c"), 0.2)
	var weight := _mat(Color("223436"))
	for sx: float in [130.0, 150.0, 162.0]:
		for c in 2:
			ModelKit.box(self, Vector3(0.12, 44.0, 0.12), _at(sx + c * 1.2, 10.0), dark)
		var w := ModelKit.group(self, "Counterweight", _at(sx + 0.6, 8.0, 0.2))
		ModelKit.box(w, Vector3(2.4, 3.2, 1.2), Vector3.ZERO, weight)
		ModelKit.box(w, Vector3(2.5, 0.2, 1.3), Vector3(0, 1.0, 0), ModelKit.emissive(accent, 1.4))
		ModelKit.box(w, Vector3(2.5, 0.2, 1.3), Vector3(0, -1.0, 0), ModelKit.emissive(accent, 1.4))
		w.set_meta(&"base_y", w.position.y)
		w.set_meta(&"speed", _rng.randf_range(0.3, 0.6))
		_weights.append(w)
	# Status light ladders up the shaft walls.
	for ly in range(0, 26, 3):
		for sx: float in [136.0, 156.0]:
			ModelKit.box(self, Vector3(0.5, 0.5, 0.2), _at(sx, ly, -0.6), ModelKit.emissive(accent if ly % 2 == 0 else Color("1d5a4a"), 1.6))


func _reactor() -> void:
	var accent := WarshipZones.accent_at(180.0)
	var shell := _mat(Color("16233a"))
	var column := ModelKit.group(self, "ReactorColumn", _at(183.0, 6.0, -2.5))
	ModelKit.cylinder(column, 4.0, 4.0, 44.0, Vector3.ZERO, shell, Vector3.ZERO, 16)
	var core := ModelKit.emissive(accent.lerp(Color.WHITE, 0.2), 1.6)
	_pulses.append(core)
	ModelKit.cylinder(column, 2.2, 2.2, 44.2, Vector3.ZERO, core, Vector3.ZERO, 12)
	ModelKit.quad(column, Vector2(40.0, 12.0), Vector3(0, 0, 4.2), ModelKit.glow(accent, 0.25, ModelKit.GlowShape.RADIAL), Vector3(0, 0, 90))
	for ry in [-8.0, -2.0, 4.0, 10.0, 16.0]:
		var ring := ModelKit.group(column, "Ring", Vector3(0, ry, 0))
		for k in 8:
			var a := TAU * k / 8.0
			ModelKit.box(ring, Vector3(1.4, 0.6, 1.0), Vector3(cos(a) * 4.6, 0, sin(a) * 4.6), _mat(Color("2b3d5c")))
		ModelKit.cylinder(ring, 4.4, 4.4, 0.25, Vector3.ZERO, ModelKit.emissive(accent, 1.8), Vector3.ZERO, 16)
		_rings.append(ring)
	# Energy conduits feeding the column.
	for side: float in [-1.0, 1.0]:
		var conduit := ModelKit.emissive(accent, 1.4)
		_pulses.append(conduit)
		ModelKit.box(self, Vector3(14.0, 0.5, 0.5), _at(183.0 + side * 9.0, 12.0, -1.0), conduit)


func _alarm_hall() -> void:
	var accent := WarshipZones.accent_at(220.0)
	var steel := _mat(Color("2a1a22"))
	for px in range(204, 246, 7):
		var piston := ModelKit.group(self, "Piston", _at(px, 12.0, -0.8))
		ModelKit.box(piston, Vector3(2.0, 3.0, 1.6), Vector3(0, 3.0, 0), steel)
		var rod := ModelKit.group(piston, "Rod")
		ModelKit.box(rod, Vector3(0.7, 5.0, 0.7), Vector3(0, -1.0, 0), _mat(Color("5a4a55"), 0.6))
		ModelKit.box(rod, Vector3(2.4, 0.8, 1.8), Vector3(0, -3.6, 0), steel)
		rod.set_meta(&"phase", px * 0.37)
		_pistons.append(rod)
	for bx in range(206, 246, 10):
		var lamp := ModelKit.group(self, "AlarmLamp", _at(bx, 16.5, 0.4))
		ModelKit.cylinder(lamp, 0.4, 0.5, 0.6, Vector3.ZERO, ModelKit.emissive(accent, 2.4), Vector3.ZERO, 8)
		var sweep := ModelKit.quad(lamp, Vector2(9.0, 2.0), Vector3(4.5, 0, 0.1), ModelKit.glow(accent, 0.8, ModelKit.GlowShape.STREAK))
		sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rings.append(lamp)


func _security() -> void:
	var accent := WarshipZones.accent_at(258.0)
	var plate := _mat(Color("2c2618"))
	var emblem := ModelKit.group(self, "Emblem", _at(258.0, 9.0, -1.5))
	ModelKit.cylinder(emblem, 5.0, 5.0, 0.6, Vector3.ZERO, plate, Vector3(90, 0, 0), 6)
	ModelKit.cylinder(emblem, 4.2, 4.2, 0.7, Vector3.ZERO, _mat(Color("16130c")), Vector3(90, 0, 0), 6)
	_eye = ModelKit.emissive(Color("ff3b30"), 2.6)
	ModelKit.sphere(emblem, 1.2, Vector3(0, 0, 0.4), _eye, Vector3(1.4, 1, 0.5))
	for k in 6:
		var a := TAU * k / 6.0
		ModelKit.box(emblem, Vector3(0.4, 1.6, 0.3), Vector3(cos(a) * 3.2, sin(a) * 3.2, 0.4), ModelKit.emissive(accent, 1.6), Vector3(0, 0, rad_to_deg(a) + 90))
	for bx: float in [249.0, 267.0]:
		ModelKit.box(self, Vector3(2.4, 12.0, 0.2), _at(bx, 9.0, -1.0), ModelKit.emissive(accent.darkened(0.55), 1.0))


func _core_conduits() -> void:
	var accent := WarshipZones.accent_at(300.0)
	for cy: float in [5.0, 15.0]:
		ModelKit.hex_x(self, 0.28, 70.0, _at(305.0, cy, -1.6), _mat(Color("2a1c48")), 8)
		ModelKit.hex_x(self, 0.1, 70.0, _at(305.0, cy, -1.3), ModelKit.emissive(accent, 0.8), 6)
	for cx in range(276, 336, 9):
		ModelKit.box(self, Vector3(0.8, 22.0, 0.8), _at(cx, 8.0, -0.4), _mat(Color("1b1430")))


## Shared colour dressing for every zone: neon bands in the accent and secondary colours,
## vertical light strips, coloured light shafts from the ceiling and a big sector sign.
func _zone_dressing(i: int) -> void:
	var span := WarshipZones.span(i)
	var accent: Color = WarshipZones.ZONES[i][2]
	var secondary: Color = WarshipZones.ZONES[i][4]
	var length := span.y - span.x
	var mid := (span.x + span.y) * 0.5
	var band_a := ModelKit.emissive(accent, 1.6)
	var band_b := ModelKit.emissive(secondary, 1.4)
	_pulses.append(band_b)
	ModelKit.box(self, Vector3(length * factor, 0.14, 0.1), _at(mid, 1.4, -1.8), band_a)
	ModelKit.box(self, Vector3(length * factor, 0.1, 0.1), _at(mid, 13.2, -1.8), band_b)
	ModelKit.box(self, Vector3(length * factor, 0.06, 0.1), _at(mid, 13.6, -1.8), band_a)
	var x := span.x + 3.0
	var k := 0
	while x < span.y - 2.0:
		var strip := ModelKit.box(self, Vector3(0.12, 4.0, 0.1), _at(x, 7.0, -1.7), band_b if k % 2 == 0 else band_a)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k % 3 == 1:
			var shaft := ModelKit.quad(self, Vector2(16.0, 3.6), _at(x, 10.0, -1.0), ModelKit.glow(secondary if k % 2 else accent, 0.16, ModelKit.GlowShape.STREAK), Vector3(0, 0, 105))
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x += 6.0
		k += 1
	var sign := Label3D.new()
	sign.text = String(WarshipZones.ZONES[i][5])
	sign.font_size = 96
	sign.pixel_size = 0.018
	sign.outline_size = 18
	sign.outline_modulate = Color(0.02, 0.02, 0.05, 0.9)
	sign.modulate = accent.lerp(Color.WHITE, 0.15)
	sign.position = _at(span.x + 12.0, 17.2, 1.0)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(sign)
	var underline := ModelKit.box(self, Vector3(9.0, 0.12, 0.1), _at(span.x + 16.0, 16.3, 1.0), band_b)
	underline.position.x = sign.position.x + 4.5


func _process(delta: float) -> void:
	_time += delta
	for i in _arcs.size():
		_arcs[i].visible = fmod(_time * 7.0 + i * 1.7, 3.0) < 1.2
		_arcs[i].position.y = 7.0 + sin(_time * 30.0 + i) * 0.4
	for ring in _rings:
		ring.rotation.y += delta * (1.4 if ring.name == &"Ring" else 3.0)
	for w in _weights:
		w.position.y = float(w.get_meta(&"base_y")) + sin(_time * float(w.get_meta(&"speed"))) * 9.0
	for rod in _pistons:
		rod.position.y = -maxf(0.0, sin(_time * 2.2 + float(rod.get_meta(&"phase")))) * 1.6
	for i in _pulses.size():
		_pulses[i].emission_energy_multiplier = 1.0 + 0.8 * maxf(0.0, sin(_time * 3.0 - i * 0.8))
	for m in _molten:
		m.emission_energy_multiplier = 2.2 + 0.4 * sin(_time * 5.0)
	if _eye:
		_eye.emission_energy_multiplier = 2.0 + 1.2 * maxf(0.0, sin(_time * 2.0))
