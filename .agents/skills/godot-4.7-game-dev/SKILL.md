---
name: godot-4.7-game-dev
description: Strict Godot 4.7 GDScript and engine best practices. Use when writing or editing GDScript, designing scenes, signals, components, or when a Godot task may default to Godot 3 patterns. Blocks legacy APIs (KinematicBody, yield, Godot 3 signal connect).
risk: safe
source: synthesized
date_added: "2026-07-09"
target_version: "Godot 4.7.x"
---

# Godot 4.7 Game Development

Strict Godot 4.7 patterns. Pairs with `godot-gdscript-patterns` (general 4.x reference) but is opinionated about 4.7-only APIs and rejects Godot 3 leakage.

## Use this skill when

- Writing or editing any `.gd` / `.tscn` / `.tres` file in a Godot project
- Asking "how do I do X in Godot" — answer must default to 4.7 API
- Reviewing code that might use legacy Godot 3 patterns
- Implementing signals, components, state machines, character controllers, or scenes

## Do not use this skill when

- The task is C#/.NET-only (Godot supports C# but most of this skill targets GDScript)
- The project is pinned to Godot 3.x
- The task is unrelated to Godot

## Hard rules (NEVER violate)

These are Godot 3 patterns that always regress. If generated code contains them, rewrite immediately.

| Forbidden (Godot 3) | Required (Godot 4.7) |
|---|---|
| `KinematicBody2D` / `KinematicBody3D` | `CharacterBody2D` / `CharacterBody3D` |
| `move_and_slide(velocity)` with arg | `velocity = ...; move_and_slide()` (no arg) |
| `yield(get_tree().create_timer(t), "timeout")` | `await get_tree().create_timer(t).timeout` |
| `"signal_name".connect(callable)` | `signal_name.connect(callable)` (Callable-based) |
| `tool` annotation (script runs in editor) | `@tool` (underscore-prefixed at-sign) |
| `export var x: int` | `@export var x: int` |
| `onready var x = $X` | `@onready var x: Type = $X` |
| `var t = Tween.new(); t.interpolate_property(...)` | `var t := create_tween(); t.tween_property(...)` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `get_tree().connect("idle_frame", ...)` | `get_tree().process_frame.connect(...)` |
| `Area2D.get_overlapping_bodies()` returning `Array` | Returns `Array[Node2D]` (typed) |
| `randi() % N` | `randi_range(0, N-1)` |
| `instance()` on PackedScene | `instantiate()` |

## Quick-reference: type system

```gdscript
class_name Player
extends CharacterBody3D

signal health_changed(new_value: int, max_value: int)

@export var speed: float = 5.0
@export_range(0.0, 1.0) var damage_reduction: float = 0.0
@export_group("Combat")
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.5

@onready var sprite: Sprite3D = $Sprite3D
@onready var anim: AnimationPlayer = $AnimationPlayer

var _health: int

func _ready() -> void:
    _health = max_health  # explicit super() not required in GDScript 4

func _physics_process(delta: float) -> void:
    velocity = Vector3(0, velocity.y, Input.get_axis("back", "forward") * speed)
    move_and_slide()  # no arg
```

## Quick-reference: signals (4.7 syntax)

```gdscript
# Declaration — typed parameters
signal damaged(amount: int, source: Node3D)

# Connect (Callable-based)
damaged.connect(_on_damaged)
damaged.connect(_on_damaged, CONNECT_ONE_SHOT)

# Disconnect
if damaged.is_connected(_on_damaged):
    damaged.disconnect(_on_damaged)

# Await a signal
await damaged
```

## Quick-reference: scene composition

- **Composition over inheritance.** High-complexity nodes (Player, WorldManager) decompose into child components named `[parent]_[purpose].gd` (e.g., `player_movement.gd`, `world_weather.gd`).
- **Strict size limits.** GDScript files ≤ 200 lines, functions ≤ 50 lines. Split before hitting the limit.
- **Signals for sibling communication.** Avoid `get_parent().get_node("...")` chains across the tree.
- **`@export` everything tunable.** Hardcoded constants in scripts become Inspector-invisible and can't be balanced.

## Quick-reference: resources as data

```gdscript
class_name WeaponData extends Resource

@export var name_id: StringName
@export var damage: int
@export var attack_speed: float
@export_range(0.0, 100.0) var range: float
@export var projectile_scene: PackedScene
@export var sound_attack: AudioStream
```

Use `resource.duplicate()` for runtime copies — never mutate shared `.tres` in-place.

## Quick-reference: state machine

```gdscript
class_name StateMachine extends Node

signal state_changed(from_name: StringName, to_name: StringName)

@export var initial_state: NodePath
var current_state: State
var states: Dictionary[StringName, State] = {}

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name] = child
            child.state_machine = self
            child.process_mode = Node.PROCESS_MODE_DISABLED
    if initial_state != NodePath():
        _enter_state(states[get_node(initial_state).name])

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
    var next := states.get(state_name)
    if next == null:
        push_error("State '%s' missing" % state_name)
        return
    current_state.exit()
    current_state.process_mode = Node.PROCESS_MODE_DISABLED
    _enter_state(next, msg)

func _enter_state(state: State, msg: Dictionary = {}) -> void:
    var prev := current_state
    current_state = state
    current_state.process_mode = Node.PROCESS_MODE_INHERIT
    current_state.enter(msg)
    state_changed.emit(prev.name if prev else &"", state.name)
```

## Quick-reference: project structure

```
project.godot
src/
├── player/
│   ├── player.gd                # Main composition root
│   ├── player_movement.gd       # Child component
│   ├── player_combat.gd
│   └── player_animator.gd
├── world/
│   ├── world.gd
│   ├── world_manager.gd
│   └── world_weather.gd
Assets/
addons/
```

## Performance rules

1. Cache `@onready` references — never `$Child` in `_process` / `_physics_process`.
2. Use typed arrays (`Array[Node3D]`) for hot loops; untyped `Array` is slower.
3. Pool frequently spawned nodes (bullets, particles, enemies) — see `godot-gdscript-patterns`.
4. Disable processing when offscreen: `set_process(false)` / `set_physics_process(false)`.
5. Forward+ is the default renderer in 4.7; mobile/Compatibility only when needed.

## Godot 4.7 specifics

- **`RenderingServer` global classes** — most of what you need is on `Node3D` and `Light3D` already; reach for `RenderingServer` only for hot-path rendering tweaks.
- **`TileMapLayer`** (replaces deprecated `TileMap`) — use for all 2D grids.
- **`@tool` scripts** — use sparingly; they run on every reload and can hide setup bugs.
- **Profile system** — `OpenXR` and `Forward+` only; `Mobile` is Forward+ with reduced features, `Compatibility` is the GL fallback.

## Verification before declaring done

- [ ] No Godot 3 APIs in new code
- [ ] All scripts typed (parameters + return)
- [ ] File ≤ 200 lines, functions ≤ 50 lines
- [ ] Tested in Godot editor (F5) — not just headless compile
- [ ] `@tool` only when script must run in editor

## Additional resources

- `resources/godot-3-4-migration.md` — full diff of forbidden patterns
- `resources/component-patterns.md` — composition recipes
- `resources/combinations.md` — **which skills to load for which subsystem** (player, world, lighting, mob, UI, VFX, save, perf)
- Pair with `godot-gdscript-patterns` (general 4.x reference)
- Pair with `godot-shaders-basics` when writing materials