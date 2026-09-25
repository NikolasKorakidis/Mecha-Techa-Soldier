class_name UiStyle
extends RefCounted
## Shared UI look (docs/art-direction.md): dark navy panels, skewed wedge corners, colored
## bottom edges, outlined text. HUD, stage overlay, tutorial card and menus all use this.

const BODY_FONT := preload("res://assets/fonts/chakra_petch_semibold.woff2")
const BOLD_FONT := preload("res://assets/fonts/chakra_petch_bold.woff2")
const DISPLAY_FONT := preload("res://assets/fonts/orbitron_black.woff2")
const DISPLAY_BOLD_FONT := preload("res://assets/fonts/orbitron_bold.woff2")

static var _tabular_font: FontVariation
static var _display_fonts: Dictionary = {}


## Translucent panel with a colored bottom edge. `skew` > 0 leans right, < 0 leans left.
static func panel(edge: Color = Palette.PLAYER_SECONDARY, skew: float = ArtStyle.UI_SKEW, alpha: float = ArtStyle.UI_PANEL_ALPHA) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK_PANEL, alpha)
	box.border_width_bottom = ArtStyle.UI_EDGE
	box.border_color = edge
	box.set_corner_radius_all(ArtStyle.UI_CORNER)
	box.skew = Vector2(skew, 0)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	return box


static func style_label(label: Label, size: int, color: Color = Color.WHITE, outline: bool = true) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	if outline:
		label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override(&"outline_size", maxi(4, size / 7))


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color)
	return l


## Orbitron with extra letter spacing (cached per spacing) for titles, banners and the logo.
static func display_font(spacing: int = 6, bold_only: bool = false) -> FontVariation:
	var key := "%d_%s" % [spacing, bold_only]
	if not _display_fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = DISPLAY_BOLD_FONT if bold_only else DISPLAY_FONT
		variation.spacing_glyph = spacing
		_display_fonts[key] = variation
	return _display_fonts[key]


## Title styling: display font, letter spacing, dark outline and a soft coloured glow.
static func style_title(label: Label, size: int, glow: Color = Palette.PLAYER_PRIMARY, spacing: int = 6) -> void:
	label.add_theme_font_override(&"font", display_font(spacing))
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color(0.02, 0.03, 0.07, 0.95))
	label.add_theme_constant_override(&"outline_size", maxi(6, size / 9))
	label.add_theme_color_override(&"font_shadow_color", Color(glow, 0.55))
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 0)
	label.add_theme_constant_override(&"shadow_outline_size", maxi(10, size / 4))


## Default font with tabular (fixed-width) digits so scores don't jitter.
static func tabular_font() -> Font:
	if _tabular_font == null:
		_tabular_font = FontVariation.new()
		_tabular_font.base_font = BOLD_FONT
		_tabular_font.opentype_features = {"tnum": 1}
	return _tabular_font
