extends Node3D
## Title screen: the cinematic 3D shot (TitleBackdrop) under the logo, menu and start prompt.
## The logo, tagline and menu animate in. Main listens for `start_requested`; no gameplay here.

signal start_requested
## Stage select: 1 = shooter, 2 = warship, 3 = hull run. Main starts the campaign there.
signal stage_requested(stage: int)

const STAGES: Array[String] = ["Stage 1 — Orbital Riptide", "Stage 2 — Warship Infiltration", "Stage 3 — Hull Run", "Stage 4 — Pixel Riptide (8-bit)"]

var _prompt: Label
var _menu: VBoxContainer
var _options: OptionsPanel
var _stage_menu: VBoxContainer
var _stage_first: UiMenuButton
var _start: UiMenuButton
var _time: float = 0.0
var _logo: Label
var _sub: Label
var _rule: ColorRect


func _ready() -> void:
	AudioService.play_music(&"title")
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.anchor_left = 0.07
	column.anchor_top = 0.16
	column.anchor_right = 0.6
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	_logo = Label.new()
	_logo.text = "ECHOES OF KHARON"
	UiStyle.style_title(_logo, 92, Palette.PLAYER_PRIMARY, 8)
	column.add_child(_logo)
	_rule = ColorRect.new()
	_rule.custom_minimum_size = Vector2(1220, 4)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_rule.color = Palette.PLAYER_PRIMARY
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rule)
	_sub = Label.new()
	_sub.text = "DEFINITE SPACE SAGA"
	var sub_font := FontVariation.new()
	sub_font.base_font = UiStyle.BOLD_FONT
	sub_font.spacing_glyph = 14
	_sub.add_theme_font_override(&"font", sub_font)
	UiStyle.style_label(_sub, 36, Palette.UI_GOLD)
	column.add_child(_sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 70)
	column.add_child(spacer)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_menu)
	_start = UiMenuButton.new()
	_start.text = "START"
	_start.pressed.connect(func() -> void: start_requested.emit())
	_menu.add_child(_start)
	var select := UiMenuButton.new()
	select.text = "SELECT STAGE"
	select.pressed.connect(_open_stage_select)
	_menu.add_child(select)
	var options := UiMenuButton.new()
	options.text = "OPTIONS"
	options.pressed.connect(_open_options)
	_menu.add_child(options)
	_stage_menu = VBoxContainer.new()
	_stage_menu.add_theme_constant_override(&"separation", 10)
	_stage_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stage_menu.visible = false
	column.add_child(_stage_menu)
	for i in STAGES.size():
		var button := UiMenuButton.new()
		button.text = STAGES[i].to_upper()
		button.pressed.connect(func() -> void: stage_requested.emit(i + 1))
		_stage_menu.add_child(button)
		if i == 0:
			_stage_first = button
	var back := UiMenuButton.new()
	back.text = "BACK"
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
	var credit := UiStyle.label("v1.0   ·   © 2026 ECHOES OF KHARON", ArtStyle.FONT_CAPTION, Color(Palette.UI_MUTED_TEXT, 0.7))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.offset_left = -620
	credit.offset_top = -56
	credit.offset_right = -40
	credit.offset_bottom = -24
	root.add_child(credit)
	_start.grab_focus.call_deferred()
	_animate_in()


## Logo slides in with a flash of glow, the rule wipes across, the tagline types on, the menu
## items drop in one after another.
func _animate_in() -> void:
	if Settings.reduced_motion:
		return
	_logo.modulate.a = 0.0
	_logo.position.x = -60.0
	_rule.scale.x = 0.0
	_sub.visible_ratio = 0.0
	var buttons := _menu.get_children()
	for b in buttons:
		(b as Control).modulate.a = 0.0
	_prompt.visible = false
	var tween := create_tween().set_parallel()
	tween.tween_property(_logo, "modulate:a", 1.0, 0.6).set_delay(0.3)
	tween.tween_property(_logo, "position:x", 0.0, 0.9).set_delay(0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rule, "scale:x", 1.0, 0.7).set_delay(0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sub, "visible_ratio", 1.0, 0.8).set_delay(1.0)
	for i in buttons.size():
		tween.tween_property(buttons[i], "modulate:a", 1.0, 0.35).set_delay(1.5 + i * 0.12)
	tween.chain().tween_callback(func() -> void: _prompt.visible = true)


func _process(delta: float) -> void:
	_time += delta
	if _logo and not Settings.reduced_motion:
		# The logo glow breathes.
		_logo.add_theme_color_override(&"font_shadow_color", Color(Palette.PLAYER_ENERGY, 0.55 + 0.25 * sin(_time * 1.6)))
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
