class_name ControlsPanel
extends VBoxContainer
## Read-only control reference (keyboard + controller).

signal closed

const ROWS: Array[Array] = [
	["Move", "W A S D / Arrows", "Left stick / D-pad"],
	["Fire (hold)", "J / Left mouse", "RT"],
	["Dash", "K / Shift", "B / Circle"],
	["Vertical burst", "Space", "A / Cross"],
	["Pause", "Esc", "Start / Options"],
]

var _back: UiMenuButton


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	add_child(UiStyle.label("CONTROLS", ArtStyle.FONT_TITLE - 16, Palette.PLAYER_PRIMARY))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 36)
	grid.add_theme_constant_override(&"v_separation", 8)
	add_child(grid)
	for header in ["", "KEYBOARD", "CONTROLLER"]:
		grid.add_child(UiStyle.label(header, ArtStyle.FONT_CAPTION, Palette.UI_GOLD))
	for row in ROWS:
		grid.add_child(UiStyle.label(row[0], ArtStyle.FONT_BODY, Palette.PLAYER_PRIMARY))
		grid.add_child(UiStyle.label(row[1], ArtStyle.FONT_BODY, Palette.UI_MUTED_TEXT))
		grid.add_child(UiStyle.label(row[2], ArtStyle.FONT_BODY, Palette.UI_MUTED_TEXT))
	_back = UiMenuButton.new()
	_back.text = "Back"
	_back.pressed.connect(func() -> void: closed.emit())
	add_child(_back)


func focus_first() -> void:
	_back.grab_focus()
