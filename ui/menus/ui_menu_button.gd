class_name UiMenuButton
extends Button
## Menu button in the shared panel language. Focus (keyboard/controller) and hover look the
## same: gold edge, brighter plate, a short slide-in (skipped with reduced motion).

const SLIDE := 10.0

var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(420, 58)
	add_theme_font_size_override(&"font_size", ArtStyle.FONT_BODY + 4)
	add_theme_color_override(&"font_color", Palette.UI_MUTED_TEXT)
	add_theme_color_override(&"font_focus_color", Palette.PLAYER_PRIMARY)
	add_theme_color_override(&"font_hover_color", Palette.PLAYER_PRIMARY)
	add_theme_color_override(&"font_pressed_color", Palette.UI_GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.BG_BLUE, 0.35)
	normal.set_corner_radius_all(ArtStyle.UI_CORNER)
	normal.content_margin_left = 22.0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(Palette.PLAYER_SECONDARY, 0.28)
	focus.border_width_left = 5
	focus.border_color = Palette.UI_GOLD
	add_theme_stylebox_override(&"normal", normal)
	add_theme_stylebox_override(&"hover", focus)
	add_theme_stylebox_override(&"focus", focus)
	add_theme_stylebox_override(&"pressed", focus)
	focus_entered.connect(_on_highlight.bind(true))
	focus_exited.connect(_on_highlight.bind(false))
	mouse_entered.connect(grab_focus)


func _on_highlight(on: bool) -> void:
	if Settings.reduced_motion:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target := SLIDE if on else 0.0
	var style := get_theme_stylebox(&"focus") as StyleBoxFlat
	_tween.tween_property(style, "content_margin_left", 22.0 + target, ArtStyle.T_FAST)
