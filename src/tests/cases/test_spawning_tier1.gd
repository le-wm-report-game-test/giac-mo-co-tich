# res://src/tests/cases/test_spawning_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 E2E tests for Spawning/Flora scattering.
# Technical comments in English, Vietnamese for game logic explanations.

func test_deterministic_spawning_generation() -> void:
	# Kiểm tra sinh quái ngẫu nhiên đồng nhất theo hạt giống (seed)
	var world_scene: PackedScene = load("res://src/world/world.tscn") as PackedScene
	var w1 := world_scene.instantiate() as Node3D
	var w2 := world_scene.instantiate() as Node3D
	tree.root.add_child(w1)
	tree.root.add_child(w2)
	
	var fb1 := w1.get_node("Forest") as Node
	var fb2 := w2.get_node("Forest") as Node
	
	var orcs1: Array[Vector3] = []
	var orcs2: Array[Vector3] = []
	for child in fb1.get_children():
		if child.name.begins_with("OrcMob_"):
			orcs1.append(child.global_position)
	for child in fb2.get_children():
		if child.name.begins_with("OrcMob_"):
			orcs2.append(child.global_position)
			
	assert_eq(orcs1.size(), orcs2.size(), "Orc sizes must match deterministic seed")
	for i in range(orcs1.size()):
		var pos1 := Vector2(orcs1[i].x, orcs1[i].z)
		var pos2 := Vector2(orcs2[i].x, orcs2[i].z)
		assert_eq(pos1, pos2, "Orc positions must be identical for same seed")
		
	w1.queue_free()
	w2.queue_free()
	await tree.process_frame

func test_orc_spawning_exclusion_zone() -> void:
	# Đảm bảo không có Orc nào sinh ra quá gần điểm hồi sinh của người chơi (< 8m)
	var fb := world_instance.get_node("Forest") as Node
	var spawn_center := Vector2(0.0, 0.0)
	
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			var pos_2d := Vector2(child.global_position.x, child.global_position.z)
			var dist := pos_2d.distance_to(spawn_center)
			assert_true(dist >= 8.0, "Orc should not spawn within 8m of player spawn center")

func test_animal_spawning_exclusion_zone() -> void:
	# Đảm bảo không có thú vật sinh ra quá gần điểm hồi sinh (< 6m)
	var fb := world_instance.get_node("Forest") as Node
	var spawn_center := Vector2(0.0, 0.0)
	
	for child in fb.get_children():
		var is_animal := child.name.begins_with("CatBot_") or child.name.begins_with("RabbitBot_") or child.name.begins_with("ParrotBot_")
		if is_animal:
			var pos_2d := Vector2(child.global_position.x, child.global_position.z)
			var dist := pos_2d.distance_to(spawn_center)
			assert_true(dist >= 6.0, "Animal should not spawn within 6m of player spawn center")

func test_spawning_counts() -> void:
	# Xác minh số lượng thực thể sinh ra đúng thiết kế (14 orcs, 12 animals)
	var fb := world_instance.get_node("Forest") as Node
	var orcs_count := 0
	var animals_count := 0
	
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			orcs_count += 1
		elif child.name.begins_with("CatBot_") or child.name.begins_with("RabbitBot_") or child.name.begins_with("ParrotBot_"):
			animals_count += 1
			
	assert_eq(orcs_count, 14, "There should be exactly 14 orcs spawned")
	assert_eq(animals_count, 12, "There should be exactly 12 animals spawned")

func test_no_mob_spawn_on_hills() -> void:
	# Đảm bảo quái vật và động vật không spawn trên gò đất
	var fb := world_instance.get_node("Forest") as Node
	var hill_zones: Array[Dictionary] = [
		{"center": Vector2(10.0, -10.0), "radius": 5.0},
		{"center": Vector2(-10.0, 12.0), "radius": 4.0},
		{"center": Vector2(22.0, 14.0), "radius": 4.5},
		{"center": Vector2(-20.0, 5.0), "radius": 3.5},
	]
	
	for child in fb.get_children():
		var is_mob := child.name.begins_with("OrcMob_") or child.name.begins_with("CatBot_") or child.name.begins_with("RabbitBot_") or child.name.begins_with("ParrotBot_")
		if is_mob:
			var pos_2d := Vector2(child.global_position.x, child.global_position.z)
			for hill in hill_zones:
				var center: Vector2 = hill["center"]
				var radius: float = hill["radius"]
				assert_true(pos_2d.distance_to(center) > radius, "Mob should not spawn inside hill zone")
