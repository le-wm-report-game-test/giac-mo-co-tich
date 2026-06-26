# proposed_test_terrain_collision.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử va chạm địa hình bằng cách di chuyển player lên gò đất và kiểm tra độ cao Y
# Technical comments in English, Vietnamese for game logic explanations.

func run() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist in world")
	
	# 1. Kiểm tra va chạm ở mặt đất phẳng (y = 0.0)
	player.global_position = Vector3(0.0, 1.0, 0.0) # Đặt player trên trời một chút
	# Chờ vài frame để Jolt Physics xử lý rơi tự do chạm đất
	for i in range(15):
		await tree.process_frame
		
	# Player phải chạm đất phẳng (độ cao Y gần 0)
	assert_true(player.is_on_floor(), "Player should collide with ground plane")
	assert_true(player.global_position.y < 0.2, "Player height should align with flat ground")

	# 2. Di chuyển player lên đỉnh gò đất (10.0, -10.0, cao 1.5m)
	player.global_position = Vector3(10.0, 3.0, -10.0)
	for i in range(20):
		await tree.process_frame
		
	assert_true(player.is_on_floor(), "Player should collide with hill surface")
	# Đỉnh gò đất cao 1.5m, độ cao player phải nằm trong khoảng phù hợp (1.5m + offset)
	assert_true(player.global_position.y > 1.3 and player.global_position.y < 1.7, "Player should be at hill height")
