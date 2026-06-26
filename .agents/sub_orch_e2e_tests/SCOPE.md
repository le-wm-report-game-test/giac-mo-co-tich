# Scope: Giac Mo Co Tich E2E Testing Track

## Architecture
- Module/package boundaries, data flow, shared interfaces:
  - `EventBus` (autoload): coordinates signals globally (`player_spawned`, `boss_spawned`, `weather_changed`, `enemy_died`, etc.).
  - `world.gd`: handles scene setup and instantiates player and camera.
  - `WorldManager`: handles boss lifecycle, weather cycles, tree fading, camera magnetic overrides, and HUD updates.
  - `ForestBuilder`: handles terrain mesh/collision construction and procedural entity spawning.
  - `BaseTestCase`: class that test files inherit from to run isolated worlds.
  - `test_runner.gd`: SceneTree runner script running tests headlessly.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Test runner | Implement E2E headless test runner and base test case | none | DONE |
| 2 | E2E Test Cases | Implement all test cases for Tier 1, Tier 2, Tier 3, and Tier 4 | M1 | DONE |
| 3 | E2E Verification | Run E2E test runner, audit execution, and output TEST_READY.md | M2 | DONE |

## Interface Contracts
### E2E Test Case Interface
- Every test script under `res://src/tests/cases/` must extend `BaseTestCase` or be loadable by the runner.
- Every test script can define test methods prefixed with `test_`.
- `BaseTestCase` will provide async `setup()` and `teardown()` to initialize/destroy `world.tscn`.
- Assertion helper methods: `assert_true`, `assert_false`, `assert_eq`, `assert_not_null`, etc.
