class_name HullRunBackdrop
extends Node3D
## Deep space around the warship for the 3D chase view (Star Wars-style battle):
##   sky shader (stars, galactic band, nebula) swapped into the environment on activate()
##   planets at "infinity" (follow the camera): ringed gas giant, red moon, the blue world below
##   distant capital ships trading turbolaser fire, fighters streaking past, burning hull
##   explosions ahead of the bike, speed streaks around the camera.
##   The warship itself (WarshipModel at track scale) spreads out under and around the deck, so
##   the run reads as racing along the spine of a 3.6 km capital ship.
## Inactive (hidden, no processing) until activate() — the side-view stages never see it.

@export var world_environment: WorldEnvironment
@export var active_on_ready: bool = false

## WarshipModel scale and placement: stern at x 150, bow tip at x 3750, dorsal deck just under
## the track plates.
const WARSHIP_SCALE := 3.6
const WARSHIP_CENTER_X := 1950.0

var active: bool = false
var warship: WarshipModel

var _sky_root: Node3D
var _ships: Array[Node3D] = []
var _camera: GameplayCamera
var _streaks: CPUParticles3D
var _blast_timer: float = 1.0
var _volley_timer: float = 1.5
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	_rng.seed = 77
	visible = false
	set_process(false)
	if active_on_ready:
		activate()


func activate() -> void:
	if active:
		return
	active = true
	visible = true
	set_process(true)
	_camera = GameplayCamera.find(get_tree())
	if _camera:
		# A sane near/far ratio keeps distant hull detail from shimmering (depth precision).
		_camera.near = 0.4
		_camera.far = 4500.0
	if world_environment == null:
		var found := get_tree().root.find_children("*", "WorldEnvironment", true, false)
		if not found.is_empty():
			world_environment = found[0] as WorldEnvironment
	if world_environment and world_environment.environment:
		var env := world_environment.environment.duplicate() as Environment
		var sky := Sky.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://art/shaders/space_sky.gdshader")
		sky.sky_material = mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world_environment.environment = env
	_sky_root = ModelKit.group(self, "SkyRoot")
	warship = WarshipModel.new()
	warship.clear_lane = 13.0
	warship.scale = Vector3.ONE * WARSHIP_SCALE
	# Well under the track plates: nothing on the hull can poke through or z-fight the spine.
	warship.position = Vector3(WARSHIP_CENTER_X, HullTrack.DECK_Y - 0.45, 0.0)
	add_child(warship)
	_build_planets()
	_build_ships()
	_build_streaks()


func _build_planets() -> void:
	SpacePlanets.build(_sky_root, SpacePlanets.Layout.HULL_RUN)


func _build_ships() -> void:
	var hull := ModelKit.toon(Color("2a3450"), 0.4, 0.7, 0.4)
	var hull_red := ModelKit.toon(Color("4a2a36"), 0.4, 0.7, 0.4)
	var win := ModelKit.emissive(Color("ffd9a0"), 1.5)
	for k in 5:
		var ally := k % 2 == 0
		var ship := ModelKit.group(self, "Capital%d" % k)
		var length := _rng.randf_range(60.0, 110.0)
		ModelKit.box(ship, Vector3(length, 8.0, 14.0), Vector3.ZERO, hull if ally else hull_red)
		ModelKit.prism(ship, Vector3(14.0, 20.0, 8.0), Vector3(length * 0.5 + 9.0, 0, 0), hull if ally else hull_red, Vector3(0, 0, -90))
		ModelKit.box(ship, Vector3(12.0, 10.0, 8.0), Vector3(-length * 0.25, 8.0, 0), hull if ally else hull_red)
		for w in int(length / 4.0):
			ModelKit.box(ship, Vector3(1.4, 0.5, 0.2), Vector3(-length * 0.5 + 2.0 + w * 4.0, 1.0, 7.1 * (1.0 if k < 3 else -1.0)), win)
		for e in 3:
			var burn := MeshInstance3D.new()
			burn.mesh = QuadMesh.new()
			burn.material_override = ModelKit.glow_billboard(Color(0.5, 0.8, 1.0) if ally else Color(1.0, 0.4, 0.3), 1.6)
			burn.position = Vector3(-length * 0.5 - 2.0, -2.0 + e * 2.0, 0)
			burn.scale = Vector3.ONE * 9.0
			ship.add_child(burn)
		ship.position = Vector3(_rng.randf_range(100.0, 900.0), _rng.randf_range(20.0, 90.0), (1.0 if k < 3 else -1.0) * _rng.randf_range(140.0, 260.0))
		ship.set_meta(&"speed", _rng.randf_range(18.0, 30.0))
		ship.set_meta(&"ally", ally)
		_ships.append(ship)


func _build_streaks() -> void:
	_streaks = CPUParticles3D.new()
	_streaks.amount = 28
	_streaks.lifetime = 0.5
	_streaks.local_coords = false
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(4.0, 12.0, 22.0)
	_streaks.direction = Vector3(-1, 0, 0)
	_streaks.spread = 2.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 120.0
	_streaks.initial_velocity_max = 160.0
	_streaks.scale_amount_min = 1.0
	_streaks.scale_amount_max = 1.0
	var box := BoxMesh.new()
	box.size = Vector3(5.0, 0.03, 0.03)
	box.material = ModelKit.emissive(Color(0.6, 0.75, 1.0), 0.7)
	_streaks.mesh = box
	_streaks.visibility_aabb = AABB(Vector3(-200, -40, -60), Vector3(400, 80, 120))
	add_child(_streaks)


func _process(delta: float) -> void:
	_time += delta
	if _camera == null:
		return
	var cam := _camera.global_position
	_sky_root.global_position = cam
	_streaks.global_position = cam + Vector3(70.0, 0, 0)
	var player := Players.find(get_tree())
	var px := player.global_position.x if player else cam.x
	for ship in _ships:
		ship.global_position.x += float(ship.get_meta(&"speed")) * delta
		if ship.global_position.x < px - 400.0:
			ship.global_position.x += 1400.0
		elif ship.global_position.x > px + 1200.0:
			ship.global_position.x -= 1400.0
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_volley_timer = _rng.randf_range(0.6, 1.4)
		_volley()
	_blast_timer -= delta
	if _blast_timer <= 0.0 and player:
		# The ship is coming apart: blasts get denser the closer you are to the bow.
		var collapse := clampf((px - 2900.0) / 600.0, 0.0, 1.0)
		_blast_timer = _rng.randf_range(0.35, 0.7) * (1.0 - 0.5 * collapse)
		_hull_explosion(px)
		if _rng.randf() < 0.35 + 0.4 * collapse:
			_deck_edge_blast(px)
		if _rng.randf() < 0.25:
			_skyline_explosion(px)


## Turbolaser exchange between two capital ships (or into the warship).
func _volley() -> void:
	if _ships.size() < 2:
		return
	var a := _ships[_rng.randi() % _ships.size()]
	var b := _ships[_rng.randi() % _ships.size()]
	if a == b:
		return
	var from := a.global_position
	var to := b.global_position + Vector3(_rng.randf_range(-30, 30), _rng.randf_range(-5, 5), 0)
	var color := Color(0.45, 1.0, 0.55) if a.get_meta(&"ally") else Color(1.0, 0.35, 0.3)
	for k in 3:
		var bolt := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.8, 16.0)
		bolt.mesh = box
		bolt.material_override = ModelKit.emissive(color, 4.0)
		add_child(bolt)
		bolt.global_position = from
		bolt.look_at(to, Vector3.UP)
		var tween := create_tween()
		tween.tween_interval(k * 0.1)
		tween.tween_property(bolt, "global_position", to, 0.9)
		tween.tween_callback(func() -> void:
			if is_instance_valid(bolt):
				Explosion3D.spawn(get_tree(), bolt.global_position, 6.0)
				bolt.queue_free())


## A blast right at the deck rail next to or just ahead of the bike (visual, shakes the camera).
func _deck_edge_blast(px: float) -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var at := Vector3(px + _rng.randf_range(8.0, 60.0), HullTrack.DECK_Y + _rng.randf_range(0.5, 3.0), side * _rng.randf_range(9.5, 13.0))
	Explosion3D.spawn(get_tree(), at, _rng.randf_range(2.0, 3.5), 0.12)
	Explosion3D.spawn(get_tree(), at + Vector3(_rng.randf_range(-2, 2), _rng.randf_range(2, 5), side * 2.0), 1.4)


## Big blasts out on the wide hull and the superstructure islands; some leave fires burning.
func _skyline_explosion(px: float) -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var at := Vector3(px + _rng.randf_range(60.0, 500.0), HullTrack.DECK_Y + _rng.randf_range(0.0, 30.0), side * _rng.randf_range(50.0, 300.0))
	Explosion3D.spawn(get_tree(), at, _rng.randf_range(6.0, 14.0))
	if warship and _rng.randf() < 0.3 and warship.get_child_count() < 400:
		var local := warship.to_local(at)
		local.y = 0.5
		warship.add_fire(local, _rng.randf_range(0.8, 1.6))


## Explosions tearing through the warship's hull beside and ahead of the bike.
func _hull_explosion(px: float) -> void:
	var near := _rng.randf() < 0.25
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var at := Vector3(px + _rng.randf_range(30.0, 150.0), HullTrack.DECK_Y + _rng.randf_range(-2.0, 10.0), side * _rng.randf_range(12.0 if near else 16.0, 32.0))
	var s := _rng.randf_range(2.0, 4.5)
	Explosion3D.spawn(get_tree(), at, s, 0.18 if near and at.x - px < 60.0 else 0.0)
	if _rng.randf() < 0.3:
		Explosion3D.spawn(get_tree(), at + Vector3(_rng.randf_range(-4, 4), _rng.randf_range(2, 6), _rng.randf_range(-3, 3)), s * 0.6)
