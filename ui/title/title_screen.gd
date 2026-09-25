extends Node3D
## Minimal title card: the Kestrel over the Orbital Riptide backdrop, logo, and a start prompt.
## Main listens for `start_requested`; no gameplay runs here.

signal start_requested
## Stage select: 1 = shooter, 2 = warship, 3 = hull run. Main starts the campaign there.
signal stage_requested(stage: int)

const STAGES: Array[String] = ["Stage 1 — Orbital Riptide", "Stage 2 — Warship Infiltration", "Stage 3 — Hull Run"]

var _prompt: Label
var _menu: VBoxContainer
var _options: OptionsPanel
var _stage_menu: VBoxContainer
var _stage_first: UiMenuButton
var _start: UiMenuButton
var _time: float = 0.0

@onready var _ship: Node3D = %Kestrel


func _ready() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.anchor_left = 0.08
	column.anchor_top = 0.2
	column.anchor_right = 0.5
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var logo := UiStyle.label("SHIFT//WING", 132, Palette.PLAYER_PRIMARY)
	column.add_child(logo)
	var sub := UiStyle.label("ECHOES OF KHARON", 34, Palette.UI_GOLD)
	column.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	column.add_child(spacer)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_menu)
	_start = UiMenuButton.new()
	_start.text = "Start"
	_start.pressed.connect(func() -> void: start_requested.emit())
	_menu.add_child(_start)
	var select := UiMenuButton.new()
	select.text = "Select Stage"
	select.pressed.connect(_open_stage_select)
	_menu.add_child(select)
	var options := UiMenuButton.new()
	options.text = "Options"
	options.pressed.connect(_open_options)
	_menu.add_child(options)
	_stage_menu = VBoxContainer.new()
	_stage_menu.add_theme_constant_override(&"separation", 10)
	_stage_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stage_menu.visible = false
	column.add_child(_stage_menu)
	for i in STAGES.size():
		var button := UiMenuButton.new()
		button.text = STAGES[i]
		button.pressed.connect(func() -> void: stage_requested.emit(i + 1))
		_stage_menu.add_child(button)
		if i == 0:
			_stage_first = button
	var back := UiMenuButton.new()
	back.text = "Back"
	back.pressed.connect(_close_stage_select)
	_stage_menu.add_child(back)
	_options = OptionsPanel.new()
	_options.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_options.visible = false
	_options.closed.connect(_close_options)
	column.add_child(_options)
	_prompt = UiStyle.label("PRESS FIRE / ENTER / A", ArtStyle.FONT_BODY, Palette.UI_MUTED_TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -110
	_prompt.offset_bottom = -70
	root.add_child(_prompt)
	_start.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _ship:
		_ship.position.y = -1.0 + sin(_time * 1.3) * 0.35
		_ship.rotation.x = sin(_time * 0.9) * 0.12
	if not Settings.reduced_motion:
		_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if _stage_menu.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_stage_select()
			get_viewport().set_input_as_handled()
		return
	if _options.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_options()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"fire"):
		get_viewport().set_input_as_handled()
		start_requested.emit()


func _open_stage_select() -> void:
	_menu.visible = false
	_stage_menu.visible = true
	_stage_first.grab_focus()


func _close_stage_select() -> void:
	_stage_menu.visible = false
	_menu.visible = true
	_start.grab_focus()


func _open_options() -> void:
	_menu.visible = false
	_options.visible = true
	_options.focus_first()


func _close_options() -> void:
	_options.visible = false
	_menu.visible = true
	_start.grab_focus()
