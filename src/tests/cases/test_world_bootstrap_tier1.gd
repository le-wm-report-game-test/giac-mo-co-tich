# res://src/tests/cases/test_world_bootstrap_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 regression tests for the main scene bootstrap contract.
# Technical comments in English, Vietnamese for game logic explanations.

func test_main_scene_bootstrap_contract() -> void:
	# World phải luôn có điểm xuất phát và tạo đủ các node runtime cốt lõi.
	var spawn_point := world_instance.get_node_or_null("SpawnPoint") as Marker3D
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	var world_manager := world_instance.get_node_or_null("WorldManager") as WorldManager

	assert_not_null(spawn_point, "World scene must contain SpawnPoint")
	assert_not_null(player, "World bootstrap must create Player")
	assert_not_null(camera, "World bootstrap must create GameCamera")
	assert_not_null(world_manager, "World bootstrap must create WorldManager")

	if spawn_point != null and player != null:
		assert_almost_eq(
			player.global_position.x,
			spawn_point.global_position.x,
			0.01,
			"Player must spawn at SpawnPoint on the X axis"
		)
		assert_almost_eq(
			player.global_position.z,
			spawn_point.global_position.z,
			0.01,
			"Player must spawn at SpawnPoint on the Z axis"
		)
