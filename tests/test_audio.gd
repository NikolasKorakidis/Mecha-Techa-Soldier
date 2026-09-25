extends TestCase
## Audio: every generated asset exists and loads, music loops, crossfades track the current
## track, and the volume options drive the buses.


func test_all_music_and_sfx_load() -> void:
	for id: StringName in AudioService.MUSIC:
		var stream := load(AudioService.MUSIC_DIR % id) as AudioStreamWAV
		assert_true(stream != null, "music '%s' loads" % id)
		# Jingles play once; everything else loops.
		if stream and id not in [&"stage_clear", &"clear8"]:
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "music '%s' loops" % id)
	for id: StringName in AudioService.SFX:
		assert_true(load(AudioService.SFX_DIR % id) is AudioStream, "sfx '%s' loads" % id)


func test_music_switches_and_ignores_repeats() -> void:
	AudioService.play_music(&"stage1", 0.01)
	assert_eq(AudioService.current_music, &"stage1", "stage 1 theme playing")
	AudioService.play_music(&"stage1", 0.01)
	assert_eq(AudioService.current_music, &"stage1", "replaying the same track keeps it")
	AudioService.play_music(&"boss", 0.01)
	assert_eq(AudioService.current_music, &"boss", "boss theme takes over")
	AudioService.stop_music(0.01)
	assert_eq(AudioService.current_music, &"", "music stopped")


func test_volume_options_drive_the_buses() -> void:
	Settings.set_persistence(false)
	Settings.set_option(&"music_volume", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "music at 0 mutes the music bus")
	Settings.set_option(&"music_volume", 1.0)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "music back on")
	Settings.set_option(&"sfx_volume", 0.5)
	var half := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
	Settings.set_option(&"sfx_volume", 1.0)
	assert_true(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")) > half, "higher effects volume = louder bus")
	Settings.reset_defaults()


func test_rapid_fire_is_throttled() -> void:
	await wait_process_frames(10)
	var voice_before: int = AudioService._next_voice
	for i in 10:
		AudioService.play(&"shot_player")
	assert_eq((AudioService._next_voice - voice_before + AudioService.VOICES) % AudioService.VOICES, 1, "ten shots in one frame use one voice")
