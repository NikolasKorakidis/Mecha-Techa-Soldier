class_name EnvironmentBinder
extends WorldEnvironment
## Applies video settings to this scene's environment, its directional lights and the
## viewport, and keeps them in sync. HIGH graphics: key-light shadows, SSAO, SMAA (always 2x MSAA).
## Every environment gets the same tight bloom (apply_tight_glow).

## Controlled bloom: only the small mip levels, so neon, bullets and engines get a halo instead
## of smearing into white bars (Forward+ HDR runs much hotter than the Compatibility renderer).
static func apply_tight_glow(env: Environment) -> void:
	var levels := [0.0, 1.0, 0.75, 0.35, 0.0, 0.0, 0.0]
	for i in levels.size():
		env.set_glow_level(i, levels[i])
	env.glow_hdr_threshold = maxf(env.glow_hdr_threshold, 1.1)
	# Stray HDR fireflies must never bloom into shapes.
	env.glow_hdr_luminance_cap = 6.0


func _ready() -> void:
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var high := Settings.high_graphics
	if environment:
		environment.glow_enabled = Settings.glow_enabled
		apply_tight_glow(environment)
		environment.ssao_enabled = high
		environment.ssao_radius = 1.2
		environment.ssao_intensity = 1.6
		environment.ssao_light_affect = 0.2
	# 2x MSAA + SMAA on HIGH: 4x MSAA turned sub-pixel slivers into HDR fireflies that the glow
	# smeared into white bars (seen on the software Vulkan driver); SMAA cleans edges without it.
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if high else Viewport.SCREEN_SPACE_AA_DISABLED
	# Only the key light casts shadows; the rim light stays a cheap fill.
	for light in get_parent().get_children():
		if light is DirectionalLight3D and light.name == &"KeyLight":
			var key := light as DirectionalLight3D
			key.shadow_enabled = high
			key.shadow_blur = 1.5
			key.shadow_opacity = 0.75
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			key.directional_shadow_max_distance = 140.0
