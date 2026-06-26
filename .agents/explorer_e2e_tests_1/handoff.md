# Giac Mo Co Tich E2E Testing Infrastructure Design Report

## 1. Observation
After searching the codebase, the following file layout and feature implementations were directly observed:
* **Main Scene & Loaders**:
  * `res://src/world/world.tscn`: Root scene linking `world.gd` (script) and `forest_builder.gd` (as the `Forest` child node).
  * `res://src/world/world.gd`: Instantiates `Player` (from `res://src/player/player.tscn`), `GameCamera` (from `res://src/camera/game_camera.tscn`), `WorldManager`, and `AudioManager` at runtime, then triggers the EventBus signal `player_spawned`.
  * `res://src/common/event_bus.gd`: Autoloaded global EventBus singleton routing key signals (`player_spawned`, `player_died`, `player_health_changed`, `player_took_damage`, `enemy_damaged`, `enemy_died`, `boss_spawned`, `orc_killed_count`, `weather_changed`).
* **Ground & Hill Terrain Collision**:
  * Implemented in `res://src/world/forest_builder.gd` inside `_build_ground_collision()` (lines 209-241). It instantiates a flat static body (`GroundBody`) and loops through all XZ coordinate blocks, creating a separate `CollisionShape3D` (BoxShape3D) for each hill tile exceeding `0.05` height (lines 232-240).
* **Boss Lifecycle**:
  * Managed in `res://src/world/world_manager.gd` (lines 68-118). Triggers `_spawn_boss()` once normal orcs killed reach `orcs_to_kill_for_boss` (default: 5).
  * Spawns character at `(-15.0, 0.2, -15.0)`, scales it to 18.0x, attaches `res://src/world/orc_mob.gd` via `set_script()`, sets health stats to `300.0`, shows HUD via `_show_boss_health_bar()`, and emits `EventBus.boss_spawned`.
  * *Critical Observation*: HUD progress bar `UI/BossHealthContainer/BossHealthBar` is created in `_create_hud()` (line 498) but its value is never updated dynamically when damage occurs (there are no references updating its progress value in `world_manager.gd`).
* **Weather Cycles**:
  * Managed in `res://src/world/world_manager.gd` (lines 123-275). Cycles between `"clear"`, `"rain"`, and `"storm"` states. Storm is triggered when `rain_cycle_count >= 3`.
  * In storm state, `_strike_lightning()` (lines 223-260) triggers screen flash, instantiates procedural cylinder lightning bolts, checks if player is within 5.0m to deal 20.0 damage, and plays thunder SFX.
* **Tree Fade System**:
  * Managed in `res://src/world/world_manager.gd` (lines 589-645). `_collect_trees()` gathers tree references, and `_update_tree_fade()` runs every frame, shifting tree transparency to 0.3 alpha when the player is within 4.0m and positioned behind the tree trunk.
* **Camera Clipping & Magnet**:
  * Managed in `res://src/world/world_manager.gd`. Camera clipping (lines 650-667) hides trees when camera is within 1.5m of their origin. Camera magnet (lines 370-410) overrides camera position and orthogonal zoom size during the boss spawn sequence.
* **HUD UI Updates**:
  * Managed in `res://src/world/world_manager.gd` (lines 415-584). Spawns the HUD overlay canvas layer, updating the health progress bar on player health changes, the orc counter on enemy deaths, and spawning floating damage numbers (white for normal, yellow for critical/crit) on damage signals.
* **Spawning/Flora scattering**:
  * Managed in `res://src/world/forest_builder.gd`. Prop placements are generated procedurally based on deterministic `random_seed = 2025`. Spawns 8 orcs and 12 animals (Cat, Rabbit, Parrot). Excludes spawning them within 8.0m and 6.0m of the player spawn point respectively, and excludes hill zones.

## 2. Logic Chain
1. *Observation 1 & 2*: There are no existing test scripts or frameworks implemented in the project. Therefore, we must introduce a design from scratch.
2. *Observation 1*: Godot 4.6 supports headless execution via the `--headless` CLI flag and execution of SceneTree scripts via the `-s` flag. Thus, a test runner extending `SceneTree` is the most direct and lightweight solution.
3. *Observation 2*: E2E tests require loading the actual game world to verify interactions. Preloading and instantiating `res://src/world/world.tscn` directly in each test case's `setup()` method allows test cases to run in isolation.
4. *Observation 2*: Physics, movement, and animations require time to execute. Writing test cases as asynchronous classes where actions can be `await`ed over several frames ensures the Jolt Physics engine can settle before making assertions.
5. *Observation 1*: Designing a base class `BaseTestCase` that manages setup (instantiating `world.tscn`), teardown (deleting the instance), and provides assertion helpers ensures tests remain modular, clean, and comply with the project's strict <200 line constraint.

## 3. Caveats
* **Physics Flakiness**: Physics-based test assertions (e.g. terrain collision) depend on character velocity and physics frames settling. A hard-coded frame count wait (e.g. 15 frames) is assumed to be sufficient but may require adjustment on varying CPU loads.
* **Autoload Pollution**: The global `EventBus` is shared. If tests emit global signals and do not reset listeners, it could cause side-effects. However, resetting the scene tree structure per test case mitigates this.
* **Refactoring Dependency**: Future milestones plan to split `WorldManager` and `ForestBuilder` into child components. Since the E2E tests access these managers directly, the node paths inside the test cases will need adjustment once the refactoring occurs.

## 4. Conclusion
We recommend implementing a modular, headless E2E testing infrastructure consisting of:
1. **Headless Test Runner (`res://src/tests/test_runner.gd`)**: A `SceneTree` runner script that dynamically scans the test cases folder, instantiates each test case, executes its methods asynchronously, and exits with code 0 on success or 1 on failure.
2. **Base Test Case Class (`res://src/tests/base_test_case.gd`)**: A lightweight `RefCounted` base class providing standardized isolated world spawning/destruction and assertion helpers (`assert_eq`, `assert_true`, etc.).
3. **Dedicated Test Cases (`res://src/tests/cases/`)**: Individual files implementing tests for the 7 core features.

To facilitate implementation, we have created the following proposed scripts in our agent working directory:
* `proposed_test_runner.gd` -> Blueprint for `res://src/tests/test_runner.gd` (82 lines)
* `proposed_base_test_case.gd` -> Blueprint for `res://src/tests/base_test_case.gd` (53 lines)
* `proposed_test_boss_lifecycle.gd` -> Test case demonstrating Boss Lifecycle assertions (53 lines)
* `proposed_test_terrain_collision.gd` -> Test case demonstrating Physics Terrain collision assertions (32 lines)

All proposed files strictly satisfy the project code conventions (static typing, under 200 lines per file, under 50 lines per function).

## 5. Verification Method
Verify the design and proposed files by performing the following steps:
1. Confirm the proposed scripts exist and can be inspected:
   * `d:\openclaw\giac-mo-co-tich\.agents\explorer_e2e_tests_1\proposed_test_runner.gd`
   * `d:\openclaw\giac-mo-co-tich\.agents\explorer_e2e_tests_1\proposed_base_test_case.gd`
   * `d:\openclaw\giac-mo-co-tich\.agents\explorer_e2e_tests_1\proposed_test_boss_lifecycle.gd`
   * `d:\openclaw\giac-mo-co-tich\.agents\explorer_e2e_tests_1\proposed_test_terrain_collision.gd`
2. Inspect the proposed files to ensure they conform to GDScript 4.6 syntax and static typing.
3. Once implemented in the source tree, the E2E test suite can be run headlessly using the following PowerShell command:
   ```powershell
   godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd
   ```
   An exit status code of `0` indicates success, while a non-zero exit status code indicates failure.
