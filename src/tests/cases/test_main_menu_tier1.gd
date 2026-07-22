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
	assert_not_null(continue_button, "Continue button must exist")
	assert_true(continue_button.disabled, "Continue should be disabled with no save data")
	assert_eq(continue_button.tooltip_text, "Hãy bắt đầu trò chơi mới để tạo dữ liệu lưu.", "Disabled continue should explain how to unlock resume")

	SaveManager.save_progress({})
	menu.call("_refresh_continue_state")
	assert_false(continue_button.disabled, "Continue should be enabled after a save exists")
	assert_eq(continue_button.tooltip_text, "", "Enabled continue should not keep the disabled tooltip")

	menu.queue_free()
	SaveManager.delete_save()

func test_main_menu_priority3_layout_is_more_breathable() -> void:
	var menu := MainMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame

	var continue_button := menu.get_node_or_null("ButtonBackdrop/ButtonContainer/ContinueEntry/Continue") as Button
	var quit_entry := menu.get_node_or_null("ButtonBackdrop/ButtonContainer/QuitEntry") as VBoxContainer
	var backdrop := menu.get_node_or_null("ButtonBackdrop") as PanelContainer
	var glow := menu.get_node_or_null("ButtonGlow") as ColorRect
	assert_not_null(continue_button, "Continue button must still exist after menu polish")
	assert_not_null(backdrop, "Button backdrop must still exist after menu polish")
	assert_not_null(glow, "Button glow layer must exist behind the menu buttons")
	assert_eq(continue_button.custom_minimum_size, Vector2(MainMenu.BUTTON_WIDTH, MainMenu.BUTTON_HEIGHT), "Menu buttons should use the configured layout size")
	assert_eq(backdrop.offset_top, MainMenu.BACKDROP_TOP, "Button cluster should sit lower to avoid crowding the key art")
	assert_true(glow.offset_top < backdrop.offset_top, "Glow layer should start above the backdrop to soften readability against the art")
	assert_true(backdrop.get_global_rect().encloses(quit_entry.get_global_rect()), "All menu entries must stay inside the backdrop")

	menu.queue_free()

func test_guide_button_is_between_continue_and_settings() -> void:
	var menu := MainMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame
	var container := menu.get_node("ButtonBackdrop/ButtonContainer") as VBoxContainer
	var guide_entry := container.get_node("GuideEntry") as VBoxContainer
	var continue_entry := container.get_node("ContinueEntry") as VBoxContainer
	var settings_entry := container.get_node("SettingsEntry") as VBoxContainer
	var guide_button := guide_entry.get_node("Guide") as Button
	assert_true(continue_entry.get_index() < guide_entry.get_index(), "Guide must appear after Continue")
	assert_true(guide_entry.get_index() < settings_entry.get_index(), "Guide must appear before Settings")
	guide_button.emit_signal("pressed")
	await tree.process_frame
	var dialog := menu.get_node_or_null("MainMenuGuideDialog") as CanvasLayer
	assert_not_null(dialog, "Guide button must create the guide dialog")
	assert_true(dialog.visible, "Guide dialog must be visible after opening")
	menu.queue_free()

func test_guide_dialog_content_and_focus_contract() -> void:
	var menu := MainMenu.new()
	tree.root.add_child(menu)
	await tree.process_frame
	var guide_button := menu.get_node("ButtonBackdrop/ButtonContainer/GuideEntry/Guide") as Button
	guide_button.emit_signal("pressed")
	await tree.process_frame
	var dialog := menu.get_node("MainMenuGuideDialog") as CanvasLayer
	var content := dialog.get_node("GuideOverlay/GuidePanel/GuideContent") as VBoxContainer
	var objective := content.get_node("ObjectiveText") as Label
	var close_button := content.get_node("CloseGuideButton") as Button
	assert_true(objective.text.contains("5 Orc"), "Guide must explain the Orc objective")
	assert_true(objective.text.contains("Chằn Tinh"), "Guide must name the boss objective")
	assert_eq(close_button, dialog.get_viewport().gui_get_focus_owner(), "Close action must receive focus")
	close_button.emit_signal("pressed")
	await tree.process_frame
	assert_false(dialog.visible, "Close action must hide the guide")
	assert_eq(guide_button, dialog.get_viewport().gui_get_focus_owner(), "Focus must return to Guide")
	menu.queue_free()
