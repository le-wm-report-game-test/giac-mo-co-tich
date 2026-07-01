# Giac Mo Co Tich — Agent Guide

## Project Overview

A Godot 4.x 3D action-adventure game set in a fantasy forest world. The player explores a procedurally generated forest, fights enemies (orcs, minotaurs, animals), and progresses through the world.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4.x |
| Language | GDScript |
| Terrain | Terrain3D addon |
| Rendering | Forward+ (3D) |

## Project Structure

```
giac-mo-co-tich/
├── project.godot
├── src/
│   ├── player/
│   │   └── player.gd
│   ├── world/
│   │   ├── world.gd
│   │   ├── world.tscn
│   │   ├── world_manager.gd
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

## Current Features

See `../feature_list.json` for full feature tracking.

## Development Rules

1. **Test in editor** — always verify changes work in Godot editor before committing
2. **Keep scenes modular** — one responsibility per scene/script
3. **Asset paths** — use relative paths from project root, never absolute
4. **No placeholder assets in production** — replace programmer art before marking feature done
5. **Consult feature_list.json** before starting new work to avoid duplication

## Protected Visual Design Contracts

- Before modifying trees, camera occlusion, tree materials/shaders, or player readability, read and obey [Tree Occlusion & Player Readability](.agents/rules/tree_occlusion_readability_rules.md).
- The tree fade constants and screen-space AABB algorithm are user-approved invariants. Do not replace them without explicit user approval.
