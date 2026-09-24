class_name EchoIcon
extends Control
## Procedural glyph for the active echo: Burst = spread rays, Arc = zigzag bolt,
## Guard = shield hex, none = hollow diamond.

var echo_id: StringName = &"":
	set(value):
		echo_id = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(30, 30)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var data := EchoModules.get_data(echo_id)
	var color := data.module_color if data else Palette.UI_MUTED_TEXT
	draw_circle(c, r, Color(0.02, 0.05, 0.1, 0.9))
	match echo_id:
		EchoModules.BURST:
			for a in [-0.45, 0.0, 0.45]:
				var dir := Vector2(cos(a), sin(a))
				draw_line(c - dir * r * 0.5, c + dir * r * 0.75, color, 3.0)
		EchoModules.ARC:
			var pts := PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(0, -r * 0.1),
					c + Vector2(-r * 0.15, r * 0.15), c + Vector2(r * 0.6, r * 0.55)])
			draw_polyline(pts, color, 3.0)
		EchoModules.GUARD:
			var hex := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 6.0 + PI / 6.0
				hex.append(c + Vector2(cos(a), sin(a)) * r * 0.65)
			draw_polyline(hex, color, 3.0)
		_:
			draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.5, 0),
					c + Vector2(0, r * 0.5), c + Vector2(-r * 0.5, 0), c + Vector2(0, -r * 0.5)]), color, 2.0)
	draw_arc(c, r, 0, TAU, 24, Color(color, 0.8), 2.0)
