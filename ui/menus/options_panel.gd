class_name OptionsPanel
extends VBoxContainer
## Accessibility and video options, bound directly to Settings.

signal closed

const OPTIONS: Array[Array] = [
	[&"reduced_flash", "Reduced flash"],
	[&"reduced_shake", "Reduced camera shake"],
	[&"reduced_motion", "Reduced menu motion"],
	[&"glow_enabled", "Glow"],
	[&"tutorials_enabled", "Tutorial cards"],
]

var _first: Control


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	add_child(UiStyle.label("OPTIONS", ArtStyle.FONT_TITLE - 16, Palette.PLAYER_PRIMARY))
	for option in OPTIONS:
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
