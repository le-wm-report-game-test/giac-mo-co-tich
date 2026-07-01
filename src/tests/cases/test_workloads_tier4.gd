# res://src/tests/cases/test_workloads_tier4.gd
extends "res://src/tests/base_test_case.gd"

# Tier 4 prolonged player workload scenario tests.
# Technical comments in English, Vietnamese for game logic explanations.

func scenario_complete_level_progression() -> void:
	# Scenario 1: Săn 5 quái thường -> Spawn Boss -> Đánh bại Boss -> Hoàn tất level
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	var fb := world_instance.get_node("Forest") as Node
	
	var orc_mobs: Array[CharacterBody3D] = []
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			orc_mobs.append(child as CharacterBody3D)
			if orc_mobs.size() >= 5:
				break
				
	assert_eq(orc_mobs.size(), 5, "We need 5 orcs for progression test")
	for orc in orc_mobs:
		EventBus.enemy_died.emit(orc)
		await tree.process_frame
		
	assert_true(world_manager.boss_spawned, "Boss must spawn after 5 orcs killed")
	
	var boss := world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss instance should be valid")
	
	var boss_hud := world_manager.get_node("UI/BossHUDContainer") as Control
	assert_true(boss_hud.visible, "Boss health HUD must be visible")
	
	EventBus.enemy_died.emit(boss)
	await tree.process_frame
	assert_false(boss_hud.visible, "Boss health HUD should hide after boss death")

func scenario_survival_stormy_forest() -> void:
	# Scenario 2: Sinh tồn trong bão sét khi đang thám hiểm rừng
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	
	player.global_position = Vector3(20.0, 0.2, -20.0)
	await tree.process_frame
	
	world_manager.weather_state = "storm"
	world_manager.weather_duration = 60.0
	EventBus.weather_changed.emit("storm")
	await tree.process_frame
	
	player.health_component.take_damage(20.0, null)
	await tree.process_frame
	
	var ui := world_manager.get_node("UI") as CanvasLayer
	var found_damage_label := false
	for child in ui.get_children():
		if child is Label and child.text == "20":
			found_damage_label = true
			break
	assert_true(found_damage_label, "Damage label for lightning strike should spawn")
	
	var hc := player.get_node("HealthComponent") as HealthComponent
	assert_true(hc.current_health < hc.max_health, "Player health should decrease")

func scenario_mob_kiting_aggro() -> void:
	# Scenario 3: Lùa và thả diều nhiều quái vật lên địa hình gò đất
	var player := tree.get_first_node_in_group("player") as Player
	var fb := world_instance.get_node("Forest") as Node
	assert_not_null(player, "Player must exist")
	
	var orcs: Array[CharacterBody3D] = []
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			orcs.append(child as CharacterBody3D)
			if orcs.size() >= 2:
				break
				
	assert_true(orcs.size() >= 2, "Need at least 2 orcs for aggro scenario")
	
	player.global_position = orcs[0].global_position + Vector3(1.0, 0.0, 1.0)
	orcs[1].global_position = orcs[0].global_position + Vector3(-1.0, 0.0, -1.0)
	for i in range(10):
		await tree.process_frame
		
	player.global_position += Vector3(5.0, 0.0, 5.0)
	for i in range(10):
		await tree.process_frame
		
	EventBus.enemy_damaged.emit(orcs[0], 15.0, orcs[0].global_position)
	EventBus.enemy_damaged.emit(orcs[1], 25.0, orcs[1].global_position)
	await tree.process_frame
	
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	var ui := world_manager.get_node("UI") as CanvasLayer
	var label_count := 0
	for child in ui.get_children():
		if child is Label:
			label_count += 1
	assert_true(label_count >= 2, "Multiple damage popups should coexist on HUD")
