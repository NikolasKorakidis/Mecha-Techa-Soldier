@tool
class_name ProjectileVisual
extends Node3D
## Shared projectile look. The core is always solid and brighter than its trail, and sits at the
## node origin = the hitbox center, so the collision point stays obvious in busy scenes.
## Trails extend along local -X (projectiles rotate to face their velocity).

enum Style { PLAYER, PLAYER_BURST, PLAYER_ORB, HOSTILE, HOSTILE_HEAVY }

@export var style: Style = Style.PLAYER:
	set(value):
		style = value
		if is_inside_tree():
			_build()

var _highlight: Node3D
var _halo: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	ModelKit.clear(self)
	_highlight = null
	_halo = null
	match style:
		Style.PLAYER:
			_player_bolt(Palette.PLAYER_SECONDARY, 1.0)
		Style.PLAYER_BURST:
			_player_bolt(Color("ff9a4a"), 1.15)
		Style.PLAYER_ORB:
			_player_bolt(Palette.PLAYER_GOLD, 0.85)
		Style.HOSTILE:
			_hostile_orb(1.0)
		Style.HOSTILE_HEAVY:
			_hostile_orb(1.5)


## Compact cyan-white bolt with a short tinted trail.
func _player_bolt(trail_color: Color, scale_factor: float) -> void:
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Palette.FRIENDLY_PROJECTILE
	var bolt := ModelKit.box(self, Vector3(0.52, 0.13, 0.1) * scale_factor, Vector3.ZERO, core)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ModelKit.quad(self, Vector2(1.5, 0.4) * scale_factor, Vector3(-0.62 * scale_factor, 0, -0.1),
			ModelKit.glow(trail_color.lerp(Palette.PLAYER_ENERGY, 0.35), ArtStyle.PROJECTILE_TRAIL_ENERGY, ModelKit.GlowShape.STREAK))
	ModelKit.quad(self, Vector2(0.7, 0.45) * scale_factor, Vector3(0.1, 0, -0.05),
			ModelKit.glow(Palette.PLAYER_ENERGY, ArtStyle.PROJECTILE_TRAIL_ENERGY * 0.8))


## Hot magenta orb: dark ring for contrast on any background, rotating highlight, short trail.
func _hostile_orb(scale_factor: float) -> void:
	var r := 0.2 * scale_factor
	ModelKit.quad(self, Vector2(1.1, 0.5) * scale_factor, Vector3(-0.45 * scale_factor, 0, -0.3),
			ModelKit.glow(Palette.HOSTILE_PROJECTILE, ArtStyle.PROJECTILE_TRAIL_ENERGY * 0.8, ModelKit.GlowShape.STREAK))
	_halo = ModelKit.quad(self, Vector2.ONE * 1.2 * scale_factor, Vector3(0, 0, -0.25),
			ModelKit.glow(Palette.HOSTILE_PROJECTILE, ArtStyle.GLOW_STANDARD * 0.7))
	var ring := StandardMaterial3D.new()
	ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.albedo_color = Color("16020f")
	# Flattened and pushed behind the core so it frames it at every size.
	ModelKit.sphere(self, r * 1.65, Vector3(0, 0, -r * 1.2), ring, Vector3(1, 1, 0.3))
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Palette.HOSTILE_PROJECTILE.lerp(Color.WHITE, 0.3)
	ModelKit.sphere(self, r, Vector3.ZERO, core)
	var center := StandardMaterial3D.new()
	center.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center.albedo_color = Color(1, 0.9, 0.97)
	ModelKit.sphere(self, r * 0.45, Vector3(0, 0, r * 0.6), center)
	_highlight = ModelKit.group(self, "Highlight", Vector3(0, 0, r + 0.02))
	ModelKit.quad(_highlight, Vector2.ONE * r * 0.9, Vector3(r * 0.95, 0, 0), ModelKit.glow(Color.WHITE, 1.6))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if _highlight:
		_highlight.rotation.z -= delta * 9.0
	if _halo and style == Style.HOSTILE_HEAVY:
		_halo.scale = Vector3.ONE * (1.0 + 0.15 * sin(_time * 14.0))
