# res://src/tests/cases/test_hud_ui_tier1.gd
extends "res://src/tests/base_test_case.gd"

func test_player_health_bar_update() -> void:
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")

	EventBus.player_health_changed.emit(75.0, 100.0)
	await tree.process_frame

	var bar: TextureProgressBar = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar")
	var text: Label = world_manager.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText")

	assert_not_null(bar, "Player health progress bar must exist")
	assert_not_null(text, "Player health label must exist")
	assert_false(text.visible, "Player health text should stay hidden")
	assert_eq(bar.value, 75.0, "Progress bar value should match current health")
	assert_eq(text.text, "75 / 100", "Label text should display current/max health")

func test_orc_counter_update() -> void:
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")

	var orc_count_label: Label = world_manager.get_node_or_null("UI/OrcCounter/OrcCountLabel")
	assert_not_null(orc_count_label, "Orc count label must exist")

	var dummy_orc: CharacterBody3D = CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)

	EventBus.enemy_died.emit(dummy_orc)
	await tree.process_frame

	assert_eq(orc_count_label.text, "Đã hạ 1", "Orc counter should show progress")
	dummy_orc.queue_free()
	await tree.process_frame

func test_boss_hud_is_hidden_before_spawn() -> void:
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	var boss_bar := world_manager.get_node_or_null("UI/BossHealthBar") as BossHealthBar
	assert_null(boss_bar, "Boss screen HUD should not exist before spawn")

func test_boss_health_bar_uses_chan_tinh_name() -> void:
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")

	var dummy_boss := Node3D.new()
	dummy_boss.add_to_group("boss")
	var health := HealthComponent.new()
	health.max_health = 180.0
	health.current_health = 180.0
	health.name = "HealthComponent"
	dummy_boss.add_child(health)
	world_instance.add_child(dummy_boss)

	world_manager.call("_show_boss_health_bar", dummy_boss)
	await tree.process_frame

	var boss_name := world_manager.get_node_or_null("UI/BossHealthBar/BossBarName") as Label
	assert_not_null(boss_name, "Boss health bar should create a name label")
	assert_eq(boss_name.text, "Chằn Tinh", "Boss HUD should show the approved display name")

	var boss_fill := world_manager.get_node_or_null("UI/BossHealthBar/BossBarFill") as TextureProgressBar
	assert_not_null(boss_fill, "Boss HUD should create the red health fill")
	assert_eq(boss_fill.value, 180.0, "Boss HUD should start at full health")
	assert_eq(boss_fill.max_value, 180.0, "Boss HUD max value should match boss health")
	assert_eq(boss_fill.tint_progress, Color(0.85, 0.18, 0.12, 1.0), "Boss HUD fill should be red")

	var boss_bar := world_manager.get_node_or_null("UI/BossHealthBar") as BossHealthBar
	var bar_rect := boss_bar.get_global_rect()
	var name_rect := boss_name.get_global_rect()
	assert_true(
		bar_rect.encloses(name_rect),
		"Boss HUD root bounds should contain the title instead of placing it above the frame"
	)
	assert_true(
		Rect2(Vector2.ZERO, boss_bar.get_viewport_rect().size).encloses(name_rect),
		"Boss title should remain fully inside the viewport"
	)

	dummy_boss.queue_free()
	await tree.process_frame

func test_minimap_player_dot_uses_world_position() -> void:
	var minimap := Minimap.new()
	minimap.setup(Vector2(100.0, 100.0))
	minimap.map_limit = 50.0
	minimap.update_positions(Vector3.ZERO, [])
	var center_pos: Vector2 = minimap.call("_world_to_canvas", Vector3.ZERO)
	var moved_pos: Vector2 = minimap.call("_world_to_canvas", Vector3(25.0, 0.0, -25.0))
	assert_eq(center_pos, Vector2(50.0, 50.0), "World origin should map to minimap center")
	assert_true(moved_pos.x > center_pos.x, "Moving right should move dot right")
	assert_true(moved_pos.y < center_pos.y, "Moving forward should move dot upward")
	minimap.free()

func test_minimap_red_markers_only_include_orcs() -> void:
	var world_manager: Node = world_instance.get_node_or_null("WorldManager")
	assert_not_null(world_manager, "WorldManager must exist")
	var animal := AnimalBot.new()
	animal.add_to_group("animals")
	var orc := OrcMob.new()
	orc.add_to_group("orc_mobs")
	assert_false(world_manager.call("_is_minimap_orc_marker", animal), "Animals must not be markers")
	assert_true(world_manager.call("_is_minimap_orc_marker", orc), "Orcs must be markers")
	animal.free()
	orc.free()

func test_minimap_marker_types_are_distinct() -> void:
	var minimap := Minimap.new()
	minimap.setup(Vector2(120.0, 120.0))
	var markers: Array[Dictionary] = [
		{"position": Vector3(4.0, 0.0, 0.0), "marker_type": Minimap.MARKER_ORC},
		{"position": Vector3(8.0, 0.0, 0.0), "marker_type": Minimap.MARKER_BOSS},
		{"position": Vector3(12.0, 0.0, 0.0), "marker_type": Minimap.MARKER_ITEM},
	]

	minimap.update_positions(Vector3.ZERO, markers)

	assert_eq(minimap._markers.size(), 3, "Minimap should keep every marker payload")
	assert_eq(minimap._markers[0].get("marker_type"), Minimap.MARKER_ORC, "Orc marker type should be preserved")
	assert_eq(minimap._markers[1].get("marker_type"), Minimap.MARKER_BOSS, "Boss marker type should be preserved")
	assert_eq(minimap._markers[2].get("marker_type"), Minimap.MARKER_ITEM, "Item marker type should be preserved")
	minimap.free()

func test_player_damage_number_spawn() -> void:
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
	assert_eq(damage_label.text, "15", "Damage number should match amount")
	assert_eq(damage_label.z_index, 100, "Damage label z_index must be 100")
	assert_true(damage_label is DamagePopup, "Should use DamagePopup component")

func test_enemy_damage_number_spawn() -> void:
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
	dummy_enemy.queue_free()
	await tree.process_frame

func test_critical_damage_number_has_impact_hierarchy() -> void:
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
	assert_eq(popup.text, "120", "Critical popup should keep numeric value")
	var impact_tag := popup.get_node_or_null("ImpactTag") as Label
	assert_not_null(impact_tag, "Critical damage must include an impact tag")
	assert_eq(impact_tag.text, "CRITICAL!", "Critical tag must describe the event")
