extends TestCase


func test_reset_restores_defaults() -> void:
	RunSession.add_score(500)
	RunSession.add_energy(2)
	RunSession.set_echo(&"burst")
	RunSession.set_health(1)
	RunSession.reset_run()
	assert_eq(RunSession.score, 0, "score reset")
	assert_eq(RunSession.energy, 0, "energy reset")
	assert_eq(RunSession.selected_echo, RunSession.NO_ECHO, "echo reset")
	assert_eq(RunSession.health, RunSession.max_health, "health reset")


func test_energy_is_clamped_between_zero_and_three() -> void:
	assert_eq(RunSession.add_energy(5), 3, "adding past cap applies only 3")
	assert_eq(RunSession.energy, 3, "energy capped at 3")
	assert_eq(RunSession.add_energy(-10), -3, "removing past zero applies only -3")
	assert_eq(RunSession.energy, 0, "energy floored at 0")


func test_spend_energy_requires_full_cost() -> void:
	RunSession.add_energy(1)
	assert_false(RunSession.spend_energy(2), "cannot spend 2 with 1")
	assert_eq(RunSession.energy, 1, "failed spend leaves energy untouched")
	assert_true(RunSession.spend_energy(1), "can spend 1 with 1")
	assert_eq(RunSession.energy, 0, "energy spent")
	assert_false(RunSession.spend_energy(0), "zero cost is rejected")


func test_health_is_clamped_and_emits_only_on_change() -> void:
	var spy := SignalSpy.new(RunSession.health_changed)
	RunSession.set_health(99)
	assert_eq(RunSession.health, RunSession.max_health, "health capped")
	assert_eq(spy.count(), 0, "no emit when value unchanged")
	RunSession.set_health(-4)
	assert_eq(RunSession.health, 0, "health floored")
	assert_eq(spy.count(), 1, "one emit on change")


func test_echo_change_emits_once() -> void:
	var spy := SignalSpy.new(RunSession.echo_changed)
	RunSession.set_echo(&"arc")
	RunSession.set_echo(&"arc")
	assert_eq(spy.count(), 1, "same echo twice emits once")
	assert_eq(RunSession.selected_echo, &"arc", "echo stored")


func test_checkpoint_restores_intended_fields() -> void:
	RunSession.add_score(1200)
	RunSession.add_energy(2)
	RunSession.equip_echo(&"guard", 50)
	RunSession.save_checkpoint(&"after_transform")
	RunSession.add_score(900)
	RunSession.add_energy(-2)
	RunSession.equip_echo(&"burst", 10)
	RunSession.set_health(1)
	assert_true(RunSession.restore_checkpoint(), "restore succeeds")
	assert_eq(RunSession.score, 1200, "score back to snapshot")
	assert_eq(RunSession.energy, 2, "energy back to snapshot")
	assert_eq(RunSession.selected_echo, &"guard", "module held at activation kept")
	assert_eq(RunSession.echo_ammo, 50, "its ammo kept too")
	assert_eq(RunSession.health, RunSession.max_health, "base health restored")
	assert_eq(RunSession.checkpoint_id, &"after_transform", "checkpoint id kept")


func test_restore_without_checkpoint_fails() -> void:
	assert_false(RunSession.has_checkpoint(), "fresh run has no checkpoint")
	assert_false(RunSession.restore_checkpoint(), "restore without snapshot fails")
