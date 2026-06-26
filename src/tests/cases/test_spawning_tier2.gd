# res://src/tests/cases/test_spawning_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 E2E edge-case tests for Spawning/Flora scattering.
# Technical comments in English, Vietnamese for game logic explanations.

func test_zero_flora_configuration() -> void:
	# Cấu hình không có cây cối không gây treo vòng lặp vô hạn
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	var custom_world := world_scene.instantiate() as Node3D
	var fb := custom_world.get_node("Forest") as Node
	
	fb.set("num_trees", 0)
	fb.set("num_bushes", 0)
	fb.set("num_grass_clumps", 0)
	fb.set("num_flowers", 0)
	fb.set("num_mushrooms", 0)
	fb.set("num_rocks", 0)
	fb.set("num_boulders", 0)
	
	tree.root.add_child(custom_world)
	await tree.process_frame
	await tree.process_frame
	
	var has_flora := false
	for child in fb.get_children():
		if child.name.begins_with("Tree") or child.name.begins_with("Bush") or child.name.begins_with("GrassTiles") or child.name.begins_with("PathTiles"):
			if not child.name.ends_with("Tiles"):
				has_flora = true
				break
				
	assert_false(has_flora, "No flora nodes should be generated when counts are 0")
	custom_world.queue_free()
	await tree.process_frame

func test_extreme_seed_values() -> void:
	# Kiểm tra các giá trị seed cực đoan (âm, 0) hoạt động ổn định
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	
	var world_low := world_scene.instantiate() as Node3D
	world_low.get_node("Forest").set("random_seed", -2147483648)
	tree.root.add_child(world_low)
	await tree.process_frame
	await tree.process_frame
	assert_not_null(world_low.get_node("Forest"), "Spawning should succeed with negative seed boundary")
	world_low.queue_free()
	
	var world_zero := world_scene.instantiate() as Node3D
	world_zero.get_node("Forest").set("random_seed", 0)
	tree.root.add_child(world_zero)
	await tree.process_frame
	await tree.process_frame
	assert_not_null(world_zero.get_node("Forest"), "Spawning should succeed with seed 0")
	world_zero.queue_free()
	await tree.process_frame

func test_mob_spawning_map_boundaries() -> void:
	# Đảm bảo quái vật không spawn vượt ra ngoài biên bản đồ (MAP_HALF = 50.0)
	var fb := world_instance.get_node("Forest") as Node
	var map_half := 50.0
	
	for child in fb.get_children():
		var is_mob := child.name.begins_with("OrcMob_") or child.name.begins_with("Cat") or child.name.begins_with("Rabbit") or child.name.begins_with("Parrot")
		if is_mob:
			var mob_node := child as Node3D
			var pos := mob_node.global_position
			assert_true(pos.x >= -map_half and pos.x <= map_half, "Mob X position should be within map boundaries")
			assert_true(pos.z >= -map_half and pos.z <= map_half, "Mob Z position should be within map boundaries")

func test_full_map_obstruction() -> void:
	# Stress-test: Bản đồ đầy vật cản vẫn chạy bình thường (thoát loop nhờ max_attempts)
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	var custom_world := world_scene.instantiate() as Node3D
	var fb := custom_world.get_node("Forest") as Node
	
	fb.set("num_trees", 5000)
	
	tree.root.add_child(custom_world)
	await tree.process_frame
	await tree.process_frame
	
	assert_true(fb.get_child_count() > 0, "Forest builder should terminate gracefully and spawn objects")
	custom_world.queue_free()
	await tree.process_frame

func test_animal_type_bounds() -> void:
	# Đảm bảo không crash khi truyền chỉ số loại động vật ngoài giới hạn
	var animal_bot_script := preload("res://src/world/animal_bot.gd") as Resource
	var test_bot := CharacterBody3D.new()
	test_bot.set_script(animal_bot_script)
	
	test_bot.set("animal_type", 99)
	world_instance.add_child(test_bot)
	await tree.process_frame
	
	assert_not_null(test_bot.get_parent(), "Animal bot with invalid type should instantiate without crash")
	test_bot.queue_free()
	await tree.process_frame

func test_tree_spacing_respects_minimum_distance() -> void:
	# CÃ¢y sinh ra pháº£i cÃ³ khoáº£ng hở tá»‘i thiá»ƒu Ä‘á»ƒ khu rá»«ng bớt dÃ y
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	var custom_world := world_scene.instantiate() as Node3D
	var fb := custom_world.get_node("Forest") as Node

	fb.set("num_trees", 40)
	fb.set("num_bushes", 0)
	fb.set("num_grass_clumps", 0)
	fb.set("num_flowers", 0)
	fb.set("num_mushrooms", 0)
	fb.set("num_rocks", 0)
	fb.set("num_boulders", 0)

	tree.root.add_child(custom_world)
	await tree.process_frame
	await tree.process_frame

	var tree_nodes: Array[Node3D] = []
	for child in fb.get_children():
		if child is Node3D and child.is_in_group("trees"):
			tree_nodes.append(child as Node3D)

	var min_spacing: float = fb.get("tree_min_spacing")
	for i in range(tree_nodes.size()):
		for j in range(i + 1, tree_nodes.size()):
			var pos_a := Vector2(tree_nodes[i].global_position.x, tree_nodes[i].global_position.z)
			var pos_b := Vector2(tree_nodes[j].global_position.x, tree_nodes[j].global_position.z)
			assert_true(pos_a.distance_to(pos_b) >= min_spacing, "Trees should respect the configured minimum spacing")

	custom_world.queue_free()
	await tree.process_frame

func test_grass_clump_density_multiplier_reduces_cluster_count() -> void:
	# Sá»‘ cá»¥m cá» pháº£i giáº£m theo density multiplier
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	var custom_world := world_scene.instantiate() as Node3D
	var fb := custom_world.get_node("Forest") as Node

	fb.set("num_trees", 0)
	fb.set("num_bushes", 0)
	fb.set("num_flowers", 0)
	fb.set("num_mushrooms", 0)
	fb.set("num_rocks", 0)
	fb.set("num_boulders", 0)
	fb.set("num_grass_clumps", 20)
	fb.set("grass_clump_density_multiplier", 0.90)

	tree.root.add_child(custom_world)
	await tree.process_frame
	await tree.process_frame

	var grass_clump_count := 0
	for child in fb.get_children():
		if child is MeshInstance3D:
			var mesh := (child as MeshInstance3D).mesh
			if mesh != null and "Hilly_Prop_Grass_Clump_" in mesh.resource_path:
				grass_clump_count += 1

	assert_eq(grass_clump_count, 18, "Grass clump density multiplier should reduce spawned clumps by 10 percent")

	custom_world.queue_free()
	await tree.process_frame
