class_name TutorialCard
extends Control
## Contextual tutorial: one short card at a time with an input glyph (keyboard or controller,
## whichever was used last). Each card fades once its action is performed and is remembered
## in Settings so it never shows again. Moves to the top safe area if the ship flies under it.

const STEPS: Array[Dictionary] = [
	{"id": "move", "text": "MOVE", "key": "W A S D", "pad": "L-STICK", "hold": 0.8},
	{"id": "fire", "text": "HOLD TO FIRE", "key": "J", "pad": "RT", "hold": 1.0},
	{"id": "dash", "text": "DASH THROUGH DANGER", "key": "K", "pad": "B", "hold": 0.0},
	{"id": "super", "text": "SUPER READY — UNLEASH IT", "key": "I", "pad": "RB", "hold": 0.0, "when": "super_ready"},
]
## Players may expose `tutorial_steps() -> Array[Dictionary]` to replace the ship's cards.
## A step with "when": "super_ready" waits until the SUPER meter is full.
const ECHO_STEP := {"id": "echo_core", "text": "FLY INTO THE CORE TO STEAL ITS WEAPON", "key": "", "pad": "", "hold": 0.0}
const START_DELAY := 2.8
## An ignored card steps aside after this long and returns later (never marked done).
const TIMEOUT := 25.0
const LOW_Y := 0.78
const HIGH_Y := 0.16

var active_id: String = ""

var _card: PanelContainer
var _glyph: PanelContainer
var _glyph_label: Label
var _text: Label
var _using_pad: bool = false
var _progress: float = 0.0
var _delay: float = START_DELAY
var _tween: Tween
var _step: Dictionary = {}
var _shown_for: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	SceneRouter.level_changed.connect(func(_l: Node) -> void: _reset_for_level())


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_set_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_pad(false)


func _process(delta: float) -> void:
	var player := Players.find(get_tree())
	if player == null or not Settings.tutorials_enabled or (player.has_method(&"in_cinematic") and player.call(&"in_cinematic")):
		_hide()
		return
	if active_id.is_empty():
		_delay -= delta
		if _delay <= 0.0:
			_pick_next()
		return
	_avoid_player(player)
	_shown_for += delta
	if _step_satisfied(delta):
		Settings.mark_tutorial_done(active_id)
		_dismiss()
	elif _shown_for >= TIMEOUT:
		_dismiss()
		_delay = 45.0


func _reset_for_level() -> void:
	_delay = START_DELAY
	active_id = ""
	_card.modulate.a = 0.0


func _pick_next() -> void:
	var player := Players.find(get_tree())
	var steps: Array = player.call(&"tutorial_steps") if player and player.has_method(&"tutorial_steps") else STEPS
	for step: Dictionary in steps:
		if Settings.tutorials_done.has(step["id"]):
			continue
		if step.get("when", "") == "super_ready" and not RunSession.super_ready():
			continue
		_show(step)
		return
	# First weapon core on the field → explain stealing weapons.
	var pickups := get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP)
	if pickups and pickups.get_child_count() > 0 and not Settings.tutorials_done.has(ECHO_STEP["id"]):
		_show(ECHO_STEP)


func _show(step: Dictionary) -> void:
	_step = step
	active_id = step["id"]
	_progress = 0.0
	_shown_for = 0.0
	_text.text = step["text"]
	_refresh_glyph()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, ArtStyle.T_MED)


func _dismiss() -> void:
	active_id = ""
	_delay = 0.7
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 0.0, ArtStyle.T_MED)


func _hide() -> void:
	_card.modulate.a = 0.0


func _step_satisfied(delta: float) -> bool:
	match active_id:
		"move":
			if Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up").length() > 0.3:
				_progress += delta
		"fire":
			if Input.is_action_pressed(&"fire"):
				_progress += delta
		"hull_steer":
			if absf(Input.get_axis(&"move_left", &"move_right")) > 0.3:
				_progress += delta
		"dash", "mech_dash", "hull_boost":
			return Input.is_action_just_pressed(&"dash")
		"mech_move":
			if absf(Input.get_axis(&"move_left", &"move_right")) > 0.3:
				_progress += delta
		"mech_jump":
			return Input.is_action_just_pressed(&"jump")
		"mech_double_jump":
			var player := Players.find(get_tree())
			return player != null and int(player.get(&"double_jumps")) > 0
		"super":
			return Input.is_action_just_pressed(&"special")
		"echo_core":
			return RunSession.selected_echo != RunSession.NO_ECHO
	return _progress >= float(_step.get("hold", 0.0)) and float(_step.get("hold", 0.0)) > 0.0


## Keeps the card off the ship: flips to the top safe area when the ship is below.
func _avoid_player(player: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen := camera.unproject_position(player.global_position)
	var view := get_viewport_rect().size
	var low := screen.y < view.y * (LOW_Y - 0.14)
	var target_y := view.y * (LOW_Y if low else HIGH_Y + 0.07)
	_card.position.y = lerpf(_card.position.y, target_y - _card.size.y * 0.5, 0.2)
	_card.position.x = (view.x - _card.size.x) * 0.5


func _set_pad(pad: bool) -> void:
	if pad == _using_pad:
		return
	_using_pad = pad
	_refresh_glyph()


func _refresh_glyph() -> void:
	var glyph: String = _step.get("pad" if _using_pad else "key", "")
	_glyph.visible = not glyph.is_empty()
	_glyph_label.text = glyph
	var cap := _glyph.get_theme_stylebox(&"panel") as StyleBoxFlat
	cap.set_corner_radius_all(18 if _using_pad else 6)


func _build() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.panel(Palette.UI_GOLD, 0.0, 0.85)
	style.content_margin_left = 18.0
	style.content_margin_right = 26.0
	_card.add_theme_stylebox_override(&"panel", style)
	_card.modulate.a = 0.0
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(row)
	_glyph = PanelContainer.new()
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color("dfe9f5")
	cap.border_width_bottom = 4
	cap.border_color = Color("7f93a8")
	cap.set_corner_radius_all(6)
	cap.content_margin_left = 12.0
	cap.content_margin_right = 12.0
	cap.content_margin_top = 2.0
	cap.content_margin_bottom = 4.0
	_glyph.add_theme_stylebox_override(&"panel", cap)
	row.add_child(_glyph)
	_glyph_label = UiStyle.label("", ArtStyle.FONT_BODY, Palette.UI_DARK_PANEL)
	_glyph_label.remove_theme_constant_override(&"outline_size")
	_glyph.add_child(_glyph_label)
	_text = UiStyle.label("", ArtStyle.FONT_BODY + 2, Palette.PLAYER_PRIMARY)
	row.add_child(_text)
	_card.position = Vector2(760, 820)
