---
name: godot-mcp
description: Godot MCP server integration for Cursor AI. Use when the editor needs to inspect scene trees, read live node properties, edit scenes, run the game headless, or read console errors — capabilities that file reads alone cannot provide.
risk: safe-with-config
source: synthesized
date_added: "2026-07-09"
target_version: "Godot 4.7.x"
---

# Godot MCP Integration

Wire Cursor (or any MCP-compatible client) to a live Godot editor through a Model Context Protocol server. The AI gains scene-tree awareness, can read real node properties, edit scripts/scenes, and capture screenshots — without leaving chat.

## Use this skill when

- Need to inspect what nodes exist in a `.tscn` without parsing text
- Want to read live node properties at runtime (Position3D, light_energy, fog density)
- Editing scene files (`_tscn`) and need to confirm structure before/after
- Headless validation: run scene, capture screenshot, check console errors
- Refactoring scenes — need usage data (`find_usages` for node paths)

## Do not use this skill when

- No MCP server is installed (use file tools + headless Godot CLI instead)
- The task is purely GDScript logic that doesn't touch the scene tree
- You need to write a brand-new `.tscn` from scratch (text authoring is fine)

## Available MCP servers (pick one)

| Server | Engine | Tools | Notes |
|---|---|---|---|
| `pcphantom/godot-mcp` | Godot 4.x | 32 tools | MIT, WebSocket-bridged, very active |
| `Godot AI` (Asset Library #5050) | Godot 4.3+ (4.4+ recommended) | 150+ ops | Commercial-grade, screenshots built-in |
| `godotiq` | Godot 4.x | spatial + runtime | Best for Composer mode workflows |

For **Godot 4.7**, prefer `pcphantom/godot-mcp` (works with 4.7, MIT, broad community) or `Godot AI` (more polished but heavier setup).

## Setup — `pcphantom/godot-mcp`

1. **Install the addon** in your Godot project:
   ```bash
   # From Godot editor: Project > Manage Plugins > search "Godot MCP"
   # Or clone into addons/
   git clone https://github.com/pcphantom/godot-mcp.git addons/godot-mcp
   ```
   Then enable the plugin in `Project Settings > Plugins`.

2. **Configure Cursor** at `.cursor/mcp.json` (project root):
   ```json
   {
     "mcpServers": {
       "godot": {
         "command": "uvx",
         "args": ["godot-mcp"],
         "env": {
           "GODOT_PATH": "D:\\Godot\\Godot_v4.7-stable_win64_console.exe"
         }
       }
     }
   }
   ```
   Windows path for this project: `D:\Godot\Godot_v4.7-stable_win64_console.exe`.

3. **Restart Cursor** — quit and reopen so it picks up the new MCP config.

4. **Start the Godot editor** (with the plugin enabled). The MCP server bridges to it via WebSocket (default port 6007).

5. **Verify**: in Cursor, ask *"list MCP tools"* — should see ~32 godot tools like `read_scene`, `get_node_properties`, `edit_script`, `run_scene`.

## Common workflows

### Inspect a scene before editing

> "Show me the structure of `res://src/world/world.tscn` and the current values of every DirectionalLight3D's `light_energy`."

→ Calls `read_scene` then `get_node_properties` per light. No guessing node paths.

### Edit scene node properties

> "Set `WorldEnvironment.environment.ambient_light_energy` to 0.42."

→ Calls `set_node_property`. Returns new scene tree dump for verification.

### Headless run + screenshot

> "Run `res://src/world/world.tscn` headless for 3 seconds and screenshot the viewport."

→ Calls `run_headless` then `capture_screenshot`. Returns PNG bytes for visual review.

### Read console errors

> "Run the project headless and tell me the first 5 errors."

→ Calls `get_console_errors` after `run_headless`. Surfaces parse errors, missing resources, signal connect failures.

### Refactor with usage tracking

> "Find every script that reads `_actor_fill_light.light_energy`."

→ Calls `find_usages` (if available) or falls back to Grep over `.gd`.

## What MCP does NOT do

- **No undo.** Changes save directly — keep git clean before MCP sessions.
- **No remote.** Runs localhost-only.
- **No multi-instance.** One Godot at a time.
- **No runtime simulation.** Can't press play, simulate input, or trigger game logic that requires input.
- **No dependency-free C#.** The `.NET` build is heavier than GDScript-only.

For runtime input simulation, use `screenshot_tool.gd` or a custom headless `SceneTree`-based script (see `resources/headless-patterns.md`).

## When MCP is unavailable

Fallback to file tools + headless Godot CLI:

```bash
# Inspect a scene
godot --headless --path . --quit-after 1 res://src/world/world.tscn

# Capture screenshot via custom tool script
godot --headless --path . --script res://src/tests/screenshot_tool.gd

# Validate parse
godot --headless --path . --check-only --script res://src/player/player.gd
```

For deeper runtime introspection, write a one-shot `SceneTree`-based script:

```gdscript
# res://src/tests/lighting_diagnostic.gd
extends SceneTree

func _initialize() -> void:
    var packed := load("res://src/world/world.tscn") as PackedScene
    if packed == null:
        push_error("Cannot load scene"); quit(1); return
    var inst: Node = packed.instantiate()
    root.add_child(inst)
    await process_frame
    await process_frame
    # ...inspect nodes...
    print("=== END ===")
    quit(0)
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| MCP tools not visible | Quit Cursor fully, reopen. Check `.cursor/mcp.json` syntax with `jq .`. |
| WebSocket refused on 6007 | Port conflict — set `addon_port` in addon settings and matching env in `mcp.json`. |
| Godot plugin won't enable | Confirm `addons/godot-mcp/plugin.cfg` exists and `script = "plugin.gd"` path is correct. |
| Scripts show Godot 3 patterns | Add `.cursor/rules/godot-4.7.mdc` (auto-loads for `.gd` files) — see companion skill. |

## Additional resources

- `resources/headless-patterns.md` — script templates for headless introspection without MCP
- `resources/mcp-server-comparison.md` — feature matrix of the three servers