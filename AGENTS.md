# Giac Mo Co Tich — Agent Guide

## Project Overview

A Godot 4.x 3D action-adventure game set in a fantasy forest world. The player explores a procedurally generated forest, fights enemies (orcs, minotaurs, animals), and progresses through the world.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4.7 |
| Language | GDScript |
| Terrain | Terrain3D addon |
| Rendering | Forward+ (3D) |

## Project Structure

```
giac-mo-co-tich/
├── project.godot
├── src/
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_movement.gd
│   │   ├── player_combat.gd
│   │   └── player_animator.gd
│   ├── world/
│   │   ├── world.gd
│   │   ├── world.tscn
│   │   ├── world_manager.gd
│   │   ├── world_weather.gd
│   │   ├── world_tree_fade.gd
│   │   ├── world_hud.gd
│   │   ├── world_camera_magnet.gd
│   │   ├── forest_builder.gd
│   │   ├── orc_mob.gd
│   │   └── animal_bot.gd
│   └── audio/
│       └── audio_manager.gd
├── Assets/
│   ├── enemies/
│   │   └── minotaur/
│   └── Tiny RPG Character Asset Pack v1.03/
└── addons/
    └── terrain_3d/
```

## Coding Conventions

- **GDScript:** Use PascalCase for class names, snake_case for variables/functions
- **Scenes:** PascalCase with `.tscn` extension
- **Signals:** Prefix with `signal_` (e.g., `signal_player_damaged`)
- **Exports:** Use `@export` annotations with type hints
- **Comments:** Vietnamese for game logic explanations, English for technical comments
- **Composition over Inheritance:** High-complexity nodes (e.g., Player, WorldManager) must decompose logic into smaller child component nodes.
- **Component File Naming:** Child component script files must follow: `[parent_name]_[component_purpose].gd` (e.g., `player_movement.gd`, `world_weather.gd`).

## Current Features

See `../feature_list.json` for full feature tracking.

## Development Rules

1. **Test in editor** — always verify changes work in Godot editor before committing
2. **Keep scenes modular** — one responsibility per scene/script
3. **Asset paths** — use relative paths from project root, never absolute
4. **No placeholder assets in production** — replace programmer art before marking feature done
5. **Consult feature_list.json** before starting new work to avoid duplication
6. **Strict Size Limits:** GDScript files must NOT exceed **200 lines**, and functions must NOT exceed **50 lines** to prevent God Objects.

## Protected Visual Design Contracts

- Before modifying trees, camera occlusion, tree materials/shaders, or player readability, read and obey [Tree Occlusion & Player Readability](.agents/rules/tree_occlusion_readability_rules.md).
- The tree fade constants and screen-space AABB algorithm are user-approved invariants. Do not replace them without explicit user approval.

## Agent skills

### Issue tracker

Local markdown file tracking under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical labels mapped 1-to-1 in local tracking. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context documentation layout. See `docs/agents/domain.md`.
