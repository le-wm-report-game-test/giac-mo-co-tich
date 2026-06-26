# Project: Giac Mo Co Tich Optimization and Refactoring

## Architecture
The project refactors two "God Objects" (`WorldManager` and `ForestBuilder`) into modular, single-responsibility components and optimizes the terrain collision system to run efficiently.

### WorldManager Component Structure
`WorldManager` will act as a parent coordinator node that instantiates and attaches the following child components:
- `BossManager`: Handles boss spawning, boss lifecycle, and kill tracking.
- `WeatherManager`: Handles weather cycles, storm particle effects, and lightning strikes.
- `TreeFadeSystem`: Handles transparent trees when player is behind them and camera clipping checks.
- `HUDManager`: Handles creating and updating HUD/UI elements and spawning damage numbers.

### ForestBuilder Component Structure
`ForestBuilder` will act as a parent coordinator node that holds configuration exports and constants, and instantiates the following child components:
- `TerrainBuilder`: Handles procedural mesh generation and collision construction (ConcavePolygonShape3D).
- `FloraScatterer`: Handles scattering grass, flowers, mushrooms, and bushes.
- `EntitySpawner`: Handles spawning the player, animal bots, and orc enemies.

### Event Bus (Decoupling)
Global systems communicate asynchronously via the global `EventBus` autoload singleton (`res://src/common/event_bus.gd`).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | E2E Test Suite | Create comprehensive E2E tests for Tiers 1-4 | None | DONE |
| 2 | Hill Terrain Collision Optimization | Replace 10,000 CollisionShape3Ds with 1 ConcavePolygonShape3D | M1 | IN_PROGRESS (71f9b247-f1f8-445f-bca7-23a2eef13102) |
| 3 | WorldManager Refactoring | Split WorldManager into 4 child components (< 200 lines each) | M1 | IN_PROGRESS (39f37015-8346-4239-90ff-c98f2e2a233c) |
| 4 | ForestBuilder Refactoring | Split ForestBuilder into 3 child components (< 200 lines each) | M1, M2 | PLANNED |
| 5 | Adversarial Hardening | Implement Tier 5 tests and fix any remaining edge cases | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### Component ↔ Parent Node
- Child components (e.g. `TerrainBuilder`) retrieve configurations, meshes, scenes, and constants from their parent coordinator (`ForestBuilder` / `WorldManager`) via parent references.
- All code files must use strict static typing and remain under 200 lines of code.
- All functions must be focused and remain under 50 lines of code.

### Code Layout
- `src/world/components/boss_manager.gd`
- `src/world/components/weather_manager.gd`
- `src/world/components/tree_fade_system.gd`
- `src/world/components/hud_manager.gd`
- `src/world/components/terrain_builder.gd`
- `src/world/components/flora_scatterer.gd`
- `src/world/components/entity_spawner.gd`
