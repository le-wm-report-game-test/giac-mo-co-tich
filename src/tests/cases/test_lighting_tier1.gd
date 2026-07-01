extends "res://src/tests/base_test_case.gd"

# Tier 1 cinematic-lighting integration tests.

func test_clear_profile_is_the_cinematic_baseline() -> void:
	var director := world_instance.get_node_or_null("LightingDirector") as LightingDirector
	var sun := world_instance.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world_environment := world_instance.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(director, "World must own a LightingDirector")
	assert_not_null(sun, "World must own the sunlight")
	assert_not_null(world_environment, "World must own a WorldEnvironment")
	assert_eq(director.get_quality_preset(), "Cinematic", "Cinematic must be the director default")
	assert_almost_eq(sun.light_energy, 1.65, 0.01, "Clear profile must use a strong but controlled warm key light")
	assert_almost_eq(world_environment.environment.ambient_light_energy, 0.42, 0.01, "Cool ambient light must preserve readable shadows without black crush")
	assert_true(world_environment.environment.volumetric_fog_enabled, "Cinematic baseline must enable volumetric fog")
	assert_true(world_environment.environment.fog_enabled, "Orthographic view must use light depth fog for layer separation")

func test_weather_profiles_change_the_complete_light_stack() -> void:
	var director := world_instance.get_node("LightingDirector") as LightingDirector
	var sun := world_instance.get_node("DirectionalLight3D") as DirectionalLight3D
	var environment := (world_instance.get_node("WorldEnvironment") as WorldEnvironment).environment
	director.set_weather(&"rain", false)
	assert_almost_eq(sun.light_energy, 0.48, 0.01, "Rain must reduce direct sunlight")
	assert_almost_eq(environment.volumetric_fog_density, 0.014, 0.001, "Rain must increase atmospheric depth")
	director.set_weather(&"storm", false)
	assert_almost_eq(sun.light_energy, 0.24, 0.01, "Storm must be darker than rain")
	assert_true(environment.adjustment_saturation < 0.7, "Storm must use a restrained color grade")

func test_performance_quality_reduces_expensive_features() -> void:
	var director := world_instance.get_node("LightingDirector") as LightingDirector
	var sun := world_instance.get_node("DirectionalLight3D") as DirectionalLight3D
	var environment := (world_instance.get_node("WorldEnvironment") as WorldEnvironment).environment
	director.set_quality_preset("Performance")
	assert_eq(director.get_quality_preset(), "Performance", "Performance preset must be selectable")
	assert_false(environment.ssil_enabled, "Performance must disable SSIL")
	assert_almost_eq(sun.directional_shadow_max_distance, 46.0, 0.01, "Performance must reduce shadow distance")
	director.set_quality_preset("Cinematic")
	assert_true(environment.ssil_enabled, "Cinematic must restore SSIL")
	assert_almost_eq(sun.directional_shadow_max_distance, 68.0, 0.01, "Cinematic must restore the wider shadow range")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Cinematic must stay within the two-cascade GPU budget")

func test_actor_readability_uses_isolated_render_layers() -> void:
	var director := world_instance.get_node("LightingDirector") as LightingDirector
	var actor_light := director.get_node("ActorReadabilityLight") as DirectionalLight3D
	var player_light := director.get_node("PlayerAccentLight") as DirectionalLight3D
	var player := tree.get_first_node_in_group("player") as Player
	var enemy := tree.get_first_node_in_group("orc_mobs") as OrcMob
	assert_not_null(player, "Player must exist")
	assert_not_null(enemy, "Enemy must exist")
	assert_eq(actor_light.light_cull_mask, 2, "Actor fill must only target the combat layer")
	assert_eq(player_light.light_cull_mask, 4, "Player accent must only target the player layer")
	assert_true(player_light.light_energy < actor_light.light_energy, "Player accent must remain subtler than the shared actor fill")
	assert_true((player.sprite.layers & 2) != 0 and (player.sprite.layers & 4) != 0, "Player must receive both readability tiers")
	assert_true((enemy.sprite.layers & 2) != 0 and (enemy.sprite.layers & 4) == 0, "Enemy must receive base fill without player accent")

func test_navigation_accents_are_bounded_and_shadowless() -> void:
	var director := world_instance.get_node("LightingDirector") as LightingDirector
	var accent_count := 0
	for child in director.get_children():
		if child is SpotLight3D and child.name.begins_with("NavigationAccent"):
			accent_count += 1
			assert_false((child as SpotLight3D).shadow_enabled, "Navigation accents must not render shadows")
	assert_eq(accent_count, 3, "Lighting budget allows exactly three navigation accents")

func test_player_readability_target_is_inside_the_gameplay_view() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var camera_rig := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Player must exist for readability validation")
	assert_not_null(camera_rig, "Gameplay camera must exist for readability validation")
	var screen_position := camera_rig.camera.unproject_position(player.global_position + Vector3.UP)
	var viewport_size := camera_rig.get_viewport().get_visible_rect().size
	assert_true(screen_position.x >= 0.0 and screen_position.x <= viewport_size.x, "Player must project inside the horizontal viewport")
	assert_true(screen_position.y >= 0.0 and screen_position.y <= viewport_size.y, "Player must project inside the vertical viewport")

func test_large_tree_between_camera_and_player_uses_camera_space_fade() -> void:
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	var camera_rig := tree.get_first_node_in_group("camera") as GameCamera
	var occluder := Node3D.new()
	occluder.name = "Pine_CameraSpaceOccluder"
	world_instance.add_child(occluder)
	var player_focus := player.global_position + Vector3.UP
	var focus_local := camera_rig.camera.to_local(player_focus)
	focus_local.z += minf(maxf(-focus_local.z * 0.35, 0.05), 0.2)
	occluder.global_position = camera_rig.camera.to_global(focus_local)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	mesh_instance.material_override = material
	occluder.add_child(mesh_instance)
	world_manager._collect_trees()
	world_manager.tree_list = [occluder]
	world_manager._set_tree_alpha(occluder, 1.0)
	for _frame in range(12):
		world_manager._update_tree_fade(1.0 / 60.0)
	assert_almost_eq(material.albedo_color.a, 0.25, 0.01, "A rendered canopy on the camera ray must reveal the player")
