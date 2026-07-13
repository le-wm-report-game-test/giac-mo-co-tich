# res://src/tests/cases/test_boss_combat_runtime_tier3.gd
extends "res://src/tests/base_test_case.gd"

# Runtime regressions taken from the recorded boss encounter.

var _player: Player = null


func setup() -> void:
	await super.setup()
	_player = tree.get_first_node_in_group("player") as Player
	assert_not_null(_player, "Player must exist")
	for candidate: Node in tree.get_nodes_in_group("orc_mobs"):
		if candidate is OrcMob:
			candidate.set_physics_process(false)




func test_mouse_attack_aims_at_clicked_boss_and_deals_damage() -> void:
	var boss := await _spawn_boss(Vector3(0.0, 0.0, -1.45), false)
	_player._set_facing_from_world_direction(Vector3.RIGHT)
	_player.input_locked = false
	await _wait_real_physics_frames(3)

	var camera := _player.get_viewport().get_camera_3d()
	assert_not_null(camera, "Game camera must exist for pointer aiming")
	if camera == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(boss.global_position + Vector3.UP)
	var target_direction := boss.global_position - _player.global_position
	target_direction.y = 0.0
	target_direction = target_direction.normalized()
	var pointer_direction: Vector3 = _player.combat_v2.get_pointer_attack_direction(click.position)
	assert_true(pointer_direction.dot(target_direction) > 0.9, "Pointer projection must resolve toward the clicked boss")

	var health_before := boss.health_component.current_health
	_player._unhandled_input(click)
	assert_true(_player.is_attacking, "Left mouse action must start a player attack")
	await _wait_real_physics_frames(45)

	assert_true(_player.facing_direction.dot(target_direction) > 0.9, "Mouse attack must face the clicked boss")
	assert_true(boss.health_component.current_health < health_before, "Mouse attack must damage a clicked boss in melee range")


func test_boss_close_chase_points_directly_at_player() -> void:
	var boss := await _spawn_boss(Vector3(-2.0, 0.0, 0.0), false)
	boss.attack_cooldown_timer = 0.0
	var desired := boss._get_planar_offset_to(_player).normalized()
	var actual := boss._get_chase_target_direction(_player)
	assert_true(actual.dot(desired) > 0.99, "Boss close chase must not strafe away from the player")


func test_boss_stays_attack_locked_until_combat_finishes() -> void:
	var boss := await _spawn_boss(Vector3(-1.2, 0.0, 0.0), true)
	boss.speed = 0.0
	boss.gravity = 0.0
	boss.attack_cooldown_timer = 0.0
	boss.current_state = OrcMob.State.CHASE
	var saw_attack := false
	var escaped_while_active := false

	for _frame in range(90):
		await tree.physics_frame
		if boss.current_state == OrcMob.State.ATTACK:
			saw_attack = true
		if saw_attack and boss.combat_v2.is_active and boss.current_state != OrcMob.State.ATTACK:
			escaped_while_active = true

	assert_true(saw_attack, "Boss must enter ATTACK inside its trigger range")
	assert_false(escaped_while_active, "Boss cannot walk/chase while its combat phase is active")
	assert_false(boss.combat_v2.is_active, "Boss combat lifecycle must finish after recovery")

func test_damaging_boss_cancels_active_hitbox() -> void:
	var boss := await _spawn_boss(Vector3(-1.2, 0.0, 0.0), true)
	boss.speed = 0.0
	boss.gravity = 0.0
	boss.attack_cooldown_timer = 0.0
	boss.current_state = OrcMob.State.CHASE
	for _frame in range(45):
		await tree.physics_frame
		if boss.combat_v2.phase == EnemyCombatV2.AttackPhase.ATTACK:
			break

	assert_eq(boss.combat_v2.phase, EnemyCombatV2.AttackPhase.ATTACK, "Boss must reach its active hit phase")
	boss.health_component.take_damage(1.0, _player)
	await tree.physics_frame
	assert_false(boss.combat_v2.is_active, "Taking damage must cancel the pending boss attack")
	assert_false(boss.hitbox_component.monitoring, "Interrupted boss hitbox must turn off immediately")


func test_boss_routes_around_blocker_and_reaches_attack_range() -> void:
	_player.set_physics_process(false)
	_player.global_position = Vector3(0.0, 20.0, 0.0)
	var boss := await _spawn_boss(Vector3(-4.0, 0.0, 0.0), false)
	boss.gravity = 0.0
	boss.speed = 1.5
	boss.attack_cooldown_timer = 0.0
	boss.current_state = OrcMob.State.CHASE

	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var blocker_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.0, 1.4)
	blocker_shape.shape = box
	blocker.add_child(blocker_shape)
	world_instance.add_child(blocker)
	blocker.global_position = _player.global_position + Vector3(-2.0, 0.75, 0.0)
	boss.set_physics_process(true)

	var reached_attack := false
	for _frame in range(420):
		await tree.physics_frame
		if boss.current_state == OrcMob.State.ATTACK:
			reached_attack = true
			break

	var final_distance := boss._get_planar_offset_to(_player).length()
	boss._cancel_active_attack()
	boss.set_physics_process(false)
	blocker.free()
	await tree.physics_frame
	assert_true(reached_attack, "Boss must route around a rock and proactively enter attack range (position=%s, distance=%.2f)" % [boss.global_position, final_distance])


func _spawn_boss(offset: Vector3, physics_enabled: bool) -> OrcBossMob:
	var boss := OrcBossMob.new()
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	world_instance.add_child(boss)
	boss.global_position = _player.global_position + offset
	boss.set_physics_process(physics_enabled)
	await _wait_real_physics_frames(2)
	return boss


func _wait_real_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await tree.physics_frame


