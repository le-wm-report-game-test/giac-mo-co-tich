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
	assert_false(text.visible, "Player health text should stay hidden in the main HUD")
	assert_eq(bar.value, 75.0, "Progress bar value should match current health")
	assert_eq(text.text, "75 / 100", "Label text should display current/max health")

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
	
	assert_eq(orc_count_label.text, "Orc đã hạ: 1/5", "Orc counter label should show progress toward the boss")
	
	dummy_orc.queue_free()
	await tree.process_frame

func test_boss_hud_is_removed() -> void:
	# Boss đã có máu trên đầu nên không còn thanh HUD riêng trên màn hình.
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var boss_container: Control = world_manager.get_node_or_null("UI/BossHUDContainer")
	assert_null(boss_container, "Boss HUD container should not exist anymore")

func test_minimap_player_dot_uses_world_position() -> void:
	# Chấm xanh phải đi theo vị trí thật của player trên map, không đứng yên ở tâm
	var minimap := Minimap.new()
	minimap.setup(Vector2(100.0, 100.0))
	minimap.map_limit = 50.0
	minimap.update_positions(Vector3.ZERO, [])
	
	var center_pos: Vector2 = minimap.call("_world_to_canvas", Vector3.ZERO)
	var moved_pos: Vector2 = minimap.call("_world_to_canvas", Vector3(25.0, 0.0, -25.0))
	
	assert_eq(center_pos, Vector2(50.0, 50.0), "World origin should map to minimap center")
	assert_true(moved_pos.x > center_pos.x, "Moving right in world should move blue dot right on minimap")
	assert_true(moved_pos.y < center_pos.y, "Moving forward in world should move blue dot upward on minimap")

func test_minimap_red_markers_only_include_orcs() -> void:
	# Chỉ Orc/Boss được hiện chấm đỏ; animal không được hiện trên minimap
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	
	var animal := AnimalBot.new()
	animal.add_to_group("animals")
	var orc := OrcMob.new()
	orc.add_to_group("orc_mobs")
	
	assert_false(world_manager.call("_is_minimap_orc_marker", animal), "Animals must not be red minimap markers")
	assert_true(world_manager.call("_is_minimap_orc_marker", orc), "Orcs must be red minimap markers")
	
	animal.free()
	orc.free()

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
	assert_true(damage_label is DamagePopup, "Damage label should use the reusable DamagePopup component")
	assert_true(damage_label.get_theme_font_size("font_size") >= 44, "Damage font must be large enough to read during combat")
	assert_true(damage_label.get_theme_constant("outline_size") >= 7, "Damage number needs a strong outline on forest backgrounds")

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
	
	EventBus.enemy_damaged.emit(dummy_enemy, 20.0, Vector3(2.0, 0.0, 2.0), false)
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

func test_critical_damage_number_has_impact_hierarchy() -> void:
	# Critical hit phải có số lớn và nhãn nhấn mạnh riêng, không giả lập True Damage.
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	var ui: CanvasLayer = world_manager.get_node_or_null("UI")

	world_manager.call("_spawn_damage_number", 120.0, Vector3.ZERO, DamagePopup.Kind.CRITICAL)
	await tree.process_frame

	var popup: DamagePopup = null
	for child in ui.get_children():
		if child is DamagePopup and child.popup_kind == DamagePopup.Kind.CRITICAL:
			popup = child as DamagePopup
			break

	assert_not_null(popup, "Critical damage should spawn a DamagePopup")
	if popup == null:
		return

	assert_eq(popup.text, "120", "Critical popup should keep the numeric value separate from its tag")
	assert_true(popup.get_theme_font_size("font_size") >= 60, "Critical damage must dominate the visual hierarchy")
	assert_true(popup.get_theme_constant("outline_size") >= 10, "Critical damage needs a stronger outline")
	var impact_tag := popup.get_node_or_null("ImpactTag") as Label
	assert_not_null(impact_tag, "Critical damage must include an impact tag")
	assert_eq(impact_tag.text, "CRITICAL!", "Critical tag must describe the actual combat event")
