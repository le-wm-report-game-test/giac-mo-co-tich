# Scope: Hill Terrain Collision Optimization (R1)

## Architecture
- `res://src/world/forest_builder.gd` is responsible for generating forest terrain including flat ground and hills.
- Active actors: Player (`res://src/player/player.gd`), Orc Mob (`res://src/world/orc_mob.gd`), Animal Bot (`res://src/world/animal_bot.gd`).
- Currently, hills generate ~10,000 individual `CollisionShape3D` nodes, causing high physics overhead.
- Goal: Create a single unified `ConcavePolygonShape3D` built from terrain mesh vertices, maintaining/integrating flat ground so that collision node count is reduced to 1.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Explore | Investigate `forest_builder.gd` and mesh generation logic, identify existing collision shapes and test files. | none | IN_PROGRESS (279a47bc-18b4-4934-9041-f1a319dcc997) |
| 2 | Implementation | Replace multiple CollisionShape3Ds with a single ConcavePolygonShape3D. Integrate/maintain flat ground. | M1 | PLANNED |
| 3 | Verification | Verify actor movement, player height match, and run headless test runner. | M2 | PLANNED |
| 4 | Audit & Signoff| Run Forensic Auditor to confirm clean implementation and compliance. | M3 | PLANNED |

## Interface Contracts
- The forest builder should expose a single static or dynamic collision shape representing the combined flat and hill terrain.
- Activating/deactivating physics or getting terrain height should still work exactly as before, but with significantly fewer collision nodes (reduced to 1).
- No new external APIs are introduced, but internal logic must adhere to the 200-line file limit and 50-line function limit.
