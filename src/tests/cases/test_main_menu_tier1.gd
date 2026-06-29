extends "res://src/tests/base_test_case.gd"

# Main menu scene-transition contract tests.

func test_new_game_scene_path_exists() -> void:
	assert_eq(
		MainMenu.GAME_SCENE_PATH,
		"res://src/world/world.tscn",
		"Start must target the real world scene"
	)
	assert_true(
		ResourceLoader.exists(MainMenu.GAME_SCENE_PATH, "PackedScene"),
		"Configured game scene must exist"
	)

func test_legacy_save_scene_resolves_to_world() -> void:
	var menu := MainMenu.new()
	tree.root.add_child(menu)
	var resolved_path := menu._resolve_game_scene_path(MainMenu.LEGACY_GAME_SCENE_PATH)
	assert_eq(
		resolved_path,
		MainMenu.GAME_SCENE_PATH,
		"Legacy saves must migrate to the current world scene"
	)
	menu.queue_free()

func test_save_manager_default_scene_matches_main_menu() -> void:
	assert_eq(
		SaveManager.DEFAULT_GAME_SCENE_PATH,
		MainMenu.GAME_SCENE_PATH,
		"Save and menu scene defaults must not diverge"
	)
