# Minimap HUD — Design Spec

**Date:** 2026-06-26
**Status:** Design Approved → Ready for Implementation

## Overview

Add a minimap (120×120px) to the top-right corner of the HUD showing player position (blue dot) and enemy positions (red dots) within a 30-unit radar range. Helps players locate enemies faster without pausing gameplay.

---

## Specifications

| Attribute | Value |
|-----------|-------|
| Position | Top-right corner of screen |
| Size | 120×120px |
| Radar range | 30 Godot units |
| Player dot | Blue circle, radius 3px |
| Enemy dot (normal) | Red circle, radius 3px |
| Boss dot | Red circle, radius 6px (2-3× normal) |
| Background | Dark semi-transparent (alpha 0.6) + 1px white border + grid |
| Grid | 12-unit cells → ~48px on canvas |
| Map boundary | ±48 units → scaled to ±60px on 120px canvas |

## Enemy Groups Queried

- `orc_mobs` — regular orcs + boss (filter by `is_in_group("boss")` for size)
- `animals` — AnimalBot instances (cats, dogs, rabbits, parrots)

## Architecture

```
src/ui/minimap.gd  (extends Control, uses _draw())
     ↓ instantiated + updated every frame
world_manager.gd → _create_hud() → add Minimap to UI CanvasLayer
     ↓ per-frame
world_manager._process() → minimap.update_positions(player_pos, enemies[])
```

### minimap.gd API

```gdscript
class_name Minimap
extends Control

## Radar range in world units (how far enemies are visible)
@export var radar_range: float = 30.0

## World map limit (± this value)
@export var map_limit: float = 48.0

func setup(size_px: Vector2) -> void
    # Sets control size, initializes state

func update_positions(player_pos: Vector3, enemies: Array[Dictionary]) -> void
    # enemies = [{"position": Vector3, "is_boss": bool}, ...]
    # Triggers queue_redraw() → _draw()
```

## Drawing Logic (in `_draw()`)

1. **Background:** `draw_rect(Rect2(Vector2.ZERO, size), dark_color)` with alpha 0.6
2. **Border:** `draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 1.0)`
3. **Grid:** Horizontal + vertical lines at 12-unit intervals, scaled to canvas
4. **Player dot:** `draw_circle(world_to_canvas(player_pos), 3, Color.BLUE)`
5. **Enemy dots:** `draw_circle(world_to_canvas(enemy_pos), 3 or 6, Color.RED)`
6. **Clipping:** Only draw enemies within radar_range of player

## Coordinate Conversion

`world_to_canvas(world_pos: Vector3) -> Vector2`:
```
canvas_x = (world_pos.x / radar_range) * (canvas_width / 2) + (canvas_width / 2)
canvas_y = (canvas_width / 2) - (world_pos.z / radar_range) * (canvas_width / 2)
```

Player is always at center of the minimap (60, 60). Enemies are offset from center based on their world position relative to player, scaled by `radar_range → canvas_size / 2`.

## Integration Points

### world_manager.gd changes:

1. **Import:** `var minimap: Minimap`
2. **`_create_hud()`:** Add Minimap instance to UI CanvasLayer, positioned top-right
3. **`_process()`:** Call `_update_minimap()` after other systems
4. **`_update_minimap()`:** Query groups, build enemy array, call `minimap.update_positions()`

## Test Coverage

- Minimap appears in top-right corner
- Player blue dot visible at center
- Orc red dots appear when within 30 units
- Boss red dot is larger than normal enemy dots
- Animal dots appear when within 30 units
- Dots move as player/enemies move
- Grid and border render correctly
- No crash when player or enemies are null
