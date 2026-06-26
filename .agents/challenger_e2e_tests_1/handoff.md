# Handoff Report — E2E Test Suite Verification

## 1. Observation
Headless E2E test runs were executed 3 times using the command:
`cmd /c "godot_console --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd"`

Across the three runs, the following results and errors were directly observed:
- **Run 1**: 75 run, 31 failed. Exit code 1.
- **Run 2**: 75 run, 31 failed. Exit code 1.
- **Run 3**: 75 run, 30 failed. Exit code 1.

### Verbatim Errors & GDScript Stack Traces:
1. **Dynamic property assignment crash on Boss Spawning**:
   ```
   BOSS SPAWNED! Chằn Tinh xuất hiện!
   SCRIPT ERROR: Invalid assignment of property or key 'attack_damage' with value of type 'float' on a base object of type 'CharacterBody3D (OrcMob)'.
      at: WorldManager._spawn_boss (res://src/world/world_manager.gd:118)
   ```
2. **Deterministic Spawning coordinates Y mismatch**:
   ```
   [FAIL] Reason: Assertion failed: Orc positions must be identical for same seed (Expected (8.046478, 7.721555, 44.85435), got (8.046478, -0.03578, 44.85435))
   ```
3. **Terrain gravity collision Y mismatch**:
   ```
   [FAIL] Reason: Assertion failed: Player Y should align with flat ground (Expected 0.000000 within 0.050000, got 0.823056)
   [FAIL] Reason: Assertion failed: Player Y should align with flat ground after fall (Expected 0.000000 within 0.050000, got 13.965556)
   ```
4. **Weather cycle ticking mismatch**:
   ```
   [FAIL] Reason: Assertion failed: Initial weather timer must be 300.0 seconds (Expected 300.0, got 299.845681555556)
   ```
5. **Float precision mismatch on tree transparency**:
   ```
   [FAIL] Reason: Assertion failed: Should fade at 2.49m diff_x (just below 2.5m threshold) (Expected 0.3, got 0.30000001192093)
   ```
6. **Compiler Parse Error in `test_spawning_tier2.gd`**:
   ```
   SCRIPT ERROR: Parse Error: Cannot infer the type of "pos" variable because the value doesn't have a set type.
      at: GDScript::reload (res://src/tests/cases/test_spawning_tier2.gd:65)
   ERROR: Failed to load script "res://src/tests/cases/test_spawning_tier2.gd" with error "Parse error".
   ```
7. **Resource Leaks at exit**:
   ```
   WARNING: 4 RIDs of type "CanvasItem" were leaked.
      at: _free_rids (servers/rendering/renderer_canvas_cull.cpp:2692)
   WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
      at: cleanup (core/object/object.cpp:2641)
   ```

---

## 2. Logic Chain
1. **Dynamic property assignment crash**:
   - `world_manager.gd` (line 118) assigns `boss.attack_damage = 25.0`.
   - `boss` is an instance of `OrcMob` (`orc_mob.gd`), which does not declare `attack_damage`.
   - This throws a runtime error, halting the rest of `_spawn_boss()`, meaning `_show_boss_health_bar()`, `_activate_camera_magnet()`, and `EventBus.boss_spawned.emit()` never execute. This directly breaks several camera and HUD E2E tests.
2. **Boss scale override lifecycle bug**:
   - `world_manager.gd` (line 100) sets `boss.scale = Vector3(18.0, 18.0, 18.0)` and calls `add_child(boss)`.
   - Entering the tree triggers `OrcMob._ready()` which contains `scale = Vector3(10.0, 10.0, 10.0)` (line 34).
   - This overrides the boss scale back to 10.0, causing `test_boss_initial_properties` to fail.
3. **GLTF tree material transparency override failure**:
   - `world_manager.gd`'s `_set_tree_alpha` attempts to modify tree opacity via `get_surface_override_material(i)`.
   - Actual trees spawned by `forest_builder.gd` are GLTF scene instances (`Pine_1.gltf`, etc.) and do not have surface override materials set. They use embedded materials.
   - Therefore, `_set_tree_alpha` does nothing on actual trees, returning an alpha of `-1.0` in `test_player_movement_tree_fade`.
4. **Flakiness in weather timer and boss location clearance**:
   - Timers tick down during the asynchronous test setup phase (`wait_physics_frames(2)`). Asserting exact values (e.g. `300.0` or `60.0`) fails because the timer is already at `299.84` or `59.99`.
   - `test_boss_spawn_location_clearance` fails in Runs 1 and 2 because `wait_physics_frames(2)` is yielded, allowing physics processing and wander movement to run for 2 frames, shifting the Boss position from `-15.0` to `-15.125`. Under different CPU schedules (Run 3), it happened to settle within tolerance, showing high flakiness.
5. **Flakiness in gravity collision frame budget**:
   - Gravity in `player.gd` is `-9.8` m/s². The tests drop the player from `1.0m`, `3.0m`, and `15.0m`, and wait for `15`, `20`, and `40` frames respectively.
   - Mathematically, a free-falling body takes $\approx 27$ frames to drop 1.0m, $\approx 47$ frames to drop 3.0m, and $\approx 105$ frames to drop 15.0m.
   - Because the frame budget is too low, the player is asserted to be on the floor while still in mid-air, causing all terrain collision tests to fail.
6. **Wrong function call in interaction/workload tests**:
   - `test_interactions_tier3.gd` (line 79) and `test_workloads_tier4.gd` (line 50) call `player._on_damaged(20.0, null)` directly.
   - This is the event handler connected to `health_component.damaged` signal, not the damage function itself. It sets animations and UI popups but does NOT reduce the player's health. Thus, player health remains at `100.0`, failing assertions.
7. **Camera target fight**:
   - `GameCamera._process()` lerps the camera towards the player target with `follow_speed = 8.0`.
   - `WorldManager._update_camera_magnet()` lerps the same camera towards `camera_magnet_target` with a factor of `3.0 * delta`.
   - Both run in the same frame without coordination, causing them to fight. Since the player follow speed is stronger, the camera remains near the player, failing `test_magnet_override_player_movement`.
8. **Compiler Parse Error**:
   - `test_spawning_tier2.gd` contains `var pos := child.global_position`. Because `child` is retrieved from `get_children()` (which returns `Array[Node]`), the type cannot be inferred, resulting in a parser compilation error.

---

## 3. Caveats
- Jolt physics body allocations and leaks were not directly visible in the standard headless console output, but 4 RIDs of type "CanvasItem" and various ObjectDB instances were leaked at exit.
- Viewport size defaults to (0, 0) under headless mode, affecting aspect-ratio calculations in `GameCamera._process()`.

---

## 4. Conclusion
The E2E test suite has a high level of coverage but is currently failing (30-31 failed out of 75 run) due to:
1. **True implementation bugs**: Boss scale reset in `_ready()`, invalid property assignment `attack_damage` in `world_manager.gd`, and inability to modify GLTF tree material transparency at runtime.
2. **Test design/assertion bugs**: Exact float checks (`== 0.3`), exact weather timer checks (`== 300.0`), insufficient frame budgets for gravity fall, calling callbacks instead of core methods (`_on_damaged` vs `take_damage`), and missing type casting.
3. **Controller conflicts**: Fighting update methods in `GameCamera` and `WorldManager`.

---

## 5. Verification Method
1. Execute the headless test suite:
   `godot_console --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`
2. Inspect the test logs located in the task folder.
3. Invalidation conditions:
   - Exit code `0` on the unmodified codebase.
   - Changing implementation code (as Challenger is constrained to Review-only).

---
---

# Adversarial Review / Challenge Report

## Challenge Summary

**Overall risk assessment**: HIGH

The E2E test infrastructure has serious bugs, flakiness, and compiler issues that prevent it from serving as a reliable CI/CD gate. Additionally, three critical features (Boss Spawning scale, Boss damage application, and Tree fading opacity on GLTF meshes) are functionally broken or crash at runtime.

## Challenges

### [High] Challenge 1: Invalid Property Assignment on OrcMob
- **Assumption challenged**: Assumed `boss` (OrcMob) has an `attack_damage` field.
- **Attack scenario**: Attempting to spawn the boss causes a runtime crash at `world_manager.gd:118` when assigning `boss.attack_damage = 25.0`.
- **Blast radius**: Halts execution of `_spawn_boss()` mid-way, preventing UI creation, camera magnet activation, and boss spawned event emission.
- **Mitigation**: Add `attack_damage` to `OrcMob` class or set it on the boss's hitbox component: `boss.hitbox_component.damage = 25.0`.

### [High] Challenge 2: Lifecycle Ordering Bug Overrides Boss Scale
- **Assumption challenged**: Setting a node's scale before `add_child` keeps the scale.
- **Attack scenario**: `WorldManager` spawns the boss, sets scale to `18.0`, and adds it to the tree. Entering the tree triggers `OrcMob._ready()`, which hard-overrides the scale back to `10.0`.
- **Blast radius**: The boss spawns at a size of `10.0` instead of the designed `18.0`.
- **Mitigation**: Set the boss scale *after* calling `add_child()`, or check if the mob is a boss in `_ready()` before applying default scales.

### [High] Challenge 3: GLTF Tree Materials Cannot Fade
- **Assumption challenged**: MeshInstance3D materials can be modified directly via override/surface lists.
- **Attack scenario**: `_set_tree_alpha` iterates through surface overrides and material overrides. But GLTF tree instances have no overrides set.
- **Blast radius**: Tree transparency/fade does not work at all for spawned trees in-game.
- **Mitigation**: Duplicate the mesh's internal material using `mesh.surface_get_material(i).duplicate()` and apply it as a surface override.

### [Medium] Challenge 4: Insufficient Gravity Frame Budget
- **Assumption challenged**: Player lands on flat ground from a 15-meter height in 40 frames (0.66s).
- **Attack scenario**: Gravity acceleration (9.8m/s²) dictates that it takes $\approx 1.75$ seconds (105 frames) to fall 15 meters. The test checks floor collision at 40 frames and fails.
- **Blast radius**: All physical collision tests fail consistently.
- **Mitigation**: Increase physics frame wait times to match physical gravity calculations (e.g. wait 110 frames for a 15m drop).

### [Medium] Challenge 5: Calling Event Handlers Directly
- **Assumption challenged**: Calling `player._on_damaged()` applies damage.
- **Attack scenario**: Tests call `_on_damaged()` which only plays animations/effects. It does not touch `HealthComponent`.
- **Blast radius**: Player health remains 100%, causing survival and damage HUD assertions to fail.
- **Mitigation**: Call `player.health_component.take_damage(20)` instead of `_on_damaged`.

---

## Stress Test Results

- **Run E2E Runner 1** → Expected: Pass → Actual: Fail (31 failed tests, exit code 1) → **FAIL**
- **Run E2E Runner 2** → Expected: Pass → Actual: Fail (31 failed tests, exit code 1) → **FAIL**
- **Run E2E Runner 3** → Expected: Pass → Actual: Fail (30 failed tests, exit code 1) → **FAIL** (Showing flakiness on boss location clearance)

## Unchallenged Areas

- **Terrain3D Addon Collision**: The interactions with Terrain3D heightmaps were not challenged due to the headless console mode ignoring high-fidelity heightmap loading.
