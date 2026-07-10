# res://src/tests/cases/test_hud_ui_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 E2E edge-case tests for HUD UI Updates.
# Technical comments in English, Vietnamese for game logic explanations.

func test_player_health_underflow_and_overflow() -> void:
	# Kiểm tra thanh máu hoạt động bình thường khi máu âm hoặc vượt tối đa
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	EventBus.player_health_changed.emit(-50.0, 100.0)
	await tree.process_frame
	var bar: TextureProgressBar = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar")
	var text: Label = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText")
	assert_false(text.visible, "Hidden HUD text should remain hidden even on health edge cases")
	assert_eq(bar.value, -50.0, "Progress bar should clamp or hold negative health value")
	assert_eq(text.text, "-50 / 100", "Label text should display negative health")
	
	EventBus.player_health_changed.emit(150.0, 100.0)
	await tree.process_frame
	assert_eq(bar.value, 150.0, "Progress bar value should match raw current health")
	assert_eq(text.text, "150 / 100", "Label text should display health overflow")

func test_damage_number_offscreen() -> void:
	# Kiểm tra tạo số sát thương khi ở quá xa camera (không gây lỗi unproject)
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")
	var initial_children: int = ui.get_child_count()
	
	EventBus.player_took_damage.emit(10.0, Vector3(10000.0, -10000.0, 10000.0))
	await tree.process_frame
	
	var current_children: int = ui.get_child_count()
	assert_true(current_children >= initial_children, "Spawning offscreen damage should not crash")

func test_rapid_damage_spawning() -> void:
	# Stress-test: Tạo hàng loạt số sát thương cùng lúc (không lag/crash)
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")
	var start_count: int = ui.get_child_count()
	
	for i in range(50):
		EventBus.player_took_damage.emit(1.0, Vector3(0.0, 0.0, 0.0))
		
	await tree.process_frame
	var end_count: int = ui.get_child_count()
	assert_eq(end_count, start_count + 50, "50 damage labels should be spawned concurrently")

func test_boss_hud_death_transition_is_noop() -> void:
	# Boss HUD trên màn hình đã bị bỏ nên hide/show chỉ còn là no-op.
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var boss_container: Control = world_manager.get_node_or_null("UI/BossHUDContainer")
	world_manager.call("_show_boss_health_bar")
	assert_null(boss_container, "Boss HUD container should remain absent")
	
	var dummy_boss: CharacterBody3D = CharacterBody3D.new()
	dummy_boss.add_to_group("boss")
	dummy_boss.add_to_group("orc_mobs")
	world_instance.add_child(dummy_boss)
	
	world_manager.call("_hide_boss_health_bar")
	assert_null(world_manager.get_node_or_null("UI/BossHUDContainer"), "Boss HUD container should still be absent after hide")
	
	dummy_boss.queue_free()
	await tree.process_frame

func test_hud_ui_recreation_safety() -> void:
	# Đảm bảo không trùng lặp CanvasLayer UI khi gọi tạo lại HUD
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	world_manager.call("_create_hud")
	await tree.process_frame
	
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")
	assert_not_null(ui, "UI must still exist after multiple create calls")
	var minimap_container: Control = world_manager.get_node_or_null("UI/MinimapContainer")
	var minimap_mask: Control = world_manager.get_node_or_null("UI/MinimapContainer/MinimapMask")
	var minimap: Minimap = world_manager.get_node_or_null("UI/MinimapContainer/MinimapMask/Minimap")
	assert_not_null(minimap_container, "Minimap container must survive HUD recreation")
	assert_not_null(minimap_mask, "Minimap mask must survive HUD recreation")
	assert_not_null(minimap, "Minimap control must survive HUD recreation")
	assert_eq(minimap_container.anchor_right, 1.0, "Minimap should stay anchored to the right edge")
	assert_eq(minimap_container.offset_right, -20.0, "Minimap should keep a viewport-relative right margin")
	assert_true(minimap_mask.size.x > 0.0 and minimap_mask.size.y > 0.0, "Minimap mask must keep a valid clipped size")
	assert_eq(minimap.size, minimap_mask.size, "Minimap draw area should match the clipped viewport area")
