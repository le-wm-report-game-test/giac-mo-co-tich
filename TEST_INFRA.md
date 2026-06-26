# E2E Test Infra: Giac Mo Co Tich Refactoring & Optimization

## Test Philosophy
- Opaque-box, requirement-driven.
- Automated headless verification running via Godot 4.6.
- Systematic testing covering core gameplay, physics, performance, and refactored manager logic.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Ground & Hill Collision | R1. Optimize Hill Terrain Collision | 5 | 5 | ✓ |
| 2 | Boss Lifecycle Tracking | R2. Refactor WorldManager (Boss) | 5 | 5 | ✓ |
| 3 | Weather Cycles & Storms | R2. Refactor WorldManager (Weather) | 5 | 5 | ✓ |
| 4 | Tree Transparency / Fade | R2. Refactor WorldManager (TreeFade) | 5 | 5 | ✓ |
| 5 | Camera Clipping & Magnet | R2. Refactor WorldManager (TreeFade/Magnet) | 5 | 5 | ✓ |
| 6 | HUD UI Updates & Damage Num | R2. Refactor WorldManager (HUD) | 5 | 5 | ✓ |
| 7 | Forest Scattering & Spawning| R3. Refactor ForestBuilder | 5 | 5 | ✓ |

## Test Architecture
- **Test Runner**: Located at `src/tests/test_runner.gd`.
- **Invocation**: `godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`
- **Pass/Fail Semantics**: The test runner exits with code 0 on success, and a non-zero code on any failure.
- **Directory Layout**: Test scripts reside under `src/tests/`.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Full Game Flow | Spawning, scattering, weather cycles, tree fading, killing orcs, boss spawning, damage numbers, and camera magnet activation. | High |
| 2 | Physics and Collision | Player, animal, and orc mob movement across flat and hilly terrains, ensuring correct collision boundaries and height offsets. | Medium |
| 3 | Stress Spawning | Heavy load testing of animal bots, orc mobs, and flora props under varying performance limits. | Medium |

## Coverage Thresholds
- Tier 1: ≥5 test cases per feature (Happy-path coverage).
- Tier 2: ≥5 boundary/edge test cases per feature.
- Tier 3: Pairwise coverage of major feature interactions.
- Tier 4: At least 3 real-world workload application scenarios.
