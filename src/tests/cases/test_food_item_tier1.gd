extends "res://src/tests/base_test_case.gd"

# Tier 1 food-atlas integration tests.


func test_food_atlas_has_four_square_transparent_cells() -> void:
	var texture := load("res://food_health.png") as Texture2D
	assert_not_null(texture, "Food atlas must load")
	assert_eq(texture.get_width(), 1024, "Food atlas must contain four 256px cells")
	assert_eq(texture.get_height(), 256, "Food atlas cells must be square")

	var image := texture.get_image()
	for cell_index in range(4):
		var cell_start := cell_index * 256
		assert_true(image.get_pixel(cell_start + 4, 4).a < 0.05, "Every food cell must have a transparent background")
		assert_true(image.get_pixel(cell_start + 128, 128).a > 0.5, "Every food cell must contain a visible fruit")


func test_food_item_uses_atlas_frame_without_secondary_region_crop() -> void:
	for food_type in range(4):
		var item := FoodItem.new()
		item.food_type = food_type as FoodItem.FoodType
		world_instance.add_child(item)
		await tree.process_frame

		assert_eq(item.sprite.hframes, 4, "Food item must split the atlas into four frames")
		assert_eq(item.sprite.frame, food_type, "Food type must select its matching atlas frame")
		assert_false(item.sprite.region_enabled, "Food item must not crop a second 64px region")
		assert_almost_eq(item.sprite.pixel_size, 0.0035, 0.0001, "Food pickup must remain readable without dominating the player")
		item.queue_free()
		await tree.process_frame


func test_all_food_types_restore_player_to_max_health() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	assert_not_null(health, "Player health component must exist")
	
	health.max_health = 100.0
	
	for food_type in range(4):
		health.current_health = 35.0
		var item := FoodItem.new()
		item.food_type = food_type as FoodItem.FoodType
		item.heal_amount = 1.0
		world_instance.add_child(item)
		await tree.process_frame
		
		item.call("_apply_effect", player)
		
		assert_eq(health.current_health, health.max_health, "Every spawned fruit should restore player to full health")
		
		item.queue_free()
		await tree.process_frame
