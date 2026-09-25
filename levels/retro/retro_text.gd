class_name RetroText
extends Node2D
## Bitmap text in the stage's 5x7 pixel font (6 px advance). Uppercase + digits + a few symbols.

const ORDER := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 :-/!.,?'x><=*"
const ADVANCE := 6

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var centered: bool = false:
	set(value):
		centered = value
		queue_redraw()
@export var shadow: bool = true

static var _font: Texture2D


func _draw() -> void:
	if _font == null:
		_font = RetroArt.texture(&"font")
	var width := text.length() * ADVANCE
	var origin := Vector2(-width * 0.5 if centered else 0.0, 0.0).round()
	for i in text.length():
		var index := ORDER.find(text[i].to_upper() if text[i] != "x" else "x")
		if index < 0:
			continue
		var src := Rect2(index * ADVANCE, 0, ADVANCE, 8)
		var at := origin + Vector2(i * ADVANCE, 0)
		if shadow:
			draw_texture_rect_region(_font, Rect2(at + Vector2(1, 1), Vector2(ADVANCE, 8)), src, Color(0, 0, 0, 1))
		draw_texture_rect_region(_font, Rect2(at, Vector2(ADVANCE, 8)), src, color)
