## 2026-06-25T19:10:26Z
You are a Refactoring Analyst (archetype: teamwork_preview_explorer).
Your working directory is: d:\openclaw\giac-mo-co-tich\.agents\explorer_refactor_3
Please analyze the existing `world_manager.gd` at `d:\openclaw\giac-mo-co-tich\src\world\world_manager.gd` and the tests in `d:\openclaw\giac-mo-co-tich\src\tests\cases\`.
Your goal is to formulate a clean design for splitting `world_manager.gd` into 4 child component nodes:
- `BossManager` (bosses, spawning, kill tracking)
- `WeatherManager` (weather cycles, storm particle effects, lightning strikes)
- `TreeFadeSystem` (transparent trees, camera clipping checks, camera magnet)
- `HUDManager` (HUD/UI, damage numbers)

Address:
1. Which specific variables, functions, and signal connections from `world_manager.gd` move to which components.
2. How `world_manager.gd` will declare getter/setter properties and delegate functions to preserve backwards compatibility (no test files can be modified).
3. How child components can communicate using clean GDScript patterns (EventBus, parent calling, signals).
4. Verify that each proposed file is under 200 lines, and functions under 50 lines.

Create BRIEFING.md, progress.md, and write your analysis to `d:\openclaw\giac-mo-co-tich\.agents\explorer_refactor_3\analysis.md`. Write handoff.md and report back.
