extends WorldEnvironment
## Applies video settings to this scene's environment, its directional lights and the
## viewport, and keeps them in sync. HIGH graphics: key-light shadows, SSAO, 4x MSAA.

func _ready() -> void:
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var high := Settings.high_graphics
	if environment:
		environment.glow_enabled = Settings.glow_enabled
		environment.ssao_enabled = high
		environment.ssao_radius = 1.2
		environment.ssao_intensity = 1.6
		environment.ssao_light_affect = 0.2
	get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X
	# Only the key light casts shadows; the rim light stays a cheap fill.
	for light in get_parent().get_children():
		if light is DirectionalLight3D and light.name == &"KeyLight":
			var key := light as DirectionalLight3D
			key.shadow_enabled = high
			key.shadow_blur = 1.5
			key.shadow_opacity = 0.75
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			key.directional_shadow_max_distance = 140.0
