extends "res://src/tests/base_test_case.gd"

# Kiểm thử cadence và hành vi commit attack của Orc thường.

var _orc: OrcMob = null
var _player: Node3D = null

func setup() -> void:
	await super.setup()
	_orc = tree.get_first_node_in_group("orc_mobs") as OrcMob
	_player = tree.get_first_node_in_group("player") as Node3D
	assert_not_null(_orc, "World must contain a regular Orc")
	assert_not_null(_player, "World must contain the player")
	if _orc:
		_orc.set_physics_process(false)

func test_regular_orc_attack_cycle_is_relentless() -> void:
	var ideal_cycle_seconds := 6.0 / _orc.attack_animation_fps + _orc.attack_cooldown_time
	assert_true(_orc.attack_animation_fps >= 10.0, "Regular Orc attack animation should run at least 10 FPS")
	assert_true(_orc.attack_cooldown_time <= 0.8, "Regular Orc recovery should be at most 0.8 seconds")
	assert_true(ideal_cycle_seconds <= 1.4, "Ideal regular Orc attack cycle should not exceed 1.4 seconds")

func test_regular_orc_repeats_three_attacks_within_four_seconds() -> void:
	_orc.global_position = Vector3.ZERO
	_player.global_position = Vector3(_orc.attack_range * 0.8, 0.8, 0.0)
	_orc.current_state = OrcMob.State.CHASE
	_orc.attack_cooldown_timer = 0.0
	var attacks_started := 0
	var was_attacking := false
	var delta := 1.0 / 60.0
	for _frame in range(240):
		_orc._update_ai_state(delta)
		var is_attacking := _orc.current_state == OrcMob.State.ATTACK
		if is_attacking and not was_attacking:
			attacks_started += 1
		_orc._update_animation(delta)
		if _orc.attack_cooldown_timer > 0.0:
			_orc.attack_cooldown_timer -= delta
		was_attacking = _orc.current_state == OrcMob.State.ATTACK
	assert_true(attacks_started >= 3, "Regular Orc should start at least three attacks within four seconds")

func test_regular_orc_commits_directly_when_attack_is_ready() -> void:
	_orc.global_position = Vector3.ZERO
	_player.global_position = Vector3(1.65, 0.8, 0.0)
	_orc.attack_cooldown_timer = 0.0
	var desired := _orc._get_planar_offset_to(_player).normalized()
	var actual := _orc._get_chase_target_direction(_player)
	assert_true(actual.dot(desired) > 0.99, "Ready Orc should approach directly inside the commit zone")

func test_regular_orc_holds_ground_during_recovery() -> void:
	_orc.global_position = Vector3.ZERO
	_player.global_position = Vector3(_orc.attack_range * 0.8, 0.8, 0.0)
	_orc.attack_cooldown_timer = 0.5
	assert_true(_orc._is_holding_attack_position(_player), "Recovering Orc should hold inside attack range")
	assert_eq(_orc._get_chase_target_direction(_player), Vector3.ZERO, "Recovering Orc should not strafe out of attack range")

func test_regular_orc_hitbox_covers_attack_trigger_range() -> void:
	var hit_shape := _orc.hitbox_col.shape as SphereShape3D
	assert_not_null(hit_shape, "Regular Orc attack hitbox should be spherical")
	assert_true(hit_shape.radius + 0.001 >= _orc.attack_range * 0.65, "Hitbox reach should match the attack trigger range")

func test_regular_orc_health_bar_is_visible_and_updates_instantly() -> void:
	assert_not_null(_orc.health_bar_sprite, "Regular Orc should create a floating health bar sprite")
	assert_not_null(_orc.health_bar_fill, "Regular Orc should create a health bar fill")
	assert_true(_orc.health_bar_sprite.visible, "Regular Orc health bar should be visible while alive")
	
	var full_width := _orc.health_bar_fill.size.x
	_orc.health_component.take_damage(_orc.health_component.max_health * 0.5, null)
	assert_almost_eq(
		_orc.health_bar_fill.size.x,
		roundf(full_width * 0.5),
		1.0,
		"Regular Orc health bar fill should update immediately after damage"
	)

func test_boss_keeps_heavy_attack_cadence() -> void:
	var boss := OrcMob.new()
	boss.add_to_group("boss")
	world_instance.add_child(boss)
	boss.set_physics_process(false)
	assert_true(boss.attack_cooldown_time >= 1.5, "Boss recovery should remain heavier than a regular Orc")
	assert_true(boss.attack_animation_fps <= 8.0, "Boss attack animation should retain its heavy cadence")
	boss.queue_free()

func test_boss_health_bar_is_larger_and_hides_on_death() -> void:
	var boss := OrcMob.new()
	boss.add_to_group("boss")
	world_instance.add_child(boss)
	boss.set_physics_process(false)
	
	assert_not_null(boss.health_bar_sprite, "Boss should create a floating health bar sprite")
	assert_not_null(boss.health_bar_fill, "Boss should create a health bar fill")
	assert_true(boss.health_bar_fill_max_width > _orc.health_bar_fill_max_width, "Boss health bar should be wider than regular Orc bar")
	assert_true(boss.health_bar_sprite.position.y > _orc.health_bar_sprite.position.y, "Boss health bar should float higher than regular Orc bar")
	
	boss.health_component.take_damage(boss.health_component.max_health, null)
	assert_false(boss.health_bar_sprite.visible, "Boss health bar should hide immediately on death")
	boss.queue_free()

func test_boss_visual_scale_stays_close_to_regular_orc() -> void:
	var boss := OrcBossMob.new()
	boss.add_to_group("boss")
	world_instance.add_child(boss)
	boss.set_physics_process(false)

	var boss_sprite := boss.sprite as Sprite3D
	assert_not_null(boss_sprite, "Boss should create its Sprite3D visual")
	assert_almost_eq(boss_sprite.pixel_size, OrcBossMob.BOSS_VISUAL_PIXEL_SIZE, 0.0001, "Boss visual should follow the dedicated boss scale constant")
	boss.queue_free()

func test_boss_diagonal_walk_falls_back_to_cardinal_frames() -> void:
	var boss := OrcBossMob.new()
	boss.add_to_group("boss")
	world_instance.add_child(boss)
	boss.set_physics_process(false)

	var diagonal_keys := [
		OrcBossMob.WALK_DIR_UP_LEFT,
		OrcBossMob.WALK_DIR_UP_RIGHT,
		OrcBossMob.WALK_DIR_DOWN_LEFT,
		OrcBossMob.WALK_DIR_DOWN_RIGHT,
	]
	for key in diagonal_keys:
		boss._walk_direction_key = key
		var frames: Array = boss._get_frames_for_state("walk")
		assert_true(frames.is_empty(), "Boss walk lookup should not provide separate diagonal frame sets anymore")
	boss.queue_free()
