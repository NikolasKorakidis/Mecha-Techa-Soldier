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


func test_engine_loop_loops_and_stops() -> void:
	var engine := AudioService.start_loop(&"bike_engine")
	assert_true(engine != null, "loop player created")
	assert_eq((engine.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "engine hum loops")
	AudioService.stop_loop(engine)
	await wait_process_frames(2)
	assert_false(is_instance_valid(engine), "stopped loop player is freed")


func test_frequent_effects_have_takes_and_never_repeat() -> void:
	for id: StringName in AudioService.VARIANTS:
		var takes: Array = AudioService._sfx_takes.get(id, [])
		assert_eq(takes.size(), int(AudioService.VARIANTS[id]), "'%s' has every take" % id)
		for take in takes:
			assert_true(take is AudioStream, "'%s' takes load" % id)
	var last: AudioStream = null
	for i in 12:
		var take := AudioService._pick_take(&"hit", null)
		assert_true(take != last, "a take is never played twice in a row")
		last = take
