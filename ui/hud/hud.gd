extends CanvasLayer
## Heads-up display. Reads RunSession signals only; never touches gameplay nodes.
## Top-left status cluster (health, energy, echo) and top-right score cluster share one
## panel language; the HUD lives on its own layer so it never shakes or glows.

const HEALTH_PIP := Vector2(24, 30)
const ENERGY_PIP := Vector2(24, 24)

var _health_segments: HBoxContainer
var _energy_segments: HBoxContainer
var _echo_icon: EchoIcon
var _echo_label: Label
var _ammo_label: Label
var _score_label: Label
var _score_value: int = 0
var _score_shown: float = 0.0

@onready var _pause_label: Label = %PauseLabel


func _ready() -> void:
	_build()
	RunSession.health_changed.connect(_on_health_changed)
	RunSession.score_changed.connect(_on_score_changed)
	RunSession.energy_changed.connect(_on_energy_changed)
	RunSession.echo_changed.connect(_on_echo_changed)
	RunSession.echo_ammo_changed.connect(_on_echo_ammo_changed)
	RunSession.run_reset.connect(_on_run_reset)
	_sync_all(false)
	set_paused(false)


func set_paused(paused: bool) -> void:
	_pause_label.visible = paused


func _process(delta: float) -> void:
	# Score rolls up quickly instead of jumping.
	if _score_shown < _score_value:
		_score_shown = minf(_score_value, _score_shown + maxf(40.0, (_score_value - _score_shown) * 10.0) * delta)
		_score_label.text = "%08d" % int(_score_shown)


func _sync_all(animate: bool) -> void:
	_set_health(RunSession.health, RunSession.max_health, animate)
	_set_energy(RunSession.energy, animate)
	_refresh_echo()
	_score_value = RunSession.score
	_score_shown = RunSession.score
	_score_label.text = "%08d" % _score_value


func _on_run_reset() -> void:
	_sync_all(false)


func _on_health_changed(current: int, maximum: int) -> void:
	_set_health(current, maximum, true)


func _on_energy_changed(segments: int) -> void:
	_set_energy(segments, true)


func _on_score_changed(score: int) -> void:
	_score_value = score
	if score < _score_shown:
		_score_shown = score
		_score_label.text = "%08d" % score


func _on_echo_changed(_echo_id: StringName) -> void:
	_refresh_echo()


func _on_echo_ammo_changed(_ammo: int) -> void:
	_refresh_echo()


func _set_health(current: int, maximum: int, animate: bool) -> void:
	_ensure_pips(_health_segments, maximum, SegmentPip.Shape.BAR, Palette.HEALTH_GREEN, HEALTH_PIP)
	for i in _health_segments.get_child_count():
		var pip := _health_segments.get_child(i) as SegmentPip
		pip.set_filled(i < current, animate)
		pip.pulse = current == 1 and i == 0


func _set_energy(segments: int, animate: bool) -> void:
	_ensure_pips(_energy_segments, RunSession.MAX_ENERGY, SegmentPip.Shape.DIAMOND, Palette.RESONANCE_VIOLET, ENERGY_PIP)
	for i in _energy_segments.get_child_count():
		(_energy_segments.get_child(i) as SegmentPip).set_filled(i < segments, animate)


## Active echo in its module color with shots left; low ammo turns red. Empty = "ECHO: NONE".
func _refresh_echo() -> void:
	var data := EchoModules.get_data(RunSession.selected_echo)
	_echo_icon.echo_id = RunSession.selected_echo
	if data == null:
		_echo_label.text = "ECHO: NONE"
		_echo_label.add_theme_color_override(&"font_color", Palette.UI_MUTED_TEXT)
		_ammo_label.text = ""
		return
	_echo_label.text = "ECHO: %s" % data.display_name
	_echo_label.add_theme_color_override(&"font_color", data.module_color)
	_ammo_label.text = "×%d" % RunSession.echo_ammo
	var low := RunSession.echo_ammo <= data.ammo / 5
	_ammo_label.add_theme_color_override(&"font_color", Palette.DANGER if low else Palette.PLAYER_PRIMARY)


func _ensure_pips(container: HBoxContainer, count: int, shape: SegmentPip.Shape, color: Color, pip_size: Vector2) -> void:
	if container.get_child_count() == count:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for i in count:
		var pip := SegmentPip.new()
		pip.shape = shape
		pip.fill_color = color
		pip.custom_minimum_size = pip_size
		pip.filled = false
		container.add_child(pip)


func _build() -> void:
	var margin := %Margin as MarginContainer
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)
	margin.move_child(top, 0)

	# Status cluster.
	var status := PanelContainer.new()
	status.name = "StatusPanel"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_stylebox_override(&"panel", UiStyle.panel(Palette.PLAYER_ENERGY, ArtStyle.UI_SKEW))
	top.add_child(status)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 6)
	status.add_child(rows)
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override(&"separation", 28)
	rows.add_child(meters)
	_health_segments = HBoxContainer.new()
	_health_segments.name = "HealthSegments"
	_health_segments.add_theme_constant_override(&"separation", 4)
	meters.add_child(_health_segments)
	_energy_segments = HBoxContainer.new()
	_energy_segments.name = "EnergySegments"
	_energy_segments.alignment = BoxContainer.ALIGNMENT_CENTER
	_energy_segments.add_theme_constant_override(&"separation", 2)
	meters.add_child(_energy_segments)
	var echo_row := HBoxContainer.new()
	echo_row.add_theme_constant_override(&"separation", 10)
	rows.add_child(echo_row)
	_echo_icon = EchoIcon.new()
	echo_row.add_child(_echo_icon)
	_echo_label = UiStyle.label("ECHO: NONE", ArtStyle.FONT_BODY, Palette.UI_MUTED_TEXT)
	echo_row.add_child(_echo_label)
	_ammo_label = UiStyle.label("", ArtStyle.FONT_BODY, Palette.PLAYER_PRIMARY)
	_ammo_label.add_theme_font_override(&"font", UiStyle.tabular_font())
	echo_row.add_child(_ammo_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	# Score cluster.
	var score := PanelContainer.new()
	score.name = "ScorePanel"
	score.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score.add_theme_stylebox_override(&"panel", UiStyle.panel(Palette.UI_GOLD, -ArtStyle.UI_SKEW))
	top.add_child(score)
	var score_col := VBoxContainer.new()
	score_col.add_theme_constant_override(&"separation", -4)
	score.add_child(score_col)
	var caption := UiStyle.label("SCORE", ArtStyle.FONT_CAPTION, Palette.UI_MUTED_TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_col.add_child(caption)
	_score_label = UiStyle.label("00000000", ArtStyle.FONT_VALUE, Palette.PLAYER_PRIMARY)
	_score_label.add_theme_font_override(&"font", UiStyle.tabular_font())
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_col.add_child(_score_label)
