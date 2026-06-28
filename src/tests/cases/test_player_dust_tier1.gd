extends "res://src/tests/base_test_case.gd"

# Tier 1 movement-dust asset integration tests.


func test_player_uses_sprite_asset_instead_of_cpu_particles() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var dust := player.get_node_or_null("MovementDustTrail") as MovementDustTrail
	assert_not_null(dust, "Player must own the movement dust component")
	assert_null(player.get_node_or_null("DustParticles"), "Legacy CPU particle dust must be removed")
	assert_eq(dust.get_pool_sprites().size(), 6, "Dust trail must use a bounded sprite pool")

	var sprite := dust.get_pool_sprites()[0]
	assert_true(sprite.texture.resource_path.ends_with("SmokeFX Lite SpriteSheet 4A-1.png"), "Dust must use the approved 4A-1 asset")
	assert_eq(sprite.hframes, 16, "4A-1 must be split into its 16 animation frames")
	assert_eq(sprite.texture.get_width() / sprite.hframes, 252, "Each 4A-1 frame must preserve its 252 pixel canvas")
	assert_false(sprite.shaded, "Dust color must remain stable across weather lighting")
	assert_eq(sprite.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Dust must not spend shadow budget")


func test_dust_puff_stays_in_world_space_and_releases_pool_slot() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var dust := player.get_node("MovementDustTrail") as MovementDustTrail
	var spawn_position := player.global_position + Vector3(1.0, 0.02, -1.0)
	dust.spawn_at(spawn_position)

	var sprite := dust.get_pool_sprites()[0]
	var expected_position := spawn_position + Vector3.UP * dust.vertical_offset
	assert_eq(dust.get_active_count(), 1, "Spawning one footstep must activate one pooled sprite")
	assert_true(sprite.top_level, "Dust puff must not follow the moving player")
	assert_almost_eq(sprite.global_position.distance_to(expected_position), 0.0, 0.001, "Dust puff must spawn at the footprint")

	dust._process(float(dust.frame_count) / dust.frames_per_second + 0.01)
	assert_eq(dust.get_active_count(), 0, "Finished animation must return its sprite to the pool")


func test_walking_footstep_triggers_dust_asset() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var dust := player.get_node("MovementDustTrail") as MovementDustTrail
	player.anim_state = Player.AnimState.WALK
	player.global_position += Vector3(1.0, 0.0, 0.0)
	player._handle_footprints(0.0)
	assert_eq(dust.get_active_count(), 1, "A walking footprint must trigger one dust animation")


func test_dust_rotates_with_player_facing_direction() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var dust := player.get_node("MovementDustTrail") as MovementDustTrail
	var spawn_position := player.global_position + Vector3(1.0, 0.02, -1.0)

	player.facing_direction = Vector3(1.0, 0.0, 0.0)
	player.facing_right = true
	dust.spawn_at(spawn_position, atan2(player.facing_direction.z, player.facing_direction.x))
	var sprite := dust.get_pool_sprites()[0]
	assert_almost_eq(sprite.global_rotation.y, 0.0, 0.001, "Dust must rotate with player facing direction")

	dust._process(float(dust.frame_count) / dust.frames_per_second + 0.01)

	player.facing_direction = Vector3(0.0, 0.0, 1.0)
	player.facing_right = false
	dust.spawn_at(spawn_position, atan2(player.facing_direction.z, player.facing_direction.x))
	sprite = dust.get_pool_sprites()[1]
	assert_almost_eq(sprite.global_rotation.y, PI / 2.0, 0.001, "Dust rotated 90 degrees when player faces Z direction")
