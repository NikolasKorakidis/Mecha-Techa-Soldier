class_name PauseMenu
extends CanvasLayer
## Pause overlay: dark scrim over the frozen (still faintly visible) playfield, a centered
## panel with Resume / Restart Stage / Controls / Options / Quit to Title. Runs while the tree
## is paused; gameplay, projectiles, particles and timers stay frozen underneath.

signal resume_requested
signal restart_requested
signal quit_requested

var is_open: bool = false

var _scrim: ColorRect
var _panel: PanelContainer
var _main_page: VBoxContainer
var _controls: ControlsPanel
var _options: OptionsPanel
var _resume: UiMenuButton
var _tween: Tween


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func open() -> void:
	is_open = true
	visible = true
	_show_page(_main_page)
	_resume.grab_focus()
	if _tween:
		_tween.kill()
	if Settings.reduced_motion:
		_scrim.modulate.a = 1.0
		_panel.modulate.a = 1.0
		return
	_scrim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.96
	_tween = create_tween().set_parallel()
	_tween.tween_property(_scrim, "modulate:a", 1.0, ArtStyle.T_FAST)
	_tween.tween_property(_panel, "modulate:a", 1.0, ArtStyle.T_MED)
	_tween.tween_property(_panel, "scale", Vector2.ONE, ArtStyle.T_MED).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	is_open = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _main_page.visible:
			resume_requested.emit()
		else:
			_show_page(_main_page)
			_resume.grab_focus()


func _show_page(page: Control) -> void:
	for p in [_main_page, _controls, _options]:
		p.visible = p == page
	_panel.reset_size()
	_center_panel()


func _center_panel() -> void:
	var view := _panel.get_viewport_rect().size
	_panel.pivot_offset = _panel.size * 0.5
	_panel.position = (view - _panel.size) * 0.5


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0.01, 0.02, 0.06, 0.66)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	_panel = PanelContainer.new()
	var style := UiStyle.panel(Palette.PLAYER_ENERGY, 0.0, 0.92)
	style.content_margin_left = 44.0
	style.content_margin_right = 44.0
	style.content_margin_top = 30.0
	style.content_margin_bottom = 34.0
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	var pages := VBoxContainer.new()
	_panel.add_child(pages)

	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override(&"separation", 10)
	pages.add_child(_main_page)
	var title := UiStyle.label("PAUSED", ArtStyle.FONT_TITLE, Palette.PLAYER_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_page.add_child(title)
	var rule := ColorRect.new()
	rule.color = Palette.UI_GOLD
	rule.custom_minimum_size = Vector2(0, 3)
	_main_page.add_child(rule)
	_resume = _button("Resume", func() -> void: resume_requested.emit())
	_button("Restart Stage", func() -> void: restart_requested.emit())
	_button("Controls", func() -> void:
		_show_page(_controls)
		_controls.focus_first())
	_button("Options", func() -> void:
		_show_page(_options)
		_options.focus_first())
	_button("Quit to Title", func() -> void: quit_requested.emit())

	_controls = ControlsPanel.new()
	_controls.closed.connect(func() -> void:
		_show_page(_main_page)
		_resume.grab_focus())
	pages.add_child(_controls)
	_options = OptionsPanel.new()
	_options.closed.connect(func() -> void:
		_show_page(_main_page)
		_resume.grab_focus())
	pages.add_child(_options)


func _button(text: String, action: Callable) -> UiMenuButton:
	var button := UiMenuButton.new()
	button.text = text
	button.pressed.connect(action)
	_main_page.add_child(button)
	return button
