class_name FlashComponent
extends Node
## Hit feedback on a visual node.
## BLINK toggles visibility.
## OVERLAY paints every mesh under the target bright white for a moment (enemy hits).
## TINT_BLINK alternates a translucent tint on and off, so the silhouette never disappears
## (player invulnerability window).

enum Mode { BLINK, OVERLAY, TINT_BLINK }

const OVERLAY_COLOR := Color(1.0, 1.0, 1.0, 0.6)
## Under sustained fire the overlay strobes instead of staying solid white.
const OVERLAY_MIN_GAP := 0.1

@export var target: Node3D
@export var mode: Mode = Mode.BLINK
@export var interval: float = 0.07

const TINT_COLOR := Color(0.75, 0.95, 1.0, 0.55)

static var _overlay_material: StandardMaterial3D
static var _tint_material: StandardMaterial3D

var _tinted: bool = false

var _time_left: float = 0.0
var _toggle_left: float = 0.0
var _overlay_cooldown: float = 0.0


func flash(duration: float) -> void:
	if mode == Mode.OVERLAY:
		if _overlay_cooldown > 0.0:
			return
		_overlay_cooldown = duration + OVERLAY_MIN_GAP
		_set_overlay(true)
	_time_left = duration
	_toggle_left = interval


func stop() -> void:
	_time_left = 0.0
	if target:
		target.visible = true
	if mode == Mode.OVERLAY:
		_set_overlay(false)
	elif mode == Mode.TINT_BLINK:
		_set_tint(false)


func is_flashing() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	_overlay_cooldown = maxf(0.0, _overlay_cooldown - delta)
	if _time_left <= 0.0 or target == null:
		return
	_time_left -= delta
	if mode == Mode.BLINK or mode == Mode.TINT_BLINK:
		_toggle_left -= delta
		if _toggle_left <= 0.0:
			_toggle_left = interval
			if mode == Mode.BLINK:
				target.visible = not target.visible
			else:
				_set_tint(not _tinted)
	if _time_left <= 0.0:
		stop()


func _set_overlay(enabled: bool) -> void:
	if target == null:
		return
	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_material.albedo_color = OVERLAY_COLOR
	_overlay_material.albedo_color.a = OVERLAY_COLOR.a * ArtStyle.flash_scale()
	for node in target.find_children("*", "GeometryInstance3D", true, false):
		if node.name == &"Outline":
			continue
		(node as GeometryInstance3D).material_overlay = _overlay_material if enabled else null


func _set_tint(enabled: bool) -> void:
	_tinted = enabled
	if target == null:
		return
	if _tint_material == null:
		_tint_material = StandardMaterial3D.new()
		_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_material.albedo_color = TINT_COLOR
	var tint := Color(TINT_COLOR, TINT_COLOR.a * ArtStyle.flash_scale())
	_tint_material.albedo_color = tint
	for node in target.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if geo.name == &"Outline" or (geo is MeshInstance3D and (geo as MeshInstance3D).mesh is QuadMesh):
			continue  # Leave outlines and glows alone.
		geo.material_overlay = _tint_material if enabled else null
