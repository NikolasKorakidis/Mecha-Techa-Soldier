class_name WarshipExterior
extends Node3D
## Far superstructure of the enemy warship (command tower, radar, gun batteries, engines),
## seen behind the roof deck. Lives under a CameraFollower with factor < 1 so it parallaxes
## slower than the deck — the ship reads as enormous. Local positions are authored for the
## drop moment (camera around x -60, y 36); `follow_factor` must match the follower.

@export var follow_factor: float = 0.6
## Camera position the layout is framed for.
@export var framing: Vector2 = Vector2(-60.0, 36.0)

var _blinkers: Array[StandardMaterial3D] = []
var _dishes: Array[Node3D] = []
var _turrets: Array[Node3D] = []
var _time: float = 0.0


func _ready() -> void:
	var hull := ModelKit.toon(Color("1a2338"), 0.35, 0.7, 0.4)
	var hull_dark := ModelKit.toon(Color("111829"), 0.3, 0.8, 0.3)
	var trim := ModelKit.toon(Color("2c3a5c"), 0.45, 0.55, 0.5)
	var warm := ModelKit.emissive(Color("ffc46b"), 1.3)
	var cool := ModelKit.emissive(Color("7fd8ff"), 1.3)
	# Command tower: stepped blocks with window bands, bridge wings, antenna array.
	var tower := ModelKit.group(self, "CommandTower", _at(-36.0, 30.0, -34.0))
	var widths := [26.0, 20.0, 15.0, 11.0]
	var y := 0.0
	for k in widths.size():
		var w: float = widths[k]
		var h := 9.0 - k
		ModelKit.box(tower, Vector3(w, h, 8.0), Vector3(0, y + h * 0.5, 0), hull if k % 2 == 0 else hull_dark)
		ModelKit.box(tower, Vector3(w + 0.4, 0.5, 8.4), Vector3(0, y + h, 0), trim)
		for wx in range(int(-w * 0.5) + 1, int(w * 0.5), 2):
			ModelKit.box(tower, Vector3(1.1, 0.5, 0.1), Vector3(wx, y + h * 0.55, 4.05), warm if (wx + k) % 3 else cool)
		y += h
	ModelKit.box(tower, Vector3(18.0, 2.2, 5.0), Vector3(0, y + 1.1, 0), hull_dark)
	ModelKit.box(tower, Vector3(17.0, 0.6, 0.1), Vector3(0, y + 1.2, 2.55), cool)
	for ax: float in [-4.0, 0.0, 3.0]:
		ModelKit.box(tower, Vector3(0.3, 8.0 + ax, 0.3), Vector3(ax, y + 6.0 + ax * 0.5, 0), trim)
		var blink := ModelKit.emissive(Palette.DANGER, 2.0)
		_blinkers.append(blink)
		ModelKit.sphere(tower, 0.35, Vector3(ax, y + 10.0 + ax, 0), blink)
	# Radar dishes.
	for d: Array in [[-84.0, 33.0, -40.0], [-8.0, 33.0, -44.0]]:
		var dish := ModelKit.group(self, "Dish", _at(d[0], d[1], d[2]))
		ModelKit.box(dish, Vector3(1.0, 6.0, 1.0), Vector3(0, 3.0, 0), trim)
		var head := ModelKit.group(dish, "Head", Vector3(0, 6.5, 0))
		ModelKit.cylinder(head, 3.2, 1.0, 1.2, Vector3.ZERO, hull, Vector3(0, 0, 70), 16)
		ModelKit.box(head, Vector3(2.6, 0.2, 0.2), Vector3(1.4, 0.4, 0), trim)
		_dishes.append(head)
	# Heavy gun batteries.
	for g: Array in [[-100.0, 31.0, -22.0], [-62.0, 31.0, -20.0], [-14.0, 31.0, -24.0]]:
		var turret := ModelKit.group(self, "Battery", _at(g[0], g[1], g[2]))
		ModelKit.cylinder(turret, 3.0, 3.6, 2.0, Vector3(0, 1.0, 0), hull_dark, Vector3.ZERO, 12)
		var head := ModelKit.group(turret, "Head", Vector3(0, 2.6, 0))
		ModelKit.box(head, Vector3(5.0, 2.2, 4.0), Vector3.ZERO, hull)
		for bz: float in [-1.0, 1.0]:
			ModelKit.hex_x(head, 0.4, 7.0, Vector3(5.5, 0.2, bz), trim, 8)
		_turrets.append(head)
	# Stern engines (left end): three huge nozzles with blue burn.
	var engines := ModelKit.group(self, "Engines", _at(-150.0, 18.0, -18.0))
	for k in 3:
		var ey := -k * 9.0
		ModelKit.hex_x(engines, 4.0, 10.0, Vector3(0, ey, 0), hull_dark, 12, 1.2)
		ModelKit.cylinder(engines, 3.3, 3.3, 0.3, Vector3(-5.1, ey, 0), ModelKit.emissive(Color("6fcfff"), 3.0), Vector3(0, 0, 90), 16)
		ModelKit.quad(engines, Vector2(22.0, 7.0), Vector3(-15.0, ey, 0.5), ModelKit.glow(Color("4fb8ff"), 1.2, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
	# Hull ridge strips with lights in between the landmarks.
	for rx in range(-140, 160, 12):
		ModelKit.box(self, Vector3(10.0, 1.2, 3.0), _at(rx, 30.6, -14.0), hull_dark)
		ModelKit.box(self, Vector3(0.6, 0.2, 0.1), _at(rx + 4.5, 31.0, -12.45), warm)


## World position at framing → local position under the follower.
func _at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x - framing.x * follow_factor, y - framing.y * follow_factor, z)


func _process(delta: float) -> void:
	_time += delta
	for i in _blinkers.size():
		_blinkers[i].emission_energy_multiplier = 3.0 if fmod(_time + i * 0.4, 1.4) < 0.15 else 0.2
	for d in _dishes:
		d.rotation.y += delta * 0.6
	for i in _turrets.size():
		_turrets[i].rotation.y = sin(_time * 0.3 + i) * 0.5
