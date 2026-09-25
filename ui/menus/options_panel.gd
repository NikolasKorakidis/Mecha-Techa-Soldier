class_name OptionsPanel
extends VBoxContainer
## Accessibility and video options, bound directly to Settings.

signal closed

const OPTIONS: Array[Array] = [
	[&"reduced_flash", "Reduced flash"],
	[&"reduced_shake", "Reduced camera shake"],
	[&"reduced_motion", "Reduced menu motion"],
	[&"glow_enabled", "Glow"],
	[&"high_graphics", "High graphics (shadows, SSAO, more particles)"],
	[&"tutorials_enabled", "Tutorial cards"],
]

var _first: Control


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	add_child(UiStyle.label("OPTIONS", ArtStyle.FONT_TITLE - 16, Palette.PLAYER_PRIMARY))
	for volume: Array in [[&"music_volume", "Music volume"], [&"sfx_volume", "Effects volume"]]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(420, 48)
		var label := UiStyle.label(volume[1], ArtStyle.FONT_BODY, Palette.UI_MUTED_TEXT)
		label.custom_minimum_size = Vector2(200, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.get(volume[0]))
		slider.focus_mode = Control.FOCUS_ALL
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v: float) -> void:
			Settings.set_option(volume[0], v)
			AudioService.play(&"ui_move"))
		row.add_child(slider)
		add_child(row)
		if _first == null:
			_first = slider
	for option in OPTIONS:
		if option[0] == &"high_graphics" and not Settings.supports_high_graphics():
			continue
		var toggle := CheckButton.new()
		toggle.text = option[1]
		toggle.button_pressed = bool(Settings.get(option[0]))
		toggle.focus_mode = Control.FOCUS_ALL
		toggle.custom_minimum_size = Vector2(420, 48)
		toggle.add_theme_font_size_override(&"font_size", ArtStyle.FONT_BODY)
		toggle.add_theme_color_override(&"font_focus_color", Palette.UI_GOLD)
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_option(option[0], on))
		add_child(toggle)
		if _first == null:
			_first = toggle
	var back := UiMenuButton.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)


func focus_first() -> void:
	if _first:
		_first.grab_focus()
