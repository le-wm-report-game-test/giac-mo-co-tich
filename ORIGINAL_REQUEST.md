# Original User Request

## Initial Request — 2026-06-26T00:35:43+07:00

This project focuses on resolving two critical issues in the GiacMoCoTich Godot 4.6 game project:
1. Terrain Physics Performance: The current system spawns up to 10,000 individual CollisionShape3Ds for hills, causing major physics performance drops.
2. God Objects Refactoring: Both `world_manager.gd` and `forest_builder.gd` exceed 660 lines, violating the 200-line coding rule. They must be split into single-responsibility scripts.

Working directory: d:/openclaw/giac-mo-co-tich
Integrity mode: demo

## Requirements

### R1. Optimize Hill Terrain Collision
Replace the 10,000 CollisionShape3Ds generated in `forest_builder.gd` with a single unified collision mesh `ConcavePolygonShape3D` built from the generated terrain mesh vertices. This should maintain exact hill heights while reducing collision node count to 1.

### R2. Refactor WorldManager God Object
Split `world_manager.gd` (667 lines) into smaller, single-responsibility Child Nodes/Components:
- `BossManager` (handles bosses, spawning, kill tracking)
- `WeatherManager` (handles weather cycles, storm particle effects, lightning strikes)
- `TreeFadeSystem` (handles transparent trees when player is behind them, camera clipping checks)
- `HUDManager` (handles creating and updating HUD/UI elements)
Keep each script file under 200 lines.

### R3. Refactor ForestBuilder God Object
Split `forest_builder.gd` (667 lines) into distinct, modular Child Nodes/Components:
- `TerrainBuilder` (procedural mesh generation and collision construction)
- `FloraScatterer` (scattering grass, flowers, mushrooms, bushes)
- `EntitySpawner` (spawning player, animals, enemies)
Keep each script file under 200 lines.

## Verification Resources
- Use Godot headlessly to check script syntax:
  ```powershell
  godot --headless --path d:\openclaw\giac-mo-co-tich --check-only
  ```

## Acceptance Criteria

### Performance & Physics
- [ ] Ground collision uses a single `ConcavePolygonShape3D` mesh shape instead of thousands of child collision shapes.
- [ ] Physics simulation runs smoothly with no performance drops when moving.

### Code Standards
- [ ] No GDScript file exceeds 200 lines.
- [ ] All functions are focused and under 50 lines.
- [ ] Node paths are exported or cached, avoiding hardcoded `/root/` lookups.
- [ ] All components communicate cleanly via Godot's EventBus singleton where applicable.
