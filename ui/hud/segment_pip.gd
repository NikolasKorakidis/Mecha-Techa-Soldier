class_name SegmentPip
extends Control
## One HUD segment. Shape carries meaning alongside color (art bible: color alone is insufficient).

enum Shape { BAR, DIAMOND }

@export var shape: Shape = Shape.BAR
@export var fill_color: Color = Palette.HEALTH
@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 28)


func _draw() -> void:
	var color := fill_color if filled else Palette.EMPTY_SEGMENT
	var r := Rect2(Vector2.ZERO, size)
	match shape:
		Shape.BAR:
			draw_rect(r.grow(-3.0), color)
		Shape.DIAMOND:
			var c := r.get_center()
			var h := minf(r.size.x, r.size.y) * 0.5 - 2.0
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0),
			]), color)
