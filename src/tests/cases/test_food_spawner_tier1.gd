extends "res://src/tests/base_test_case.gd"

# Tier 1 reachable food-spawn integration tests.


func test_initial_food_uses_reachable_flat_candidate_pool() -> void:
	var spawner := world_instance.get_node("FoodSpawner") as FoodSpawner
	var forest := world_instance.get_node("Forest") as ForestBuilder
	var foods := spawner.get_spawned_items()

	assert_true(spawner.get_reachable_candidate_count() > 100, "Static world must expose a useful reachable candidate pool")
	assert_eq(foods.size(), 15, "World must spawn the configured initial food count")
	for food in foods:
		var zone := forest._get_zone(food.global_position.x, food.global_position.z)
		assert_true(zone != ForestBuilder.Zone.HILL, "Food must never spawn on a hill")
		assert_true(zone != ForestBuilder.Zone.PATH, "Food must stay outside the navigation path")
		assert_true(spawner.is_position_reachable(food.global_position), "Every food must share the player's reachable component")
		assert_true(spawner._is_valid_spawn_position(food.global_position), "Every food must pass flatness and obstacle clearance")
		var expected_y := forest._get_hill_height(food.global_position.x, food.global_position.z) + spawner.pickup_ground_offset
		assert_almost_eq(food.global_position.y, expected_y, 0.01, "Food must sit at the sampled ground height")


func test_initial_food_positions_respect_minimum_spacing() -> void:
	var spawner := world_instance.get_node("FoodSpawner") as FoodSpawner
	var foods := spawner.get_spawned_items()
	for first_index in range(foods.size()):
		for second_index in range(first_index + 1, foods.size()):
			var first := Vector2(foods[first_index].global_position.x, foods[first_index].global_position.z)
			var second := Vector2(foods[second_index].global_position.x, foods[second_index].global_position.z)
			assert_true(first.distance_to(second) >= spawner.min_food_spacing, "Food pickups must not form unreadable clusters")


func test_respawn_moves_food_to_a_new_reachable_position() -> void:
	var spawner := world_instance.get_node("FoodSpawner") as FoodSpawner
	var food := spawner.get_spawned_items()[0]
	var old_position := food.global_position

	food._collected = true
	food.respawn_time = 0.0
	food._schedule_respawn()
	food._physics_process(0.1)

	var old_planar := Vector2(old_position.x, old_position.z)
	var new_planar := Vector2(food.global_position.x, food.global_position.z)
	assert_true(food.visible, "Food must become visible after relocation")
	assert_false(food._collected, "Relocated food must be collectible again")
	assert_true(old_planar.distance_to(new_planar) >= spawner.min_respawn_displacement, "Respawn must move food to a genuinely new location")
	assert_true(spawner.is_position_reachable(food.global_position), "Respawn destination must remain reachable")
	assert_true(spawner._is_valid_spawn_position(food.global_position), "Respawn destination must remain flat and obstacle-free")
