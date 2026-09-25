extends TestCase

const TEMP_PATH := "user://test_settings.cfg"


func test_missing_file_loads_defaults() -> void:
	Settings.reduced_flash = true
	Settings.load_settings("user://does_not_exist.cfg")
	assert_false(Settings.reduced_flash, "default reduced_flash")
	assert_true(Settings.glow_enabled, "default glow")
	assert_false(Settings.show_debug_labels, "debug labels off by default")
	assert_eq(Settings.high_graphics, Settings.supports_high_graphics(), "high graphics defaults on only where supported")


func test_particle_amount_follows_graphics_quality() -> void:
	Settings.high_graphics = false
	assert_eq(Settings.particle_amount(8), 8, "standard keeps base counts")
	Settings.high_graphics = true
	assert_true(Settings.particle_amount(8) > 8, "high adds particles")
	Settings.reset_defaults()


func test_incompatible_version_loads_defaults() -> void:
	var file := ConfigFile.new()
	file.set_value("meta", "version", 999)
	file.set_value("accessibility", "reduced_shake", true)
	file.save(TEMP_PATH)
	Settings.load_settings(TEMP_PATH)
	assert_false(Settings.reduced_shake, "ignored incompatible file")


func test_round_trip() -> void:
	Settings.set_persistence(true)
	Settings.reduced_shake = true
	Settings.tutorials_done = PackedStringArray(["move"])
	Settings.save_settings(TEMP_PATH)
	Settings.set_persistence(false)
	Settings.reset_defaults()
	Settings.load_settings(TEMP_PATH)
	assert_true(Settings.reduced_shake, "reduced shake persisted")
	assert_true(Settings.tutorials_done.has("move"), "tutorial progress persisted")


func test_reduced_modes_scale_feedback() -> void:
	assert_eq(ArtStyle.shake_scale(), 1.0, "full shake by default")
	Settings.reduced_shake = true
	Settings.reduced_flash = true
	assert_true(ArtStyle.shake_scale() < 0.5, "reduced shake")
	assert_true(ArtStyle.flash_scale() < 0.5, "reduced flash")
