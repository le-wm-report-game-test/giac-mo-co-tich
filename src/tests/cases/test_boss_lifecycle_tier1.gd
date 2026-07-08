# res://src/tests/cases/test_boss_lifecycle_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh - Tier 1 (Happy Path)
# Technical comments in English, Vietnamese for game logic explanations.

var _world_manager: WorldManager = null

func setup() -> void:
	await super.setup()
	_world_manager = world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(_world_manager, "WorldManager must exist")

func test_boss_not_spawned_initially() -> void:
	assert_false(_world_manager.boss_spawned, "Boss should not be spawned initially")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 0, "No boss in group 'boss' initially")
	var hud_bar: Control = _world_manager.get_node_or_null("UI/BossHUDContainer") as Control
	assert_true(hud_bar == null or not hud_bar.visible, "Boss health UI should be hidden/non-existent initially")

func test_boss_spawn_trigger() -> void:
	_world_manager.orcs_to_kill_for_boss = 3
	var dummy_orc := CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	for i in range(3):
		EventBus.enemy_died.emit(dummy_orc)
		await wait_physics_frames(1)
		
	dummy_orc.queue_free()
	await wait_physics_frames(1)
	
	assert_true(_world_manager.boss_spawned, "Boss should spawn after 3 orcs killed")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "There should be exactly one boss in group 'boss'")

func test_boss_initial_properties() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss instance should be valid")
	assert_eq(boss.name, "BossChằnTinh", "Boss node name should match")
	assert_true(boss.is_in_group("boss") and boss.is_in_group("orc_mobs"), "Boss should be in groups")
	assert_eq(boss.scale, Vector3(1.0, 1.0, 1.0), "Boss scale should be 1.0")
	assert_eq(boss.health_component.max_health, 300.0, "Boss max health should be 300")
	assert_eq(boss.speed, 1.5, "Boss speed should be 1.5")

func test_boss_hud_visibility_on_spawn() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var hud_bar: Control = world_instance.get_node_or_null("WorldManager/UI/BossHUDContainer") as Control
	assert_not_null(hud_bar, "HUD BossHUDContainer should exist")
	assert_true(hud_bar.visible, "HUD BossHUDContainer should be visible")

func test_boss_death_sequence() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	# Gây sát thương làm boss chết
	boss.health_component.take_damage(300.0)
	await wait_physics_frames(10)
	
	# Trạng thái của OrcMob lúc chết là State.DEATH (5)
	assert_eq(boss.get("current_state"), 5, "Boss should be in State.DEATH (5)")
	
	# Chờ tween fade-out hoàn tất và giải phóng node (2.5s)
	await tree.create_timer(2.5).timeout
	assert_false(is_instance_valid(boss), "Boss should be freed and invalid")
	
	var hud_bar: Control = world_instance.get_node_or_null("WorldManager/UI/BossHUDContainer") as Control
	assert_true(hud_bar == null or not hud_bar.visible, "HUD BossHUDContainer should be hidden on boss death")

func test_boss_victory_dialog_targets_main_menu() -> void:
	# Khi boss bị đánh bại, hiện lời chúc mừng, bài văn và nút về menu chính
	var dialog := VictoryDialog.new()
	world_instance.add_child(dialog)
	await tree.process_frame
	
	var boss := Node3D.new()
	boss.add_to_group("boss")
	
	dialog.call("_on_enemy_died", boss)
	await tree.process_frame
	
	var overlay := dialog.get_node_or_null("VictoryOverlay") as Control
	assert_not_null(overlay, "Victory overlay should appear after boss death")
	var title := dialog.get_node_or_null("VictoryOverlay/VictoryPanel/VBoxContainer/VictoryTitle") as Label
	assert_not_null(title, "Victory title should exist")
	assert_true(title.text.contains("Chúc mừng"), "Victory title should congratulate the player")
	assert_true(title.custom_minimum_size.x >= 600.0, "Victory title should reserve enough width to avoid per-character wrapping")
	assert_eq(title.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Victory title should fill the panel width")
	var body := dialog.get_node_or_null("VictoryOverlay/VictoryPanel/VBoxContainer/StoryScroll/VictoryBody") as RichTextLabel
	assert_not_null(body, "Victory story body should exist")
	assert_true(body.text.contains("Thạch Sanh"), "Victory story should tell the Thach Sanh ending")
	assert_true(body.text.contains("Chằn Tinh"), "Victory story should mention the defeated boss")
	assert_true(body.custom_minimum_size.x >= 600.0, "Victory body should reserve enough width to avoid vertical letter wrapping")
	assert_eq(body.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Victory body should fill the scroll area width")
	var return_button := dialog.get_node_or_null("VictoryOverlay/VictoryPanel/VBoxContainer/ReturnToMenuButton") as Button
	assert_not_null(return_button, "Victory dialog should provide a manual return button")
	assert_eq(return_button.text, "TRỞ VỀ MENU", "Victory dialog should not auto-redirect; it should expose a menu button")
	var chime_player := dialog.get_node_or_null("VictoryChimePlayer") as AudioStreamPlayer
	assert_not_null(chime_player, "Victory dialog should create the victory chime player")
	assert_not_null(chime_player.stream, "Victory chime player should have the imported MP3 stream")
	assert_eq(VictoryDialog.MAIN_MENU_SCENE_PATH, "res://src/ui/MainMenu.tscn", "Victory should return to main menu")
	
	boss.free()
	dialog.queue_free()
	await tree.process_frame
