class_name ScreenTransition
extends CanvasLayer
## Full-screen shutter wipe used by SceneRouter for every level change: plates sweep in, the
## logo holds while the next level mounts behind them, then the plates sweep out the far side.
## Owns no game state; SceneRouter drives it.

const COVER_TIME := 0.5
const REVEAL_TIME := 0.6

var covered: bool = false

var _rect: ColorRect
var _mat: ShaderMaterial
var _logo: Label
var _tween: Tween


func _init() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://art/shaders/shutter_wipe.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_logo = Label.new()
	_logo.text = "ECHOES OF KHARON"
	_logo.set_anchors_preset(Control.PRESET_CENTER)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_logo.grow_vertical = Control.GROW_DIRECTION_BOTH
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_set_phase(0.0)


func _ready() -> void:
	UiStyle.style_title(_logo, 54, Palette.PLAYER_PRIMARY, 10)


## Plates sweep in; resolves when the screen is fully covered.
func cover(duration: float = COVER_TIME) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _run(0.0, 1.0, duration)
	covered = true


## Plates sweep off the far side; resolves when the screen is clear.
func reveal(duration: float = REVEAL_TIME) -> void:
	covered = false
	await _run(1.0, 2.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_phase(0.0)


func _run(from: float, to: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_phase, from, to, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished


func _set_phase(value: float) -> void:
	_mat.set_shader_parameter(&"phase", value)
	_rect.visible = value > 0.0 and value < 2.0
	# The logo shows only while the plates are closed.
	var shown := clampf(1.0 - absf(value - 1.0) * 6.0, 0.0, 1.0)
	_logo.visible = shown > 0.0
	_logo.modulate.a = shown
	_logo.scale = Vector2.ONE * lerpf(1.08, 1.0, shown)
