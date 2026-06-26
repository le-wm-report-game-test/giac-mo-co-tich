# Handoff Report — E2E Test Suite Performance and Stability Verification

## 1. Observation

A headless E2E test run was executed via the command:
`D:\Godot\godot_console.exe --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`

The console output and errors recorded are as follows:

### A. Overall Test Stats & Parse Errors
- **Execution stats**: Out of 80 tests, 75 were run, 44 passed, and 31 failed. 5 tests were skipped.
- **Parse Error in `test_spawning_tier2.gd`**:
  ```
  SCRIPT ERROR: Parse Error: Cannot infer the type of "pos" variable because the value doesn't have a set type.
     at: GDScript::reload (res://src/tests/cases/test_spawning_tier2.gd:65)
  ERROR: Failed to load script "res://src/tests/cases/test_spawning_tier2.gd" with error "Parse error".
  ```
- **Test Runner Crash on Instantiation**:
  ```
  SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
     at: _run_test_file (res://src/tests/test_runner.gd:56)
  ```

### B. Console Resource Leaks Warnings
- **CanvasItem and ObjectDB leaks**:
  ```
  WARNING: 4 RIDs of type "CanvasItem" were leaked.
     at: _free_rids (servers/rendering/renderer_canvas_cull.cpp:2692)
  WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
     at: cleanup (core/object/object.cpp:2641)
  ```

### C. Mismatched Hardcoded Path in `world_manager.gd`
- **Path Reference Mismatch**:
  - `world_manager.gd` (Line 246) attempts to fetch the UI node via:
    `var ui_layer := get_node_or_null("/root/World/UI")`
  - However, in `world_manager.gd` (Line 427-430), the HUD UI is created and added as a child of the `WorldManager` instance (which is `/root/World/WorldManager`):
    ```gdscript
    func _create_hud() -> void:
        var ui := CanvasLayer.new()
        ui.name = "UI"
        add_child(ui) # Path becomes "/root/World/WorldManager/UI"
    ```

### D. Tree Position Warnings
- **Not-in-tree operations**:
  ```
  ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
     at: get_global_transform (scene/3d/node_3d.cpp:642)
     at: setup_tree_test (res://src/tests/cases/test_camera_tier1.gd:15)
  ```
- **Tree Setup Logic**:
  ```gdscript
  test_tree = Node3D.new()
  test_tree.name = "Pine_TestTree"
  test_tree.global_position = Vector3(10.0, 0.0, 10.0) # line 15 - Node is not in the tree yet
  world_instance.add_child(test_tree) # line 22
  ```

### E. Mismatched Gravity and Waiting Time in Physics Tests
- **Terrain Collision assertions**:
  - `test_terrain_collision_tier1.gd` (Line 10-11):
    ```gdscript
    player.global_position = Vector3(0.0, 1.0, 0.0)
    await wait_physics_frames(15)
    ```
    Failed with: `Assertion failed: Player Y should align with flat ground (Expected 0.000000 within 0.050000, got 0.823056)`
  - `test_terrain_collision_tier1.gd` (Line 37-40):
    ```gdscript
    player.global_position = Vector3(-5.0, 15.0, -5.0)
    await wait_physics_frames(40)
    ```
    Failed with: `Assertion failed: Player Y should align with flat ground after fall (Expected 0.000000 within 0.050000, got 13.965556)`

### F. Shared Environment Resource Modification
- **World Environment modification**:
  - `world_manager.gd` (Line 312-314):
    ```gdscript
    var world_env := get_node_or_null("/root/World/WorldEnvironment") as WorldEnvironment
    if world_env and world_env.environment:
        var env := world_env.environment # Reference to a shared resource
    ```

---

## 2. Logic Chain

- **Step 1 (Parse & Load Failures)**: In `test_spawning_tier2.gd:65`, the loop variable `child` is inferred as a generic `Node` type returned by `get_children()`. Accessing `child.global_position` without typecasting fails compilation because `Node` does not have a statically-defined `global_position` property. Since the parser fails, `load()` returns an errored `GDScript` resource that throws a runtime script error when `script.new()` is called, crashing the test runner for that script.
- **Step 2 (CanvasItem RID Leak)**: Four E2E tests (`test_lightning_damage_radius`, `test_lightning_just_inside_radius`, `test_lightning_just_outside_radius`, and `scenario_survival_stormy_forest`) trigger lightning strikes. In `world_manager.gd:242`, a `ColorRect` named `flash` is dynamically created (`ColorRect.new()`). It attempts to resolve `ui_layer` using `/root/World/UI`. Because the UI canvas layer path is actually `/root/World/WorldManager/UI`, the lookup returns `null`, the `flash` node is never added to the tree, and the tween/free callback is never created. The unparented `ColorRect` is orphaned, leaking exactly 4 `CanvasItem` RIDs at exit.
- **Step 3 (Physics Test Failures)**: In Godot, the physics process runs at a fixed tick rate (typically 60 ticks/second). Under a standard gravity of $9.8\text{ m/s}^2$, the distance fallen in $t$ seconds from rest is $d = 0.5 \cdot g \cdot t^2$. 
  - For `test_flat_ground_collision`, a 15-frame wait represents $0.25\text{ s}$, corresponding to a maximum fall distance of $0.3\text{ m}$. Spawning at $Y=1.0\text{m}$ means the player can only reach $\approx 0.7\text{m}$, making it mathematically impossible to reach the ground ($Y=0.0\text{m}$) within the allotted frames (observed: $0.823\text{m}$).
  - For `test_gravity_fall_on_ground`, a 40-frame wait ($0.66\text{s}$) allows a fall of only $\approx 2.17\text{m}$. Spawning at $Y=15.0\text{m}$ means the player cannot reach the floor within 40 frames (observed: $13.96\text{m}$).
- **Step 4 (Incorrect Not-in-tree Operations)**: Testing nodes (`test_tree` in camera and fade tests) have their `global_position` set before being added as children using `add_child()`. Godot does not initialize spatial transforms outside the SceneTree, producing the `!is_inside_tree()` console errors.
- **Step 5 (Shared Resource Pollution)**: `WorldManager` directly modifies the properties of the `Environment` resource of `WorldEnvironment`. In Godot, resources are shared and cached globally by default. By modifying the `Environment` directly without copying it (`.duplicate()`), the changes pollute the cached resource and persist across all subsequent test cases, violating clean isolation.
- **Step 6 (Tree Fading Non-functionality)**: `_set_tree_alpha` operates on `material_override` or `surface_override_materials`. However, pine tree models spawned by `ForestBuilder` are loaded from glTF files and have internal surfaces and materials inside the mesh resources, leaving overrides empty. Consequently, actual tree models do not fade, which is why the tier 3 integration test `test_player_movement_tree_fade` (which uses a real tree) returns `-1.0` (failure), while Tier 1/2 tests (which use dummy test meshes with overrides manually configured) pass.
- **Step 7 (Camera Magnet Conflict)**: Both `GameCamera._process(delta)` and `WorldManager._update_camera_magnet(delta)` directly modify the `global_position` of the camera, fighting for control on every frame. This creates conflicting camera assignments and causes jitter/failure.
- **Step 8 (Early-Exit Defect in Assertion Helper)**: In `base_test_case.gd`, the `fail()` function sets `failed = true` but does not exit the current test case execution. This allows subsequent assertions in the same test method to continue running and overwrite `fail_reason`, hiding the root cause of the initial failure.

---

## 3. Caveats

- Operating in `CODE_ONLY` network mode, meaning all tests were executed locally.
- Did not modify the source tree or write fix patches, strictly conforming to the "Review-only" challenger mandate.
- Performance logs rely on standard Godot headless output console prints.

---

## 4. Conclusion

The E2E test suite has significant stability, cleanup, and logic issues:
1. **Dynamic memory leaks** occur during lightning strikes due to an invalid hardcoded path lookup to `/root/World/UI` instead of the correct path `/root/World/WorldManager/UI`.
2. **Physics tests are mathematically flawed**, asserting landing positions with wait-times that are physically impossible under the engine's gravity constraints.
3. **Environment pollution** occurs between tests because shared resources are not duplicated.
4. **Tree fade and camera magnet systems have structural bugs** inside the game implementation that are correctly surfaced by the integration test failures.
5. **The assertion framework hides failures** due to the lack of early-exits on failed assertions.

---

## 5. Verification Method

To reproduce these findings and verify the E2E test suite behavior:
1. **Run the headless test suite**:
   `D:\Godot\godot_console.exe --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`
2. **Observe leaks and failures** in the console output.
3. **Inspect the following files for pathing, syntax, and logic errors**:
   - Mismatched UI path in `src/world/world_manager.gd` (Line 246).
   - Incomplete type inference in `src/tests/cases/test_spawning_tier2.gd` (Line 65).
   - Physic frames timing in `src/tests/cases/test_terrain_collision_tier1.gd`.
   - Shared resource modifications in `src/world/world_manager.gd` (Line 312-314).
