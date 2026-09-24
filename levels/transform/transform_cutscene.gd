class_name TransformCutscene
extends Node3D
## Short, skippable transformation beat between stages: the current form breaks into its
## recognizable parts, a flash, and the parts re-lock as the next form. Then routes on.
## Any of jump / fire / special / ui_accept skips after a short grace period.

signal finished

enum Form { SHIP, MECH, BIKE }

@export var from_form: Form = Form.SHIP
@export var to_form: Form = Form.MECH
@export var title: String = "MECH MODE"
@export var subtitle: String = ""
@export_file("*.tscn") var next_level: String = ""
@export var stage_ui: StageUI
@export var camera: GameplayCamera
@export var model_scale: float = 1.8
## Models sit below centre so the mode banner never covers them.
@export var stage_offset_y: float = -1.9
@export var accent: Color = Palette.PLAYER_ENERGY

const T_ENTER := 0.9
const T_SPLIT := 1.7
const T_ASSEMBLE := 2.9
const T_LOCK := 3.3
const T_END := 4.9
const SKIP_GRACE := 0.4

var time: float = 0.0
var done: bool = false

var _stage: Node3D
var _from: Node3D
var _to: Node3D
var _from_parts: Array[Dictionary] = []
var _to_parts: Array[Dictionary] = []
var _ring: MeshInstance3D
var _flash: ColorRect
var _swapped: bool = false
var _locked: bool = false


func _ready() -> void:
	if stage_ui == null or camera == null:
		push_error("TransformCutscene: stage_ui and camera must be assigned.")
		return
	_stage = ModelKit.group(self, "Stage")
	_stage.rotation_degrees = Vector3(0, -28, 0)
	_from = _make_model(from_form)
	_to = _make_model(to_form)
	_to.visible = false
	_from_parts = _collect_parts(_from)
	_to_parts = _collect_parts(_to)
	for part in _to_parts:
		var node := part["node"] as Node3D
		node.position = part["home"] + part["scatter"]
		node.rotation = part["spin"]
	_ring = ModelKit.quad(self, Vector2.ONE * 2.0, Vector3(0, stage_offset_y, -1.5), ModelKit.glow(accent, 0.0, ModelKit.GlowShape.RING))
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)
	stage_ui.show_prompt("PRESS JUMP TO SKIP")


func _process(delta: float) -> void:
	tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if time < SKIP_GRACE or done:
		return
	for action: StringName in [&"jump", &"fire", &"special", &"ui_accept"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_finish()
			return


func tick(delta: float) -> void:
	if done or _stage == null:
		return
	time += delta
	var center_y := _center_offset(to_form if _swapped else from_form)
	# Enter: glide in and settle.
	var enter := clampf(time / T_ENTER, 0.0, 1.0)
	_stage.position = Vector3(lerpf(-9.0, 0.0, 1.0 - pow(1.0 - enter, 3.0)), stage_offset_y - center_y, 0)
	_stage.rotation_degrees.y = -28.0 + 10.0 * sin(time * 1.3)
	if time >= T_ENTER and not _swapped:
		var split := clampf((time - T_ENTER) / (T_SPLIT - T_ENTER), 0.0, 1.0)
		var e := split * split
		for part in _from_parts:
			var node := part["node"] as Node3D
			node.position = (part["home"] as Vector3) + (part["scatter"] as Vector3) * e
			node.rotation = (part["rest_rot"] as Vector3) + (part["spin"] as Vector3) * e
		_set_ring(split * 2.5, split * 1.8)
		if time >= T_SPLIT:
			_swap()
	if _swapped and not _locked:
		var join := clampf((time - T_SPLIT) / (T_ASSEMBLE - T_SPLIT), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - join, 3.0)
		for part in _to_parts:
			var node := part["node"] as Node3D
			node.position = (part["home"] as Vector3) + (part["scatter"] as Vector3) * (1.0 - e)
			node.rotation = (part["rest_rot"] as Vector3) + (part["spin"] as Vector3) * (1.0 - e)
		_set_ring(2.5 - join * 1.5, 1.8 * (1.0 - join) + 0.4)
		if time >= T_ASSEMBLE:
			_lock()
	if _locked:
		var fade := clampf((time - T_ASSEMBLE) / 0.8, 0.0, 1.0)
		_set_ring(1.0 + fade * 2.0, 1.4 * (1.0 - fade))
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 2.5)
	if time >= T_END:
		_finish()


func _swap() -> void:
	_swapped = true
	_from.visible = false
	_to.visible = true
	_flash.color.a = 0.85 * ArtStyle.flash_scale()
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), Vector3(0, stage_offset_y, 1), 3.0, {&"color": accent})


func _lock() -> void:
	_locked = true
	for part in _to_parts:
		(part["node"] as Node3D).position = part["home"]
		(part["node"] as Node3D).rotation = part["rest_rot"]
	camera.add_trauma(ArtStyle.SHAKE_ELITE_DEATH)
	_flash.color.a = 0.35 * ArtStyle.flash_scale()
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), Vector3(0, stage_offset_y, 1), 4.5, {&"color": Palette.PLAYER_PRIMARY})
	stage_ui.show_banner(title, subtitle, T_END - T_LOCK + 0.6)


func _finish() -> void:
	if done:
		return
	done = true
	finished.emit()
	if not next_level.is_empty():
		SceneRouter.go_to.call_deferred(next_level)


func _set_ring(size: float, energy: float) -> void:
	_ring.scale = Vector3.ONE * maxf(0.01, size * model_scale)
	(_ring.material_override as ShaderMaterial).set_shader_parameter(&"energy", energy)


func _make_model(form: Form) -> Node3D:
	var model: Node3D
	match form:
		Form.SHIP:
			model = KestrelModel.new()
		Form.MECH:
			model = MechModel.new()
		Form.BIKE:
			model = BikeModel.new()
	model.scale = Vector3.ONE * model_scale
	_stage.add_child(model)
	return model


## Mech and bike are built feet-down; centre them on the view like the ship.
func _center_offset(form: Form) -> float:
	match form:
		Form.MECH:
			return 1.25 * model_scale
		Form.BIKE:
			return 0.8 * model_scale
	return 0.0


func _collect_parts(model: Node3D) -> Array[Dictionary]:
	var names: Array = model.get_script().get_script_constant_map().get("PART_NAMES", [])
	var parts: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for node in model.find_children("*", "Node3D", true, false):
		if not (node.name in names):
			continue
		var n := node as Node3D
		var outward := Vector3(n.position.x, n.position.y, 0).normalized()
		if outward == Vector3.ZERO:
			outward = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0).normalized()
		parts.append({
			"node": n,
			"home": n.position,
			"rest_rot": n.rotation,
			"scatter": outward * rng.randf_range(1.2, 2.2) + Vector3(0, 0, rng.randf_range(-0.6, 1.2)),
			"spin": Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-3, 3)),
		})
	return parts
