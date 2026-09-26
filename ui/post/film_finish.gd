class_name FilmFinish
extends ColorRect
## Full-screen finish under the HUD. Desktop (Forward+): film_finish.gdshader (edge chromatic
## aberration, grain, vignette, hurt pulse). Web / mobile: the plain vignette. Reads RunSession's
## health signal for the hurt pulse; owns no game state.

var _mat: ShaderMaterial
var _pulse: float = 0.0
var _last_health: int = -1
var _full: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_full = Settings.supports_high_graphics()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://art/shaders/film_finish.gdshader") if _full else preload("res://art/shaders/vignette.gdshader")
	material = _mat
	RunSession.health_changed.connect(_on_health_changed)
	RunSession.run_reset.connect(func() -> void: _last_health = -1)


func _on_health_changed(current: int, _maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		_pulse = 1.0
	_last_health = current


func _process(delta: float) -> void:
	if not _full:
		return
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	_mat.set_shader_parameter(&"pulse", _pulse * ArtStyle.flash_scale())
