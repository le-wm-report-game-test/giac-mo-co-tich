# Scope: Milestone 3 WorldManager God Object Refactoring (R2)

## Architecture
We are splitting `res://src/world/world_manager.gd` (the parent coordinator) into 4 child component nodes:
1. `BossManager` (`res://src/world/boss_manager.gd`) - Handles bosses, spawning, and kill tracking.
2. `WeatherManager` (`res://src/world/weather_manager.gd`) - Handles weather cycles, storm particle effects, lightning strikes.
3. `TreeFadeSystem` (`res://src/world/tree_fade_system.gd`) - Handles tree transparency checks and camera clipping checks.
4. `HUDManager` (`res://src/world/hud_manager.gd`) - Handles UI elements creation, updates, and damage numbers.

The `WorldManager` acts as the parent coordinator, instantiating these child nodes dynamically in its `_ready()` function or holding them as static scene children, and delegates public fields and API functions to them via GDScript getters/setters and function wrappers. This ensures backwards compatibility with existing test cases in `src/tests/cases/`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Explore | Analyze the current `world_manager.gd` and map functions/variables | none | PLANNED |
| 2 | Component Implementation | Implement BossManager, WeatherManager, TreeFadeSystem, and HUDManager components | M1 | PLANNED |
| 3 | Coordinator Refactoring | Modify `world_manager.gd` to compose the components and forward APIs | M2 | PLANNED |
| 4 | Verification & Audit | Run headless Godot test suite and perform Forensic Audit | M3 | PLANNED |

## Interface Contracts
- All component scripts should extend `Node` (or appropriate sub-class if needed, but `Node` is standard) and use PascalCase for class names: `BossManager`, `WeatherManager`, `TreeFadeSystem`, `HUDManager`.
- Property delegation getters and setters in `world_manager.gd`:
  - `boss_spawned`, `orcs_to_kill_for_boss`, `boss_instance`, `orcs_killed` -> delegated to `BossManager`
  - `weather_state`, `weather_timer`, `weather_duration`, `is_raining`, `rain_cycle_count`, `rain_particles` -> delegated to `WeatherManager`
  - `tree_list`, `camera_magnet_active`, `camera_magnet_target`, `camera_magnet_zoom`, `camera_magnet_duration`, `camera_magnet_timer` -> delegated to `TreeFadeSystem`
- Method delegation:
  - `_collect_trees()` -> delegated to `TreeFadeSystem`
  - `_activate_camera_magnet()` -> delegated to `TreeFadeSystem`
  - `_strike_lightning()` -> delegated to `WeatherManager`
  - `_show_boss_health_bar()` / `_hide_boss_health_bar()` -> delegated to `HUDManager`
- Line count constraints:
  - Every script file must be under 200 lines.
  - Every function must be under 50 lines.
  - All properties must have explicit static types.
