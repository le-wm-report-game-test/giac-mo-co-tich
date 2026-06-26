# res://src/tests/cases/test_hud_ui_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 E2E tests for HUD UI Updates.
# Technical comments in English, Vietnamese for game logic explanations.

func test_player_health_bar_update() -> void:
	# Cập nhật thanh máu của Player khi nhận signal
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	EventBus.player_health_changed.emit(75.0, 100.0)
	await tree.process_frame
	
	var bar: TextureProgressBar = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar")
	var text: Label = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText")
	
	assert_not_null(bar, "Player health progress bar must exist")
	assert_not_null(text, "Player health label must exist")
	assert_eq(bar.value, 75.0, "Progress bar value should match current health")
	assert_eq(text.text, "75/100", "Label text should display current/max health")

func test_orc_counter_update() -> void:
	# Tăng bộ đếm quái đã diệt trên HUD khi Orc chết
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var orc_count_label: Label = world_manager.get_node_or_null("UI/OrcCounter/OrcCountLabel")
	assert_not_null(orc_count_label, "Orc count label must exist")
	
	var dummy_orc: CharacterBody3D = CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	EventBus.enemy_died.emit(dummy_orc)
	await tree.process_frame
	
	var target_count: int = world_manager.get("orcs_to_kill_for_boss") as int
	assert_eq(orc_count_label.text, "1/%d" % target_count, "Orc counter label should show 1 killed")
	
	dummy_orc.queue_free()
	await tree.process_frame

func test_boss_health_bar_appears() -> void:
	# Hiển thị thanh máu Boss khi Boss xuất hiện
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var boss_container: Control = world_manager.get_node_or_null("UI/BossHealthContainer")
	assert_not_null(boss_container, "Boss health container must exist")
	assert_false(boss_container.visible, "Boss health container should be hidden initially")
	
	world_manager.call("_show_boss_health_bar")
	assert_true(boss_container.visible, "Boss health container should be visible after showing")

func test_player_damage_number_spawn() -> void:
	# Hiển thị số sát thương (đỏ) khi Player bị tấn công
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")
	assert_not_null(ui, "UI CanvasLayer must exist")
	
	var initial_labels: int = 0
	for child in ui.get_children():
		if child is Label and child.text.is_valid_int():
			initial_labels += 1
			
	EventBus.player_took_damage.emit(15.0, Vector3(0.0, 0.0, 0.0))
	await tree.process_frame
	
	var current_labels: int = 0
	var damage_label: Label = null
	for child in ui.get_children():
		if child is Label and child.text.is_valid_int():
			current_labels += 1
			damage_label = child as Label
			
	assert_eq(current_labels, initial_labels + 1, "Exactly one damage label should spawn")
	assert_not_null(damage_label, "Damage label reference must be valid")
	assert_eq(damage_label.text, "15", "Damage number text should match damage amount")
	assert_eq(damage_label.z_index, 100, "Damage label z_index must be 100")

func test_enemy_damage_number_spawn() -> void:
	# Hiển thị số sát thương (trắng hoặc vàng crit) khi Enemy bị đánh
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")
	assert_not_null(ui, "UI CanvasLayer must exist")
	
	var initial_labels: int = 0
	for child in ui.get_children():
		if child is Label:
			initial_labels += 1
			
	var dummy_enemy: Node3D = Node3D.new()
	world_instance.add_child(dummy_enemy)
	
	EventBus.enemy_damaged.emit(dummy_enemy, 20.0, Vector3(2.0, 0.0, 2.0))
	await tree.process_frame
	
	var current_labels: int = 0
	var damage_label: Label = null
	for child in ui.get_children():
		if child is Label:
			current_labels += 1
			damage_label = child as Label
			
	assert_true(current_labels > initial_labels, "At least one damage label should spawn")
	assert_not_null(damage_label, "Damage label must be valid")
	assert_true(damage_label.text.to_int() >= 20, "Damage amount should be at least base damage")
	
	dummy_enemy.queue_free()
	await tree.process_frame
