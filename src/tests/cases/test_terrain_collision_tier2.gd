# res://src/tests/cases/test_terrain_collision_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử va chạm địa hình - Tier 2 (Boundary/Edge cases)
# Technical comments in English, Vietnamese for game logic explanations.

func test_terrain_outer_boundary_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Kiểm tra giới hạn biên dương X
	player.global_position = Vector3(49.5, 1.0, 0.0)
	await wait_physics_frames(5)
	assert_almost_eq(player.global_position.x, 48.0, 0.1, "Player X should be clamped to 48.0")
	
	# Kiểm tra giới hạn biên âm X
	player.global_position = Vector3(-49.5, 1.0, 0.0)
	await wait_physics_frames(5)
	assert_almost_eq(player.global_position.x, -48.0, 0.1, "Player X should be clamped to -48.0")

func test_hill_boundary_transition() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Điểm cách tâm Hill 1 khoảng 5.1m (ngoài bán kính 5.0m)
	player.global_position = Vector3(15.1, 1.0, -10.0)
	await tree.create_timer(0.5).timeout
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should be flat ground just outside hill")

	# Điểm cách tâm Hill 1 khoảng 4.0m (trong bán kính, dự kiến cao ~0.06m)
	player.global_position = Vector3(14.0, 1.0, -10.0)
	await tree.create_timer(0.5).timeout
	assert_true(player.global_position.y > 0.02, "Player Y should be elevated slightly inside hill")

func test_under_floor_bullet_prevention() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Gán vận tốc rơi cực kỳ lớn để thử nghiệm đâm xuyên mặt đất (tunneling)
	player.global_position = Vector3(0.0, 5.0, 0.0)
	player.velocity = Vector3(0.0, -150.0, 0.0)
	await tree.create_timer(0.3).timeout
	# Jolt Physics phải giữ nhân vật lại trên mặt phẳng (hộp dày 0.2m)
	assert_true(player.is_on_floor(), "Player must be on floor despite high downward speed")
	assert_true(player.global_position.y >= -0.2, "Player should not tunnel below ground shape")

func test_zero_height_hill_zone() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Khu vực spawn trung tâm (0.0, 0.0) không chứa gò đất
	player.global_position = Vector3(0.0, 1.0, 0.0)
	await tree.create_timer(0.5).timeout
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Y position must be exactly 0.0 in clearing zone")

func test_hill_slopes_extreme_teleportation() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	
	# Teleport liên tiếp qua các vị trí cao độ khác nhau để xem server vật lý đồng bộ kịp không
	player.global_position = Vector3(10.0, 3.0, -10.0) # Đỉnh Hill 1
	await wait_physics_frames(1)
	player.global_position = Vector3(-10.0, 3.0, 12.0) # Đỉnh Hill 2
	await wait_physics_frames(1)
	player.global_position = Vector3(0.0, 1.0, 0.0) # Mặt đất phẳng
	await tree.create_timer(0.5).timeout
	
	assert_true(player.is_on_floor(), "Player should be on floor after extreme teleports")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should settle at 0.0")
