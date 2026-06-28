# res://src/tests/cases/test_terrain_collision_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử va chạm địa hình - Tier 1 (Happy Path)
# Technical comments in English, Vietnamese for game logic explanations.
#
# The player CollisionShape3D offsets the capsule centre by +0.8 (height=1.6),
# which means the capsule bottom sits at the player origin. When the feet
# touch ground Y=0, the player centre is exactly at Y=0 too.
# Expectations all assume the ground top is exactly at Y=0 (flat) or
# `sample_height(x, z)` (hills).

func test_flat_ground_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	player.global_position = Vector3(0.0, 1.0, 0.0)
	await tree.create_timer(0.5).timeout
	assert_true(player.is_on_floor(), "Player should be on flat ground floor")
	assert_almost_eq(player.global_position.y, 0.0, 0.1, "Player Y should sit at ground surface (0m)")

func test_hill_peak_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Hill 1 center (10, -10), radius 5, height 1.5 → sample_height returns 1.5
	# Player feet rest at the hill peak → player centre = 1.5m.
	player.global_position = Vector3(10.0, 3.0, -10.0)
	await tree.create_timer(0.6).timeout
	assert_true(player.is_on_floor(), "Player should be on hill peak floor")
	assert_almost_eq(player.global_position.y, 1.5, 0.15, "Player Y should sit on Hill 1 peak (1.5m)")

func test_hill_slope_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Slope at x = 12.0, z = -10.0 is between ring vertices of the fan mesh.
	# The analytic hill formula gives ~0.54m there, but the fan mesh is
	# coarser so the player rests on whichever triangle is closest (~0.86m).
	# Either is correct behaviour — we just need to confirm the player is
	# safely above flat ground.
	player.global_position = Vector3(12.0, 3.0, -10.0)
	await tree.create_timer(0.8).timeout
	assert_true(player.is_on_floor(), "Player should be on hill slope floor")
	assert_true(player.global_position.y > 0.3, "Player Y should be elevated above flat ground on slope")
	assert_true(player.global_position.y < 1.8, "Player Y should be below peak height (1.5m)")

func test_gravity_fall_on_ground() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	player.global_position = Vector3(-5.0, 15.0, -5.0)
	await wait_physics_frames(2)
	assert_false(player.is_on_floor(), "Player should be in mid-air initially")
	await tree.create_timer(2.0).timeout
	assert_true(player.is_on_floor(), "Player should land on flat ground after fall")
	assert_almost_eq(player.global_position.y, 0.0, 0.1, "Player Y should settle on flat ground")

func test_multiple_hills_heights() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")

	# Hill 2: center (-10, 12), radius 4, height 1.2 → sample_height 1.2 → player Y = 1.2
	player.global_position = Vector3(-10.0, 3.0, 12.0)
	await tree.create_timer(0.6).timeout
	assert_true(player.is_on_floor(), "Player should be on Hill 2 floor")
	assert_almost_eq(player.global_position.y, 1.2, 0.15, "Player Y should sit on Hill 2 peak")

	# Hill 3: center (22, 14), radius 4.5, height 1.0 → sample_height 1.0 → player Y = 1.0
	player.global_position = Vector3(22.0, 3.0, 14.0)
	await tree.create_timer(0.7).timeout
	assert_true(player.is_on_floor(), "Player should be on Hill 3 floor")
	assert_almost_eq(player.global_position.y, 1.0, 0.15, "Player Y should sit on Hill 3 peak")
