extends WorldEnvironment
## Applies video settings (glow) to this scene's environment and keeps them in sync.

func _ready() -> void:
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	if environment:
		environment.glow_enabled = Settings.glow_enabled
