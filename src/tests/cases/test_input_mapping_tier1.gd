extends "res://src/tests/base_test_case.gd"


func test_player_setup_preserves_existing_move_binding() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return
	var original_events: Array[InputEvent] = InputMap.action_get_events(&"move_left").duplicate(true)
	InputMap.action_erase_events(&"move_left")
	var custom_event := InputEventKey.new()
	custom_event.physical_keycode = KEY_F
	custom_event.keycode = KEY_F
	InputMap.action_add_event(&"move_left", custom_event)

	player._setup_input_actions()
	var configured_events := InputMap.action_get_events(&"move_left")
	var preserved := configured_events.size() == 1
	if preserved:
		var configured_key := configured_events[0] as InputEventKey
		preserved = configured_key != null and configured_key.physical_keycode == KEY_F

	InputMap.action_erase_events(&"move_left")
	for event in original_events:
		InputMap.action_add_event(&"move_left", event)
	assert_true(preserved, "Player setup must not erase an existing custom binding")
