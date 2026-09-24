extends CanvasLayer
## Heads-up display. Reads RunSession signals only; never touches gameplay nodes.

@onready var _health_segments: HBoxContainer = %HealthSegments
@onready var _energy_segments: HBoxContainer = %EnergySegments
@onready var _score_label: Label = %ScoreLabel
@onready var _echo_label: Label = %EchoLabel
@onready var _pause_label: Label = %PauseLabel


func _ready() -> void:
	RunSession.health_changed.connect(_on_health_changed)
	RunSession.score_changed.connect(_on_score_changed)
	RunSession.energy_changed.connect(_on_energy_changed)
	RunSession.echo_changed.connect(_on_echo_changed)
	RunSession.echo_ammo_changed.connect(_on_echo_ammo_changed)
	_on_health_changed(RunSession.health, RunSession.max_health)
	_on_score_changed(RunSession.score)
	_on_energy_changed(RunSession.energy)
	_on_echo_changed(RunSession.selected_echo)
	set_paused(false)


func set_paused(paused: bool) -> void:
	_pause_label.visible = paused


func _on_health_changed(current: int, maximum: int) -> void:
	_rebuild_segments(_health_segments, maximum, SegmentPip.Shape.BAR, Palette.HEALTH)
	_fill_segments(_health_segments, current)


func _on_energy_changed(segments: int) -> void:
	_rebuild_segments(_energy_segments, RunSession.MAX_ENERGY, SegmentPip.Shape.DIAMOND, Palette.ENERGY)
	_fill_segments(_energy_segments, segments)


func _on_score_changed(score: int) -> void:
	_score_label.text = "%08d" % score


func _on_echo_changed(_echo_id: StringName) -> void:
	_refresh_echo()


func _on_echo_ammo_changed(_ammo: int) -> void:
	_refresh_echo()


## Active echo weapon in its module color, with shots left; low ammo turns red.
func _refresh_echo() -> void:
	var data := EchoModules.get_data(RunSession.selected_echo)
	if data == null:
		_echo_label.text = "WEAPON: BASIC"
		_echo_label.add_theme_color_override(&"font_color", Color(0.75, 0.85, 0.95))
		return
	_echo_label.text = "%s  ×%d" % [data.display_name, RunSession.echo_ammo]
	var low := RunSession.echo_ammo <= data.ammo / 5
	_echo_label.add_theme_color_override(&"font_color", Palette.DANGER if low else data.module_color)


func _rebuild_segments(container: HBoxContainer, count: int, shape: SegmentPip.Shape, color: Color) -> void:
	if container.get_child_count() == count:
		return
	for child in container.get_children():
		child.queue_free()
		container.remove_child(child)
	for i in count:
		var pip := SegmentPip.new()
		pip.shape = shape
		pip.fill_color = color
		container.add_child(pip)


func _fill_segments(container: HBoxContainer, filled_count: int) -> void:
	for i in container.get_child_count():
		(container.get_child(i) as SegmentPip).filled = i < filled_count
