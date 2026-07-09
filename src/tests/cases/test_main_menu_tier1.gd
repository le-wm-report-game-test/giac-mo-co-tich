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

func test_continue_button_reflects_save_state() -> void:
	SaveManager.delete_save()
	var menu := MainMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame

	var continue_button := menu.get_node_or_null("ButtonBackdrop/ButtonContainer/ContinueEntry/Continue") as Button
	var continue_hint := menu.get_node_or_null("ButtonBackdrop/ButtonContainer/ContinueEntry/ContinueHint") as Label
	assert_not_null(continue_button, "Continue button must exist")
	assert_not_null(continue_hint, "Continue hint must exist")
	assert_true(continue_button.disabled, "Continue should be disabled with no save data")
	assert_eq(continue_hint.text, "Chưa có dữ liệu lưu.", "Continue hint should explain the disabled state")

	SaveManager.save_progress({})
	menu.call("_refresh_continue_state")
	assert_false(continue_button.disabled, "Continue should be enabled after a save exists")
	assert_eq(continue_hint.text, "Tiếp tục từ lần lưu gần nhất.", "Continue hint should describe the resume action")

	menu.queue_free()
	SaveManager.delete_save()
