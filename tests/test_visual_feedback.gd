extends TestCase
## Feedback systems: camera shake, explosions, hit flash.


func _scaffold() -> GameplayCamera:
	var camera := GameplayCamera.new()
	camera.size = 18.0
	camera.position = Vector3(0, 0, 30)
	add_autofree(camera)
	var effects := Node3D.new()
	effects.add_to_group(Vfx.ROOT_GROUP)
	add_autofree(effects)
	return camera


func test_trauma_is_capped_and_decays() -> void:
	var camera := _scaffold()
	camera.add_trauma(5.0)
	assert_eq(camera.trauma, ArtStyle.SHAKE_MAX_TRAUMA, "trauma capped")
	await wait_process_frames(90)
	assert_eq(camera.trauma, 0.0, "trauma decays to zero")
	assert_eq(camera.h_offset, 0.0, "offset reset after shake")


func test_shake_never_moves_the_play_rect() -> void:
	var camera := _scaffold()
	var rect := camera.get_play_rect()
	camera.add_trauma(1.0)
	await wait_process_frames(5)
	assert_eq(camera.get_play_rect(), rect, "play rect independent of shake offset")


func test_shake_scale_zero_disables_shake() -> void:
	var camera := _scaffold()
	camera.shake_scale = 0.0
	camera.add_trauma(1.0)
	await wait_process_frames(5)
	assert_eq(camera.h_offset, 0.0, "no horizontal shake")
	assert_eq(camera.v_offset, 0.0, "no vertical shake")


func test_explosion_spawns_at_position_shakes_and_frees() -> void:
	var camera := _scaffold()
	var boom := Vfx.spawn(get_tree(), load("res://vfx/explosion.tscn"), Vector3(3, 2, 0), 1.0) as Explosion
	assert_true(boom != null, "explosion spawned")
	assert_eq(boom.global_position, Vector3(3, 2, 0), "at requested position")
	assert_true(camera.trauma > 0.0, "explosion adds trauma")
	# The free timer starts in _ready with the configured lifetime (smoke needs it to clear).
	await get_tree().create_timer(boom.lifetime + 0.3).timeout
	assert_false(is_instance_valid(boom), "explosion frees itself")


func test_overlay_flash_paints_and_clears_meshes() -> void:
	var target := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	target.add_child(mesh)
	add_autofree(target)
	var flash := FlashComponent.new()
	flash.target = target
	flash.mode = FlashComponent.Mode.OVERLAY
	add_autofree(flash)
	flash.flash(0.05)
	assert_true(mesh.material_overlay != null, "overlay applied during flash")
	await get_tree().create_timer(0.15).timeout
	assert_true(mesh.material_overlay == null, "overlay cleared after flash")
	assert_true(target.visible, "overlay mode never hides the target")


func test_overlay_flash_strobes_under_sustained_hits() -> void:
	var target := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	target.add_child(mesh)
	add_autofree(target)
	var flash := FlashComponent.new()
	flash.target = target
	flash.mode = FlashComponent.Mode.OVERLAY
	add_autofree(flash)
	var lit_frames := 0
	for i in 60:
		flash.flash(0.05)  # hit every frame
		await get_tree().process_frame
		if mesh.material_overlay != null:
			lit_frames += 1
	assert_true(lit_frames < 50, "overlay is not solid under constant fire (%d/60 lit)" % lit_frames)
	assert_true(lit_frames > 5, "overlay still shows hits")


func test_hit_stop_is_brief_and_restores_time() -> void:
	HitStop.trigger(get_tree(), 0.05)
	assert_true(Engine.time_scale < 1.0, "time slowed on a strong hit")
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "time scale restored")


func test_impact_sparks_follow_projectile_direction() -> void:
	_scaffold()
	var spark := Vfx.spawn(get_tree(), load("res://vfx/impact_spark.tscn"), Vector3.ZERO, 1.0, {&"direction": Vector3.UP}) as ImpactSpark
	assert_eq(spark.direction, Vector3.UP, "direction applied before the burst is built")
