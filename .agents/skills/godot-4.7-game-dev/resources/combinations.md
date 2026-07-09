# Skill Combinations — giac-mo-co-tich

How to combine `godot-4.7-game-dev` with the rest of the workspace's Godot skill set for specific game subsystems. This file is the lookup table when you start a task and need to know which skills to load in what order.

## Skill role summary

| Skill | One-line role | When it leads |
|---|---|---|
| `godot-4.7-game-dev` | Strict 4.7 API rulebook — catches Godot 3 leakage | Every `.gd`/`.tscn`/`.tres` edit |
| `godot-gdscript-patterns` | Pattern catalog (FSM, pool, scene manager, save) | Designing a new system from scratch |
| `godot-mcp` | Live editor bridge — read tree, set properties, screenshot, run headless | Verifying changes, runtime introspection |
| `godot-shaders-basics` | Material/shader work — foliage, fog, hitflash, post-FX | Anything visual below gameplay logic |
| `godot-ui` | Control nodes, themes, HUD/menu/dialogue | Any user-facing screen |
| `godogen-pipeline` | Build-from-scratch AI pipeline (C# output) | **Do not use for this project** — see note below |

## ⚠️ When NOT to use `godogen-pipeline`

`giac-mo-co-tich` is mid-development GDScript. Godogen regenerates from scratch in C#, which would lose all existing code, Git history, and the GDScript-first convention. Reserve it for spinning up a brand-new standalone mini-game in a separate folder (e.g. a fishing minigame prototype), then manually port the generated scenes into this project.

---

## Master workflow

```
task lands
   ↓
[1] godot-4.7-game-dev    → choose API surface, list applicable hard rules
   ↓
[2] godot-gdscript-patterns (optional) → pick pattern recipe (FSM, pool, etc.)
   ↓
[3] code in `.gd` / `.tscn` / `.tres`
   ↓
[4] godot-mcp              → verify in live editor (read scene, set property, screenshot)
   ↓
[5] godot-shaders-basics OR godot-ui → only if task touches materials/UI
   ↓
[6] godot-mcp again        → final visual/runtime confirmation
```

The rule of thumb: **`godot-4.7-game-dev` is always on. `godot-mcp` brackets every edit with a verify step. The other three are loaded only when the task touches their domain.**

---

## Per-subsystem recipes

### Player (`src/player/*`)

| Concern | Lead skill | What to read/write |
|---|---|---|
| New component (movement, combat, animator) | `godot-4.7-game-dev` | `Hard rules` table, `Quick-reference: scene composition` |
| State machine (idle, attack, hurt, dodge, dead) | `godot-gdscript-patterns` | `Pattern 1: State Machine` in `implementation-playbook.md` |
| Damage flash on hit | `godot-shaders-basics` | `scripts/instance_uniform_hitflash.gdshader` |
| Verify scene + read live values | `godot-mcp` | `read_scene`, `get_node_properties` |
| Player readability under foliage (occlusion fix) | `godot-4.7-game-dev` (project rules) | `Protected Visual Design Contracts` in `AGENTS.md` + `tree_occlusion_readability_rules.md` |

### World / forest (`src/world/*`)

| Concern | Lead skill | What to read/write |
|---|---|---|
| Forest spawning, mob spawn pool | `godot-gdscript-patterns` | `Pattern 4: Object Pooling` |
| Scene transitions (biome swap, dungeon load) | `godot-gdscript-patterns` | `Pattern 6: Scene Management` |
| Foliage wind sway | `godot-shaders-basics` | `scripts/foliage_wind_sway_expert.gdshader` |
| Cliff/rock texturing (no UVs) | `godot-shaders-basics` | `scripts/triplanar_world_mapping.gdshader` |
| Localized fog (caves, swamp zones) | `godot-shaders-basics` | `Expert Pattern: Deferred-Fog-Volume` |
| Tree fade, camera occlusion readability | `godot-4.7-game-dev` | `tree_occlusion_readability_rules.md` (project rule wins) |
| Inspect or edit `world.tscn` safely | `godot-mcp` | `read_scene` then targeted `set_node_property` |
| Grass flattening around player | `godot-shaders-basics` | `scripts/global_grass_flatten.gdshader` |

### Lighting system (`src/lighting/profiles/*.tres`, lighting_director)

| Concern | Lead skill | What to read/write |
|---|---|---|
| Profile resource shape (`actor_fill_energy`, etc.) | `godot-4.7-game-dev` | `Quick-reference: resources as data` |
| Drive profile swap at runtime | `godot-4.7-game-dev` | `resources/component-patterns.md` → `lighting_director.gd` recipe |
| Diagnose why scene is too dark | `godot-mcp` | `lighting_diagnostic.gd` headless, `get_node_properties` on every DirectionalLight3D |
| Visual QA after a lighting edit | `godot-mcp` | `run_headless` → `capture_screenshot` → compare with `before.png` |
| Shader-based stylized look (e.g. hex pixelate) | `godot-shaders-basics` | `scripts/screenspace_hex_pixelate.gdshader` |
| Depth/world reconstruction for water/fog | `godot-shaders-basics` | `scripts/depth_world_reconstruction.gdshader` |

### Mob AI (`orc_mob.gd`, `animal_bot.gd`, `OrcBossMob`)

| Concern | Lead skill | What to read/write |
|---|---|---|
| State machine (Patrol, Chase, Attack, Dead) | `godot-gdscript-patterns` | `Pattern 1: State Machine` |
| Hitpoints / damage reception | `godot-gdscript-patterns` | `Pattern 5: Component System` (`HealthComponent`, `HitboxComponent`, `HurtboxComponent`) |
| Dissolve death effect | `godot-shaders-basics` | `scripts/dissolve_scissor_expert.gdshader` |
| Per-mob hit flash without breaking batching | `godot-shaders-basics` | `scripts/instance_uniform_hitflash.gdshader` |
| Mob stuck / wrong-path debugging | `godot-mcp` | `get_node_properties` on nav target, headless run, `get_console_errors` |
| Sight cone / line-of-sight checks | `godot-4.7-game-dev` + `godot-gdscript-patterns` | `PhysicsRayQueryParameters3D.create` + `space.intersect_ray` |

### Combat VFX (weapons, impacts, screen shake)

| Concern | Lead skill | What to read/write |
|---|---|---|
| Hit spark | `godot-shaders-basics` | `scripts/screenspace_full_quad.gdshader` + particle system |
| Screen shake / flash on hit | `godot-shaders-basics` | `screenspace_full_quad.gdshader` driven by uniform |
| Weapon trail | `godot-shaders-basics` | Custom thin geometry + `unshaded` material |
| Drive shader parameters from gameplay | `godot-4.7-game-dev` | `material.set_shader_parameter("name", value)` — typed |
| Many unique per-mob colors at once | `godot-shaders-basics` | `instance uniform` (NEVER duplicate material) |

### UI / HUD (`src/ui/*`, in-world HUD)

| Concern | Lead skill | What to read/write |
|---|---|---|
| HUD layout (health bar, weather indicator, minimap) | `godot-ui` | `HUD (Heads-Up Display)` template |
| Settings menu, pause menu | `godot-ui` | `Settings Menu` / `Pause Menu` templates |
| Dialogue system (NPC trees) | `godot-ui` | `Dialogue System` template + RichTextLabel |
| Inventory / item grid | `godot-ui` | `Inventory System` template |
| Gamepad + keyboard focus chain | `godot-ui` | `Menu Navigation with Keyboard/Gamepad` |
| UI tweening (fade, slide) | `godot-ui` | `Animated Transitions` (4.7 `create_tween()` syntax) |
| Underlying controller script typing | `godot-4.7-game-dev` | Strict typing, no Godot 3 leakage in UI scripts |
| Visual verify of UI placement | `godot-mcp` | `read_scene` on the menu `.tscn` + `capture_screenshot` |

### Save / persistence (save_manager)

| Concern | Lead skill | What to read/write |
|---|---|---|
| Save data shape + encryption | `godot-gdscript-patterns` | `Pattern 7: Save System` |
| `FileAccess.open_encrypted_with_pass` (4.7) | `godot-4.7-game-dev` | NEVER use `File.new()` from Godot 3 |
| Per-scene saveable components | `godot-gdscript-patterns` | `Saveable` node in `Pattern 7` |

### Performance audits

| Concern | Lead skill | What to read/write |
|---|---|---|
| Identify hot allocations | `godot-4.7-game-dev` | `Performance rules` (cache `@onready`, typed arrays, disable process) |
| Object pool for frequent spawns | `godot-gdscript-patterns` | `Pattern 4: Object Pooling` |
| Shader stutter on first encounter | `godot-shaders-basics` | `Expert Pattern: Shader-Precompilation-Warmup` |
| Verify draw call / batch count | `godot-mcp` | Run editor with `--debug-stringnames` or remote inspect |

### New mini-game / prototype

| Concern | Lead skill | What to read/write |
|---|---|---|
| Spinning up a side prototype | `godogen-pipeline` | Publish to a fresh sibling folder, then port scenes in |
| Porting Godogen C# → GDScript | `godot-4.7-game-dev` | Mechanically convert types, fix Godot 3 patterns that slipped through |
| Final fit into main project | `godot-gdscript-patterns` | Re-cast into the FSM / pool / component patterns |

---

## Anti-patterns to avoid

- ❌ Loading `godogen-pipeline` for edits to existing `giac-mo-co-tich` files — it will suggest regenerating from scratch.
- ❌ Editing `.tscn` text by hand for a tree the agent hasn't read — use `godot-mcp` `read_scene` first to see real node paths.
- ❌ Skipping `godot-4.7-game-dev` because "I know GDScript" — the LLM training data is full of Godot 3 and the rule table is the only guardrail.
- ❌ Loading `godot-shaders-basics` for a non-visual task — burns context, doesn't help.
- ❌ Using `godot-ui` for in-world 3D HUDs anchored to a `Node3D` — use `Control` under a `CanvasLayer` with viewport-anchored `SubViewport` only if the 3D-to-2D mapping is required.

---

## Quick picker (TL;DR)

| I want to… | Load this combo |
|---|---|
| Edit any existing script | `godot-4.7-game-dev` |
| Add a new enemy | `godot-4.7-game-dev` + `godot-gdscript-patterns` (FSM) + `godot-shaders-basics` (hitflash) |
| Fix lighting | `godot-4.7-game-dev` + `godot-mcp` |
| Add foliage sway | `godot-shaders-basics` + `godot-mcp` (verify shader compiles) |
| Add HUD element | `godot-ui` + `godot-4.7-game-dev` (typing) |
| Add main menu / settings | `godot-ui` |
| Debug "mob stuck" | `godot-mcp` (read live nav target) |
| Add save system | `godot-gdscript-patterns` (Pattern 7) + `godot-4.7-game-dev` |
| Spin up a new prototype | `godogen-pipeline` (in a sibling folder) |
| Profile / optimize | `godot-4.7-game-dev` (rules) + `godot-gdscript-patterns` (pool) + `godot-shaders-basics` (warmup) |
