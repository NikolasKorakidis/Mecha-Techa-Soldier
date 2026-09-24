class_name StageUI
extends CanvasLayer
## Level-owned overlay: stage banners, WARNING, short prompts and the boss health bar.
## Reads only the level's own actors (director calls in, boss signals); owns no game state.

const WARNING_RED := Color("ff3b4a")

var _banner: VBoxContainer
var _banner_title: Label
var _banner_subtitle: Label
var _warning: VBoxContainer
var _prompt: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_ghost: ProgressBar
var _banner_tween: Tween
var _prompt_tween: Tween
var _warning_left: float = 0.0


func _ready() -> void:
	layer = 8
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_banner = _centered_column(root, 0.38)
	_banner_title = _label(_banner, 96, Color.WHITE)
	_banner_subtitle = _label(_banner, 34, Color("9fe8ff"))
	_banner.modulate.a = 0.0

	_warning = _centered_column(root, 0.4)
	_label(_warning, 120, WARNING_RED).text = "WARNING"
	_label(_warning, 30, Color("ffd0d4")).text = "HOSTILE GUARDIAN APPROACHING"
	_warning.visible = false

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.position = Vector2(-600, 120)
	_prompt.size = Vector2(1200, 60)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_prompt, 34, Color("ffe08a"))
	_prompt.modulate.a = 0.0
	root.add_child(_prompt)

	_build_boss_bar(root)


func show_banner(title: String, subtitle: String, duration: float) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(maxf(0.1, duration - 0.9))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.55)


func show_warning(duration: float) -> void:
	_warning.visible = true
	_warning_left = duration


func show_prompt(text: String) -> void:
	_prompt.text = text
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.2)
	_prompt_tween.tween_interval(2.4)
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.5)


func track_boss(boss: BossBase) -> void:
	_boss_name.text = boss.boss_name
	_boss_bar.max_value = boss.max_health
	_boss_ghost.max_value = boss.max_health
	_boss_bar.value = boss.max_health
	_boss_ghost.value = boss.max_health
	_boss_panel.visible = true
	boss.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(func() -> void: _boss_panel.visible = false)


func is_warning_visible() -> bool:
	return _warning.visible


func _process(delta: float) -> void:
	if _warning.visible:
		_warning_left -= delta
		_warning.modulate.a = 0.55 + 0.45 * absf(sin(_warning_left * 6.0))
		if _warning_left <= 0.0:
			_warning.visible = false
	if _boss_panel.visible and _boss_ghost.value > _boss_bar.value:
		# Trailing "damage taken" bar.
		_boss_ghost.value = maxf(_boss_bar.value, _boss_ghost.value - _boss_ghost.max_value * 0.25 * delta)


func _on_boss_health_changed(current: int, _maximum: int) -> void:
	_boss_bar.value = current


func _build_boss_bar(root: Control) -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_panel.position = Vector2(-520, -110)
	_boss_panel.size = Vector2(1040, 80)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.06, 0.7)
	style.border_width_top = 3
	style.border_color = WARNING_RED
	style.set_corner_radius_all(6)
	style.skew = Vector2(0.2, 0)
	style.set_content_margin_all(12)
	_boss_panel.add_theme_stylebox_override(&"panel", style)
	root.add_child(_boss_panel)
	var column := VBoxContainer.new()
	_boss_panel.add_child(column)
	_boss_name = _label(column, 26, Color("ffd0d4"))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(1000, 22)
	column.add_child(bars)
	_boss_ghost = _bar(bars, Color(1, 1, 1, 0.55))
	_boss_bar = _bar(bars, WARNING_RED)
	_boss_panel.visible = false


func _bar(parent: Control, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.0)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fg)
	parent.add_child(bar)
	return bar


func _centered_column(root: Control, height_ratio: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.anchor_top = height_ratio - 0.12
	column.anchor_bottom = height_ratio + 0.12
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	return column


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, font_size, color)
	parent.add_child(label)
	return label


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", maxi(6, font_size / 8))
