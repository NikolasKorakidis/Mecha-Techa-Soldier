class_name StageUI
extends CanvasLayer
## Level-owned overlay: stage banners, WARNING, short prompts and the boss health bar.
## Reads only the level's own actors (director calls in, boss signals); owns no game state.

const WARNING_RED := Palette.DANGER
const BANNER_WIDTH := 1500.0
const BOSS_CARD_WIDTH := 760.0

var _banner: Control
var _banner_plate: Panel
var _banner_lines: Array[ColorRect] = []
var _banner_title: Label
var _banner_subtitle: Label
var _warning: Control
var _warning_title: Label
var _boss_card: Control
var _boss_card_plate: Panel
var _boss_card_name: Label
var _boss_card_tag: Label
var _boss_card_tween: Tween
var _prompt: Label
var _toast: PanelContainer
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_ghost: ProgressBar
var _banner_tween: Tween
var _prompt_tween: Tween
var _warning_left: float = 0.0
var _bars: Array[ColorRect] = []
var _flash: ColorRect
var _flash_tween: Tween
var _bars_tween: Tween


const GROUP := &"stage_ui"


static func find(tree: SceneTree) -> StageUI:
	return tree.get_first_node_in_group(GROUP) as StageUI


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	layer = 8
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_banner(root)
	_build_warning(root)
	_build_boss_card(root)

	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override(&"panel", UiStyle.panel(Palette.UI_GOLD, 0.0, 0.8))
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	_prompt = UiStyle.label("", ArtStyle.FONT_BODY, Palette.UI_GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_prompt)

	_build_boss_bar(root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		root.add_child(bar)
		_bars.append(bar)
	_set_bars(0.0)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)


## Full-screen white flash (transformations, big blasts), scaled by the reduced-flash option.
func flash(strength: float = 0.9, fade: float = 0.6, color: Color = Color.WHITE) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = Color(color.r, color.g, color.b, strength * ArtStyle.flash_scale())
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, fade)


## Cinematic letterbox (≈11% of the height top and bottom).
func letterbox(on: bool, duration: float = 0.6) -> void:
	if _bars_tween:
		_bars_tween.kill()
	_bars_tween = create_tween()
	_bars_tween.tween_method(_set_bars, _bars[0].offset_bottom / 1080.0, 0.11 if on else 0.0, duration)


func is_letterboxed() -> bool:
	return _bars[0].offset_bottom > 1.0


func _set_bars(ratio: float) -> void:
	var h := ratio * 1080.0
	_bars[0].offset_top = 0.0
	_bars[0].offset_bottom = h
	_bars[1].offset_top = -h
	_bars[1].offset_bottom = 0.0


## Title card: a skewed armour plate slams in from the left, accent rails wipe across, the title
## punches in with a glow, holds, and the plate shoots off to the right.
func show_banner(title: String, subtitle: String, duration: float) -> void:
	_banner_title.text = title
	_fit_font(_banner_title, title, BANNER_WIDTH - 180.0, 78)
	_banner_subtitle.text = subtitle
	_banner_subtitle.visible = not subtitle.is_empty()
	if _banner_tween:
		_banner_tween.kill()
	var motion := not Settings.reduced_motion
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_plate.position.x = -BANNER_WIDTH * 1.2 if motion else _banner_center_x()
	_banner_title.modulate.a = 0.0
	_banner_title.scale = Vector2.ONE * (1.18 if motion else 1.0)
	_banner_subtitle.modulate.a = 0.0
	for line in _banner_lines:
		line.scale.x = 0.0
	_banner_tween = create_tween()
	_banner_tween.set_parallel()
	_banner_tween.tween_property(_banner_plate, "position:x", _banner_center_x(), 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in _banner_lines.size():
		_banner_tween.tween_property(_banner_lines[i], "scale:x", 1.0, 0.45).set_delay(0.08 + i * 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_title, "modulate:a", 1.0, 0.18).set_delay(0.12)
	_banner_tween.tween_property(_banner_title, "scale", Vector2.ONE, 0.35).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_subtitle, "modulate:a", 1.0, 0.3).set_delay(0.28)
	_banner_tween.chain().tween_interval(maxf(0.2, duration - 1.0))
	_banner_tween.chain().set_parallel()
	_banner_tween.tween_property(_banner_plate, "position:x", 1920.0 + BANNER_WIDTH * 0.2 if motion else _banner_center_x(), 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.38)
	_banner_tween.chain().tween_callback(func() -> void: _banner.visible = false)


func show_warning(duration: float) -> void:
	AudioService.play(&"warning")
	_warning.visible = true
	_warning_left = duration


## Boss name card (Mega Man X-style): slides in from the right under the WARNING, holds, leaves.
func show_boss_card(boss_name: String, tagline: String = "GUARDIAN-CLASS WAR MACHINE") -> void:
	_boss_card_name.text = boss_name
	_fit_font(_boss_card_name, boss_name, BOSS_CARD_WIDTH - 110.0, 52)
	_boss_card_tag.text = tagline
	if _boss_card_tween:
		_boss_card_tween.kill()
	_boss_card.visible = true
	_boss_card.modulate.a = 1.0
	var home := 1920.0 - BOSS_CARD_WIDTH - 90.0
	_boss_card_plate.position.x = 1920.0 + 40.0
	_boss_card_tween = create_tween()
	_boss_card_tween.tween_property(_boss_card_plate, "position:x", home, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_boss_card_tween.tween_interval(2.6)
	_boss_card_tween.tween_property(_boss_card, "modulate:a", 0.0, 0.5)
	_boss_card_tween.tween_callback(func() -> void: _boss_card.visible = false)


## Short informational toast, centered between the HUD clusters (never over them).
func show_prompt(text: String) -> void:
	_prompt.text = text
	_toast.reset_size()
	var view := _toast.get_viewport_rect().size
	_toast.position = Vector2((view.x - _toast.size.x) * 0.5, 34)
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_toast, "modulate:a", 1.0, ArtStyle.T_MED)
	_prompt_tween.tween_interval(2.4)
	_prompt_tween.tween_property(_toast, "modulate:a", 0.0, ArtStyle.T_SLOW)


func track_boss(boss: BossBase) -> void:
	show_boss_card(boss.boss_name)
	_boss_name.text = boss.boss_name
	_boss_bar.max_value = boss.max_health
	_boss_ghost.max_value = boss.max_health
	_boss_bar.value = boss.max_health
	_boss_ghost.value = boss.max_health
	_boss_panel.visible = true
	boss.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(func() -> void: _boss_panel.visible = false)


## Boss bar for bosses that are not BossBase (hull-run gunship).
func track_generic(title: String, maximum: int, changed: Signal) -> void:
	_boss_name.text = title
	_boss_bar.max_value = maximum
	_boss_ghost.max_value = maximum
	_boss_bar.value = maximum
	_boss_ghost.value = maximum
	_boss_panel.visible = true
	changed.connect(_on_boss_health_changed)


func hide_generic() -> void:
	_boss_panel.visible = false


func is_warning_visible() -> bool:
	return _warning.visible


func _process(delta: float) -> void:
	if _warning.visible:
		_warning_left -= delta
		var swing := 0.45 * ArtStyle.flash_scale()
		_warning.modulate.a = 1.0 - swing + swing * absf(sin(_warning_left * 6.0))
		if _warning_left <= 0.0:
			_warning.visible = false
	if _boss_panel.visible and _boss_ghost.value > _boss_bar.value:
		# Trailing "damage taken" bar.
		_boss_ghost.value = maxf(_boss_bar.value, _boss_ghost.value - _boss_ghost.max_value * 0.25 * delta)


func _on_boss_health_changed(current: int, _maximum: int) -> void:
	_boss_bar.value = current


## Shrinks a label's font size until `text` fits `max_width` (long stage names).
func _fit_font(label: Label, text: String, max_width: float, base_size: int) -> void:
	var font := label.get_theme_font(&"font")
	var size := base_size
	while size > 24 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 2
	label.add_theme_font_size_override(&"font_size", size)


func _banner_center_x() -> float:
	return (1920.0 - BANNER_WIDTH) * 0.5


func _build_banner(root: Control) -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)
	_banner_plate = Panel.new()
	_banner_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_plate.size = Vector2(BANNER_WIDTH, 210)
	_banner_plate.position = Vector2(_banner_center_x(), 1080.0 * 0.38 - 105.0)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.015, 0.028, 0.06, 0.84)
	plate.skew = Vector2(0.28, 0)
	plate.border_width_left = 10
	plate.border_color = Palette.PLAYER_PRIMARY
	plate.shadow_color = Color(0, 0, 0, 0.45)
	plate.shadow_size = 18
	_banner_plate.add_theme_stylebox_override(&"panel", plate)
	_banner.add_child(_banner_plate)
	for i in 2:
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Palette.PLAYER_PRIMARY if i == 0 else Palette.UI_GOLD
		line.size = Vector2(BANNER_WIDTH - 60, 3)
		line.position = Vector2(40, 22 if i == 0 else 210 - 25)
		_banner_plate.add_child(line)
		_banner_lines.append(line)
	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_title.size = Vector2(BANNER_WIDTH, 120)
	_banner_title.position = Vector2(0, 32)
	_banner_title.pivot_offset = _banner_title.size * 0.5
	UiStyle.style_title(_banner_title, 78, Palette.PLAYER_PRIMARY, 8)
	_banner_plate.add_child(_banner_title)
	_banner_subtitle = Label.new()
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle.size = Vector2(BANNER_WIDTH, 44)
	_banner_subtitle.position = Vector2(0, 140)
	_banner_subtitle.add_theme_font_override(&"font", UiStyle.BOLD_FONT)
	_style_label(_banner_subtitle, 30, Palette.UI_GOLD)
	_banner_plate.add_child(_banner_subtitle)


func _build_warning(root: Control) -> void:
	_warning = Control.new()
	_warning.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.visible = false
	root.add_child(_warning)
	var center_y := 1080.0 * 0.4
	for i in 2:
		var band := ColorRect.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.size = Vector2(1920, 26)
		band.position = Vector2(0, center_y + (-112.0 if i == 0 else 86.0))
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://art/shaders/hazard_stripes.gdshader")
		mat.set_shader_parameter(&"direction", 1.0 if i == 0 else -1.0)
		band.material = mat
		_warning.add_child(band)
	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = Color(0.25, 0.0, 0.03, 0.55)
	plate.size = Vector2(1920, 172)
	plate.position = Vector2(0, center_y - 86.0)
	_warning.add_child(plate)
	_warning_title = Label.new()
	_warning_title.text = "WARNING"
	_warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_title.size = Vector2(1920, 130)
	_warning_title.position = Vector2(0, center_y - 90.0)
	UiStyle.style_title(_warning_title, 112, WARNING_RED, 22)
	_warning_title.add_theme_color_override(&"font_color", Color("ff5a64"))
	_warning.add_child(_warning_title)
	var sub := Label.new()
	sub.text = "HOSTILE GUARDIAN APPROACHING"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1920, 40)
	sub.position = Vector2(0, center_y + 38.0)
	sub.add_theme_font_override(&"font", UiStyle.BOLD_FONT)
	_style_label(sub, 28, Color("ffd0d4"))
	_warning.add_child(sub)


func _build_boss_card(root: Control) -> void:
	_boss_card = Control.new()
	_boss_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_card.visible = false
	root.add_child(_boss_card)
	_boss_card_plate = Panel.new()
	_boss_card_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_card_plate.size = Vector2(BOSS_CARD_WIDTH, 128)
	_boss_card_plate.position = Vector2(1920, 1080.0 * 0.6)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.01, 0.02, 0.86)
	style.skew = Vector2(-0.28, 0)
	style.border_width_right = 10
	style.border_width_bottom = 3
	style.border_color = WARNING_RED
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	_boss_card_plate.add_theme_stylebox_override(&"panel", style)
	_boss_card.add_child(_boss_card_plate)
	_boss_card_tag = Label.new()
	_boss_card_tag.position = Vector2(40, 14)
	_boss_card_tag.size = Vector2(BOSS_CARD_WIDTH - 80, 30)
	_boss_card_tag.add_theme_font_override(&"font", UiStyle.BOLD_FONT)
	_style_label(_boss_card_tag, 22, Color("ff9aa2"))
	_boss_card_plate.add_child(_boss_card_tag)
	_boss_card_name = Label.new()
	_boss_card_name.position = Vector2(36, 44)
	_boss_card_name.size = Vector2(BOSS_CARD_WIDTH - 72, 70)
	UiStyle.style_title(_boss_card_name, 52, WARNING_RED, 6)
	_boss_card_plate.add_child(_boss_card_name)


func _build_boss_bar(root: Control) -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_panel.position = Vector2(-520, -110)
	_boss_panel.size = Vector2(1040, 80)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.UI_DARK_PANEL, ArtStyle.UI_PANEL_ALPHA)
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
	_boss_name.add_theme_font_override(&"font", UiStyle.display_font(4, true))
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
