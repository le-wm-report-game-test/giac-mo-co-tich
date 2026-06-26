# proposed_test_boss_lifecycle.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh
# Technical comments in English, Vietnamese for game logic explanations.

func run() -> void:
	# 1. Kiểm tra ban đầu: Boss chưa xuất hiện
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 0, "No boss should be spawned initially")
	
	var world_manager := world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	# 2. Giả lập giết 5 Orc để kích hoạt spawn Boss
	var orcs_to_kill := world_manager.get("orcs_to_kill_for_boss") as int
	assert_true(orcs_to_kill > 0, "orcs_to_kill_for_boss should be positive")
	
	# Tạo dummy orc để giả lập sự kiện chết gửi qua EventBus
	var dummy_orc := CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	# Bắn tín hiệu enemy_died qua EventBus để tăng orcs_killed
	for i in range(orcs_to_kill):
		EventBus.enemy_died.emit(dummy_orc)
		await tree.process_frame
		
	# Dọn dẹp dummy orc
	dummy_orc.queue_free()
	await tree.process_frame
	
	# 3. Kiểm tra xem Boss đã spawn chưa
	bosses = tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "Boss should spawn after target orcs killed")
	
	var boss := bosses[0] as CharacterBody3D
	assert_not_null(boss, "Boss instance should be valid")
	
	# 4. Kiểm tra chỉ số của Boss
	var health_comp = boss.get_node_or_null("HealthComponent")
	assert_not_null(health_comp, "Boss should have a HealthComponent")
	assert_eq(health_comp.get("max_health"), 300.0, "Boss max health should be 300")
	assert_eq(boss.get("speed"), 1.5, "Boss speed should be 1.5")
	
	# 5. Kiểm tra HUD hiển thị thanh máu Boss
	var boss_hud_container = world_manager.get_node_or_null("UI/BossHealthContainer")
	assert_not_null(boss_hud_container, "HUD Boss container should exist")
	assert_true(boss_hud_container.visible, "HUD Boss container should be visible")
