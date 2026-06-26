# Giac Mo Co Tich — Refined E2E Testing Design Document

This design document refines the End-to-End (E2E) testing infrastructure for **Giac Mo Co Tich**. It specifies the method-based test runner, the base test case class, and the detailed test suites for Ground & Hill Terrain Collision and Boss Lifecycle.

---

## 1. Architectural Overview & File Structure

To guarantee isolated, automated, and repeatable testing of core features without modifying source code, we propose a headless test runner that runs tests within a clean SceneTree context.

### Directory Layout
The testing files are located within the `res://src/tests/` namespace:
```
giac-mo-co-tich/
└── src/
    └── tests/
        ├── test_runner.gd                 # E2E Test Runner (SceneTree script)
        ├── base_test_case.gd              # Base TestCase class
        └── cases/                         # Test Cases directory
            ├── test_terrain_collision_tier1.gd
            ├── test_terrain_collision_tier2.gd
            ├── test_boss_lifecycle_tier1.gd
            └── test_boss_lifecycle_tier2.gd
```

### Constraints Met
* **File Size Constraint**: Every script is designed to stay well under the **200-line limit** by splitting Tier 1 (happy path) and Tier 2 (boundary/edge cases) into separate files.
* **Method Size Constraint**: Every method is under **50 lines**.
* **Type Safety**: All variables, function parameters, and return types are **statically typed**.
* **Bilingual Documentation**: Vietnamese for game-logic/test explanations, English for technical infrastructure and comments.

---

## 2. The E2E Test Runner (`test_runner.gd`)

The runner is a `SceneTree` script executed headlessly via CLI.
Instead of calling a single `run()` method, this refined runner dynamically discovers all methods starting with `test_` via reflection, then runs `setup()`, the test method itself, and `teardown()` for each method on a **fresh instance** of the test class.

### Async Execution Strategy
In Godot 4 (GDScript 2.0), calling an asynchronous function (coroutine) returns a `Signal` immediately when it yields (i.e. reaches its first `await`). The caller can inspect if the returned value `is Signal` and `await` it to block until completion. Synchronous functions do not return a signal, allowing them to proceed instantly without unnecessary warnings.

### Code Blueprint: `test_runner.gd`
```gdscript
# res://src/tests/test_runner.gd
extends SceneTree

# Headless E2E Test Runner utilizing reflection for method discovery
# Technical comments in English, Vietnamese for runner logic.

const TEST_DIR := "res://src/tests/cases/"

var _tests_run: int = 0
var _tests_failed: int = 0

func _initialize() -> void:
	# Khởi tạo bộ chạy test suite E2E
	print("[E2E Test Runner] Initializing test suite...")
	await _run_suite()

func _run_suite() -> void:
	# Quét thư mục TEST_DIR để tìm tất cả các file kiểm thử .gd
	var dir := DirAccess.open(TEST_DIR)
	if not dir:
		print("[E2E Test Runner] ERROR: Cannot open tests directory: ", TEST_DIR)
		quit(1)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var test_scripts: Array[String] = []
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			test_scripts.append(TEST_DIR + file_name)
		file_name = dir.get_next()
		
	test_scripts.sort()
	
	for script_path in test_scripts:
		await _run_test_file(script_path)
		
	print("==================================================")
	print("[E2E Test Runner] Results: %d run, %d failed" % [_tests_run, _tests_failed])
	print("==================================================")
	
	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func _run_test_file(path: String) -> void:
	# Nạp script kiểm thử từ đường dẫn chỉ định
	var script := load(path) as GDScript
	if not script:
		print("[E2E Test Runner] FAIL: Failed to load script: ", path)
		_tests_failed += 1
		return
		
	var temp_instance = script.new() as RefCounted
	if not temp_instance:
		print("[E2E Test Runner] FAIL: Failed to instantiate: ", path)
		_tests_failed += 1
		return
		
	# Tìm các hàm bắt đầu bằng "test_"
	var test_methods: Array[String] = []
	for method_info in temp_instance.get_method_list():
		var method_name: String = method_info["name"]
		if method_name.begins_with("test_"):
			test_methods.append(method_name)
	test_methods.sort()
	
	print("[E2E Test Runner] Running script: %s (%d tests)" % [path, test_methods.size()])
	
	for method_name in test_methods:
		_tests_run += 1
		print("  -> Running test: %s" % method_name)
		var success := await _run_single_test(script, method_name)
		if not success:
			_tests_failed += 1

func _run_single_test(script: GDScript, method_name: String) -> bool:
	# Chạy một hàm kiểm thử cụ thể trên một thực thể mới (isolation)
	var test_instance = script.new() as RefCounted
	if not test_instance:
		print("    [FAIL] Failed to instantiate for: ", method_name)
		return false
		
	test_instance.set("tree", self)
	
	# 1. Thực thi Setup
	if test_instance.has_method("setup"):
		var setup_res = test_instance.call("setup")
		if setup_res is Signal:
			await setup_res
			
	if test_instance.get("failed") as bool:
		print("    [FAIL] Setup failed: ", test_instance.get("fail_reason"))
		return false
		
	# 2. Thực thi Hàm Kiểm Thử
	var run_res = test_instance.call(method_name)
	if run_res is Signal:
		await run_res
		
	var failed: bool = test_instance.get("failed") as bool
	if failed:
		print("    [FAIL] Reason: ", test_instance.get("fail_reason"))
		
	# 3. Thực thi Teardown để dọn dẹp môi trường
	if test_instance.has_method("teardown"):
		var teardown_res = test_instance.call("teardown")
		if teardown_res is Signal:
			await teardown_res
			
	if failed or (test_instance.get("failed") as bool):
		return false
		
	print("    [PASS]")
	return true
```

---

## 3. The Base Test Case Class (`base_test_case.gd`)

Provides state management, automatic instantiation/destruction of `res://src/world/world.tscn` to keep tests isolated, and standardized static-typed assertions.

### Code Blueprint: `base_test_case.gd`
```gdscript
# res://src/tests/base_test_case.gd
extends RefCounted
class_name BaseTestCase

# Base class for E2E test cases managing scene isolation and assertions
# Technical comments in English, Vietnamese for game logic explanations.

var tree: SceneTree = null
var failed: bool = false
var fail_reason: String = ""
var world_instance: Node3D = null

func setup() -> void:
	# Tự động nạp và tạo mới môi trường thế giới game cho mỗi test case
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	if not world_scene:
		fail("Cannot load world.tscn")
		return
	world_instance = world_scene.instantiate() as Node3D
	tree.root.add_child(world_instance)
	await wait_physics_frames(2)

func teardown() -> void:
	# Dọn dẹp môi trường game sau khi test xong để đảm bảo tính cô lập
	if is_instance_valid(world_instance):
		world_instance.queue_free()
		world_instance = null
	await wait_physics_frames(2)

func fail(reason: String) -> void:
	# Ghi nhận trạng thái thất bại
	failed = true
	fail_reason = reason

func wait_physics_frames(frames: int) -> void:
	# Chờ một số lượng khung hình vật lý để Jolt Physics xử lý va chạm
	for i in range(frames):
		await tree.process_frame

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		fail("Assertion failed: %s (Expected true, got false)" % msg)

func assert_false(condition: bool, msg: String) -> void:
	if condition:
		fail("Assertion failed: %s (Expected false, got true)" % msg)

func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		fail("Assertion failed: %s (Expected %s, got %s)" % [msg, str(expected), str(actual)])

func assert_ne(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		fail("Assertion failed: %s (Expected different, both are %s)" % [msg, str(actual)])

func assert_not_null(val: Variant, msg: String) -> void:
	if val == null:
		fail("Assertion failed: %s (Expected non-null value)" % msg)

func assert_null(val: Variant, msg: String) -> void:
	if val != null:
		fail("Assertion failed: %s (Expected null value, got %s)" % [msg, str(val)])

func assert_almost_eq(actual: float, expected: float, tolerance: float, msg: String) -> void:
	# Rất quan trọng khi kiểm tra tọa độ vật lý có sai số nhỏ
	if absf(actual - expected) > tolerance:
		fail("Assertion failed: %s (Expected %f within %f, got %f)" % [msg, expected, tolerance, actual])
```

---

## 4. Ground & Hill Terrain Collision Test Cases

This suite tests the integration with the **Jolt Physics 3D** engine. It verifies player collision on flat terrain, elevated hill peaks (which are dynamically generated using box shapes per tile), slopes calculated via quadratic falloff, gravity drops, and boundary clamps.

### Tier 1 (Happy Path): `test_terrain_collision_tier1.gd`
* `test_flat_ground_collision`: Tests that the player on flat land (Y=0) lands properly and `is_on_floor()` is true.
* `test_hill_peak_collision`: Spawns the player on a hill peak (Hill 1 center at `(10, -10)` with height `1.5`) and verifies elevation.
* `test_hill_slope_collision`: Tests elevation at `(12, -10)` which is on Hill 1's slope, matching the mathematical quadratic height formula (`1.5 * (1 - 2/5)^2 = 0.54`).
* `test_gravity_fall_on_ground`: Spawns player high in the air (Y=15) and checks that they fall and land safely without going through the map.
* `test_multiple_hills_heights`: Teleports the player to multiple hills (Hill 2 at `(-10, 12)` peak `1.2` and Hill 3 at `(22, 14)` peak `1.0`) to confirm that collision height updates dynamically.

```gdscript
# res://src/tests/cases/test_terrain_collision_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử va chạm địa hình - Tier 1 (Happy Path)
# Technical comments in English, Vietnamese for game logic explanations.

func test_flat_ground_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	player.global_position = Vector3(0.0, 1.0, 0.0)
	await wait_physics_frames(15)
	assert_true(player.is_on_floor(), "Player should be on flat ground floor")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should align with flat ground")

func test_hill_peak_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Hill 1 center (10, -10), radius 5, height 1.5
	player.global_position = Vector3(10.0, 3.0, -10.0)
	await wait_physics_frames(20)
	assert_true(player.is_on_floor(), "Player should be on hill peak floor")
	assert_almost_eq(player.global_position.y, 1.5, 0.1, "Player Y should align with hill 1 peak (1.5m)")

func test_hill_slope_collision() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Slope at x = 12.0 (distance 2.0m from center 10.0, -10.0, radius 5.0)
	# Height: 1.5 * (1.0 - 2.0 / 5.0)^2 = 1.5 * 0.36 = 0.54m
	player.global_position = Vector3(12.0, 3.0, -10.0)
	await wait_physics_frames(20)
	assert_true(player.is_on_floor(), "Player should be on hill slope floor")
	assert_almost_eq(player.global_position.y, 0.54, 0.1, "Player Y should align with slope height")

func test_gravity_fall_on_ground() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	player.global_position = Vector3(-5.0, 15.0, -5.0)
	await wait_physics_frames(2)
	assert_false(player.is_on_floor(), "Player should be in mid-air initially")
	await wait_physics_frames(40)
	assert_true(player.is_on_floor(), "Player should land on flat ground after fall")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should align with flat ground after fall")

func test_multiple_hills_heights() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	
	# Hill 2: center (-10, 12), radius 4, height 1.2
	player.global_position = Vector3(-10.0, 3.0, 12.0)
	await wait_physics_frames(20)
	assert_true(player.is_on_floor(), "Player should be on Hill 2 floor")
	assert_almost_eq(player.global_position.y, 1.2, 0.1, "Player Y should align with Hill 2 peak (1.2m)")
	
	# Hill 3: center (22, 14), radius 4.5, height 1.0
	player.global_position = Vector3(22.0, 3.0, 14.0)
	await wait_physics_frames(20)
	assert_true(player.is_on_floor(), "Player should be on Hill 3 floor")
	assert_almost_eq(player.global_position.y, 1.0, 0.1, "Player Y should align with Hill 3 peak (1.0m)")
```

### Tier 2 (Boundary/Edge Cases): `test_terrain_collision_tier2.gd`
* `test_terrain_outer_boundary_collision`: Verifies that the player is clamped to bounds `[-48.0, 48.0]` on X and Z axis, preventing them from falling off the edge.
* `test_hill_boundary_transition`: Tests positioning immediately inside/outside Hill 1 radius (`5.0`m) to ensure sharp elevation falloffs function correctly.
* `test_under_floor_bullet_prevention`: Spawns the player with an extremely high downward speed (`-150m/s`) to test that Jolt prevents tunneling through the collision plane.
* `test_zero_height_hill_zone`: Confirms player height settles exactly at `Y=0.0` in the central clearing zone (radius `7`m, where no hills can spawn).
* `test_hill_slopes_extreme_teleportation`: Teleports the player sequentially to different hill peaks and flat land in consecutive frames to confirm the physics server updates colliders instantly without sticking.

```gdscript
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
	assert_almost_eq(player.global_position.x, 48.0, 0.01, "Player X should be clamped to 48.0")
	
	# Kiểm tra giới hạn biên âm X
	player.global_position = Vector3(-49.5, 1.0, 0.0)
	await wait_physics_frames(5)
	assert_almost_eq(player.global_position.x, -48.0, 0.01, "Player X should be clamped to -48.0")

func test_hill_boundary_transition() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Điểm cách tâm Hill 1 khoảng 5.1m (ngoài bán kính 5.0m)
	player.global_position = Vector3(15.1, 1.0, -10.0)
	await wait_physics_frames(15)
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should be flat ground just outside hill")

	# Điểm cách tâm Hill 1 khoảng 4.0m (trong bán kính, dự kiến cao ~0.06m)
	player.global_position = Vector3(14.0, 1.0, -10.0)
	await wait_physics_frames(15)
	assert_true(player.global_position.y > 0.02, "Player Y should be elevated slightly inside hill")

func test_under_floor_bullet_prevention() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Gán vận tốc rơi cực kỳ lớn để thử nghiệm đâm xuyên mặt đất (tunneling)
	player.global_position = Vector3(0.0, 5.0, 0.0)
	player.velocity = Vector3(0.0, -150.0, 0.0)
	await wait_physics_frames(5)
	# Jolt Physics phải giữ nhân vật lại trên mặt phẳng (hộp dày 0.2m)
	assert_true(player.is_on_floor(), "Player must be on floor despite high downward speed")
	assert_true(player.global_position.y >= -0.2, "Player should not tunnel below ground shape")

func test_zero_height_hill_zone() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	# Khu vực spawn trung tâm (0.0, 0.0) không chứa gò đất
	player.global_position = Vector3(0.0, 1.0, 0.0)
	await wait_physics_frames(15)
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Y position must be exactly 0 in clearing zone")

func test_hill_slopes_extreme_teleportation() -> void:
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	assert_not_null(player, "Player must exist")
	
	# Teleport liên tiếp qua các vị trí cao độ khác nhau để xem server vật lý đồng bộ kịp không
	player.global_position = Vector3(10.0, 3.0, -10.0) # Đỉnh Hill 1
	await wait_physics_frames(1)
	player.global_position = Vector3(-10.0, 3.0, 12.0) # Đỉnh Hill 2
	await wait_physics_frames(1)
	player.global_position = Vector3(0.0, 1.0, 0.0) # Mặt đất phẳng
	await wait_physics_frames(15)
	
	assert_true(player.is_on_floor(), "Player should be on floor after extreme teleports")
	assert_almost_eq(player.global_position.y, 0.0, 0.05, "Player Y should settle at 0.0")
```

---

## 5. Boss Lifecycle Test Cases

This suite tests the spawning logic, initial statistics, UI integrations, and death lifecycle of the Boss (Chằn Tinh). It checks the exact trigger conditions, properties override, camera magnet override, and damage/death routines.

### Tier 1 (Happy Path): `test_boss_lifecycle_tier1.gd`
* `test_boss_not_spawned_initially`: Verifies no boss is present and the boss HUD is hidden when the world loaded.
* `test_boss_spawn_trigger`: Kills the required number of normal Orcs (`orcs_to_kill_for_boss` set to `3`) and verifies the boss is spawned.
* `test_boss_initial_properties`: Checks properties (name, groups, scale=18, max_health=300, speed=1.5).
* `test_boss_hud_visibility_on_spawn`: Confirms `UI/BossHealthContainer` becomes visible immediately after boss spawns.
* `test_boss_death_sequence`: Damages the boss's health to 0, checks State.DEATH, waits for the queue_free tween, and asserts the boss instance is destroyed and the HUD hidden.

```gdscript
# res://src/tests/cases/test_boss_lifecycle_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh - Tier 1 (Happy Path)
# Technical comments in English, Vietnamese for game logic explanations.

var _world_manager: WorldManager = null

func setup() -> void:
	await super.setup()
	_world_manager = world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(_world_manager, "WorldManager must exist")

func test_boss_not_spawned_initially() -> void:
	assert_false(_world_manager.boss_spawned, "Boss should not be spawned initially")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 0, "No boss in group 'boss' initially")
	var hud_bar = _world_manager.get_node_or_null("UI/BossHealthContainer")
	assert_true(hud_bar == null or not hud_bar.visible, "Boss health UI should be hidden/non-existent initially")

func test_boss_spawn_trigger() -> void:
	_world_manager.orcs_to_kill_for_boss = 3
	var dummy_orc := CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	for i in range(3):
		EventBus.enemy_died.emit(dummy_orc)
		await wait_physics_frames(1)
		
	dummy_orc.queue_free()
	await wait_physics_frames(1)
	
	assert_true(_world_manager.boss_spawned, "Boss should spawn after 3 orcs killed")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "There should be exactly one boss in group 'boss'")

func test_boss_initial_properties() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss instance should be valid")
	assert_eq(boss.name, "BossChằnTinh", "Boss node name should match")
	assert_true(boss.is_in_group("boss") and boss.is_in_group("orc_mobs"), "Boss should be in groups")
	assert_eq(boss.scale, Vector3(18.0, 18.0, 18.0), "Boss scale should be 18.0")
	assert_eq(boss.health_component.max_health, 300.0, "Boss max health should be 300")
	assert_eq(boss.speed, 1.5, "Boss speed should be 1.5")

func test_boss_hud_visibility_on_spawn() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var hud_bar = world_instance.get_node_or_null("WorldManager/UI/BossHealthContainer")
	assert_not_null(hud_bar, "HUD BossHealthContainer should exist")
	assert_true(hud_bar.visible, "HUD BossHealthContainer should be visible")

func test_boss_death_sequence() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	# Gây sát thương làm boss chết
	boss.health_component.take_damage(300.0)
	await wait_physics_frames(10)
	
	# Trạng thái của OrcMob lúc chết là State.DEATH (5)
	assert_eq(boss.get("current_state"), 5, "Boss should be in State.DEATH (5)")
	
	# Chờ tween fade-out hoàn tất và giải phóng node (120 frames ~ 2 giây)
	await wait_physics_frames(120)
	assert_false(is_instance_valid(boss), "Boss should be freed and invalid")
	
	var hud_bar = world_instance.get_node_or_null("WorldManager/UI/BossHealthContainer")
	assert_true(hud_bar == null or not hud_bar.visible, "HUD BossHealthContainer should be hidden on boss death")
```

### Tier 2 (Boundary/Edge Cases): `test_boss_lifecycle_tier2.gd`
* `test_boss_double_spawn_prevention`: Kills additional Orcs *after* the Boss spawns to assert that additional Bosses are not generated.
* `test_boss_spawn_location_clearance`: Asserts that the Boss is spawned at the exact designated center `(-15.0, 0.2, -15.0)` without offset.
* `test_boss_damage_ui_sync`: Verifies that the HUD boss progress bar value updates dynamically on damage. **Note: This addresses the critical observation that the Boss progress bar value is currently static and not connected dynamically to the health components in the original implementation.**
* `test_boss_camera_magnet_activation`: Checks if the camera magnet configuration is correctly activated, setting bounds and overriding zoom.
* `test_boss_health_underflow_overflow`: Tests damage values exceeding total health (e.g. `400` damage) and checks if health clamps to `0.0` and revival is prevented.

```gdscript
# res://src/tests/cases/test_boss_lifecycle_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh - Tier 2 (Boundary/Edge cases)
# Technical comments in English, Vietnamese for game logic explanations.

var _world_manager: WorldManager = null

func setup() -> void:
	await super.setup()
	_world_manager = world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(_world_manager, "WorldManager must exist")

func test_boss_double_spawn_prevention() -> void:
	_world_manager.orcs_to_kill_for_boss = 2
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	
	# Spawn boss bằng cách báo chết 2 lần
	EventBus.enemy_died.emit(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	assert_true(_world_manager.boss_spawned, "Boss should be spawned")
	
	# Giết tiếp orc để đảm bảo boss thứ hai không được tạo ra
	EventBus.enemy_died.emit(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	
	dummy.queue_free()
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "There should never be more than 1 boss spawned")

func test_boss_spawn_location_clearance() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	# Tọa độ chỉ định: (-15.0, 0.2, -15.0)
	assert_almost_eq(boss.global_position.x, -15.0, 0.05, "Boss spawn X should be -15.0")
	assert_almost_eq(boss.global_position.z, -15.0, 0.05, "Boss spawn Z should be -15.0")

func test_boss_damage_ui_sync() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	var hud_bar = world_instance.get_node_or_null("WorldManager/UI/BossHealthContainer/BossHealthBar") as ProgressBar
	assert_not_null(hud_bar, "Boss progress bar must exist")
	
	# Gây sát thương và kiểm tra đồng bộ giao diện (Sửa bug thanh máu)
	boss.health_component.take_damage(60.0)
	await wait_physics_frames(2)
	
	assert_almost_eq(hud_bar.value, 240.0, 0.1, "Boss health bar value should sync with boss health")

func test_boss_camera_magnet_activation() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	# Kiểm tra trạng thái camera magnet có kích hoạt sau khi boss xuất hiện
	var is_magnet_active = _world_manager.get("camera_magnet_active") as bool
	assert_true(is_magnet_active, "Camera magnet should be activated upon boss spawn")

func test_boss_health_underflow_overflow() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	# Gây sát thương lớn hơn lượng máu tối đa
	boss.health_component.take_damage(400.0)
	await wait_physics_frames(2)
	assert_eq(boss.health_component.current_health, 0.0, "Boss health should clamp to 0.0")
	
	# Thử hồi máu khi đã chết (không được phép hồi phục)
	boss.health_component.heal(100.0)
	await wait_physics_frames(2)
	assert_eq(boss.health_component.current_health, 0.0, "Dead boss should not be healable")
```

---

## 6. Execution Command

Once implemented in the source tree, run the entire E2E test suite headlessly using this command:

```powershell
godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd
```
An exit status code of `0` indicates success, and `1` indicates failures in test discovery, loading, setups, assertions, or teardowns.
