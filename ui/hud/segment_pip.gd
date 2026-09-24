class_name SegmentPip
extends Control
## One HUD segment with a dark empty container. Losing it flashes white, then it drains;
## gaining pops; `pulse` makes it breathe (last health segment).

enum Shape { BAR, DIAMOND }

@export var shape: Shape = Shape.BAR
@export var fill_color: Color = Palette.HEALTH_GREEN

var filled: bool = true
var pulse: bool = false:
	set(value):
		pulse = value
		queue_redraw()

var _flash: float = 0.0
var _pop: float = 0.0
var _time: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(22, 30)


## Changes state with a short animation (reduced-flash dims the white flash).
func set_filled(value: bool, animate: bool = true) -> void:
	if value == filled:
		return
	filled = value
	if animate:
		if filled:
			_pop = 1.0
		else:
			_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _flash <= 0.0 and _pop <= 0.0 and not pulse:
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta / ArtStyle.T_MED)
	_pop = maxf(0.0, _pop - delta / ArtStyle.T_MED)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var container := Color(0.02, 0.05, 0.1, 0.9)
	var edge := Color(Palette.UI_MUTED_TEXT, 0.25)
	var fill := fill_color
	if pulse and filled:
		fill = fill_color.lerp(Color.WHITE, 0.25 + 0.25 * sin(_time * 6.0))
	var grow := -3.0 + _pop * 2.0
	match shape:
		Shape.BAR:
			draw_rect(r.grow(-1.0), container)
			draw_rect(r.grow(-1.0), edge, false, 1.5)
			if filled:
				draw_rect(r.grow(grow), fill)
				draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 3)), Color(1, 1, 1, 0.35))
			if _flash > 0.0:
				draw_rect(r.grow(-3.0 + (1.0 - _flash) * -4.0), Color(1, 1, 1, _flash * ArtStyle.flash_scale()))
		Shape.DIAMOND:
			var c := r.get_center()
			var h := minf(r.size.x, r.size.y) * 0.5 - 1.0
			draw_colored_polygon(_diamond(c, h), container)
			draw_polyline(_diamond(c, h, true), edge, 1.5)
			if filled:
				draw_colored_polygon(_diamond(c, h + grow), fill)
			if _flash > 0.0:
				draw_colored_polygon(_diamond(c, h - 2.0), Color(1, 1, 1, _flash * ArtStyle.flash_scale()))


static func _diamond(c: Vector2, h: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
	if closed:
		pts.append(pts[0])
	return pts
