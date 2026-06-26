# Handoff Report - E2E Testing Design Refinement

## 1. Observation
The following details were directly observed in the codebase:
* **HUD UI Updates**:
  * In `src/world/world_manager.gd`, `_create_hud()` (line 415) creates:
    * `UI/PlayerHealthContainer/PlayerHealthBar` (TextureProgressBar, line 434)
    * `UI/PlayerHealthContainer/PlayerHealthText` (Label, line 457)
    * `UI/OrcCounter/OrcCountLabel` (Label, line 476)
    * `UI/BossHealthContainer/BossHealthBar` (TextureProgressBar, line 497)
  * Damage numbers are spawned via `_spawn_damage_number(...)` at line 556:
    ```gdscript
    func _spawn_damage_number(amount: float, world_pos: Vector3, color: Color, is_critical: bool) -> void:
    ```
* **Spawning/Flora scattering**:
  * In `src/world/forest_builder.gd`, the deterministic seed is defined as:
    ```gdscript
    @export var random_seed: int = 2025
    ```
  * Species list and counts are defined in `_spawn_animals()` (line 601):
    ```gdscript
    var species_list := [
        {"type": 1, "count": 4, "name": "Cat"},
        {"type": 2, "count": 4, "name": "Rabbit"},
        {"type": 3, "count": 4, "name": "Parrot"}
    ]
    ```
  * Spawn exclusions are applied in `_spawn_animals()` (lines 622-627) and `_spawn_orcs()` (lines 656-660):
    * Animals: `pos_2d.distance_to(SPAWN_CENTER) < 6.0` (exclude)
    * Orcs: `pos_2d.distance_to(SPAWN_CENTER) < 8.0` (exclude)
    * Hills: `zone == Zone.HILL` (exclude)

## 2. Logic Chain
1. *Observation 1*: The game features are managed through `WorldManager` and `ForestBuilder` components. E2E tests must load `res://src/world/world.tscn` to execute integrated tests.
2. *Observation 1 & 2*: Project constraints demand that no script exceeds 200 lines and all methods remain statically typed and under 50 lines.
3. *Logic Step*: To keep tests below 200 lines while testing 20+ distinct test cases (Tiers 1 to 4), the test cases must be split across multiple files in `res://src/tests/cases/`.
4. *Logic Step*: Grouping tests by feature and tier (e.g., `test_hud_ui_tier1.gd`, `test_spawning_tier1.gd`) maintains compliance with the 200-line limit and categorizes tests logically.

## 3. Caveats
* **Jolt Physics Settling**: Tests involving Jolt Physics (collisions, movement) require awaiting multiple frame updates (`await tree.process_frame`) to allow positions to update. 
* **Crit Flakiness**: Crit numbers are calculated randomly in `_on_enemy_damaged`. Tests checking for crit popups must handle or assert on either regular or crit popups.
* **No Source Editing**: No code files inside `src/` were edited, conforming to the read-only explorer constraint.

## 4. Conclusion
The E2E testing design has been refined into 6 dedicated test case files located in `res://src/tests/cases/`, covering Tier 1 (Core HUD and Spawning), Tier 2 (Boundary/Edge Cases), Tier 3 (Feature Interactions), and Tier 4 (Prolonged Workload Scenarios). All scripts strictly conform to static typing and line count limits.

## 5. Verification Method
Verify the design and proposed files by performing the following steps:
1. Inspect the detailed blueprint file at `d:\openclaw\giac-mo-co-tich\.agents\explorer_m1_3\design.md` and check that all GDScript files defined are statically typed, under 200 lines, and contain methods under 50 lines.
2. Once the implementer translates these designs to files, execute the test runner headlessly via:
   ```powershell
   godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd
   ```
