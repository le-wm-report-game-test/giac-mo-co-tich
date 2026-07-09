# Component Patterns for Godot 4.7

The "composition over inheritance" pattern. High-complexity nodes split into child components, each owning one responsibility.

## When to decompose

A node is a composition root if it has any of:
- > 200 lines (file size limit)
- Multiple responsibilities (input + combat + animation + audio)
- Reused sub-systems across multiple actor types

## Naming convention

`[parent_name]_[component_purpose].gd`. Examples:

| Composition root | Components |
|---|---|
| `player.gd` | `player_movement.gd`, `player_combat.gd`, `player_animator.gd`, `player_audio.gd` |
| `world.gd` | `world_manager.gd`, `world_weather.gd`, `world_tree_fade.gd`, `world_hud.gd` |

## Pattern: sibling component communication

Components on the same parent should never `get_parent().get_node("Other")`. Use signals or a shared state reference on the parent.

```gdscript
# player.gd — composition root
extends CharacterBody3D

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var animator: PlayerAnimator = $Animator

func _ready() -> void:
    combat.attack_started.connect(animator.play_attack)
    combat.attack_landed.connect(_on_attack_landed)
    movement.dashed.connect(animator.play_dash)
```

```gdscript
# player_combat.gd
extends Node
class_name PlayerCombat

signal attack_started
signal attack_landed(target: Node3D, damage: int)

@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 2.0

var _can_attack: bool = true
var _attack_origin: Node3D

func try_attack() -> bool:
    if not _can_attack:
        return false
    _can_attack = false
    attack_started.emit()
    _resolve_hit()
    await get_tree().create_timer(attack_cooldown).timeout
    _can_attack = true
    return true

func _resolve_hit() -> void:
    var space := get_world_3d().direct_space_state
    var from := global_position + Vector3(0, 1.0, 0)
    var to := from + -transform.basis.z * attack_range
    var query := PhysicsRayQueryParameters3D.create(from, to)
    var hit := space.intersect_ray(query)
    if not hit.is_empty():
        var target := hit.collider as Node3D
        if target and target.has_method("take_damage"):
            target.take_damage(attack_damage)
            attack_landed.emit(target, attack_damage)
```

## Pattern: actor fill light component

A reusable child component for "always-lit" sprites in dark scenes — common in 2.5D games.

```gdscript
# actor_fill_light.gd
extends Node3D
class_name ActorFillLight

@export var parent_visual: Node3D
@export var light_color: Color = Color(0.9, 0.94, 0.98)
@export var light_energy: float = 1.0
@export_range(0.1, 5.0, 0.1) var follow_distance: float = 2.5
@export var follow_height: float = 1.5
@export_flags_3d_render var cull_mask: int = 0b10  # COMBAT_ACTOR layer

var _light: OmniLight3D

func _ready() -> void:
    _light = OmniLight3D.new()
    _light.light_color = light_color
    _light.light_energy = light_energy
    _light.omni_range = follow_distance * 2.0
    _light.light_cull_mask = cull_mask
    add_child(_light)

func _process(_delta: float) -> void:
    if parent_visual:
        global_position = parent_visual.global_position + Vector3(0, follow_height, 0)
```

## Pattern: profile-driven state

For weather, day/night, or any "mode-switching" behavior, store per-state values in a `Resource` and swap the resource, not the script.

```gdscript
# lighting_profile.gd
extends Resource
class_name LightingProfile

@export var profile_name: StringName
@export var sun_energy: float = 1.0
@export var sun_color: Color = Color.WHITE
@export var ambient_energy: float = 0.3
@export var ambient_color: Color = Color(0.2, 0.25, 0.3)
@export var exposure: float = 1.0
@export var fog_density: float = 0.01
@export var actor_fill_energy: float = 0.8
@export var player_accent_energy: float = 0.2
@export var wet_amount: float = 0.0
```

```gdscript
# lighting_director.gd
extends Node
class_name LightingDirector

@export var clear_profile: LightingProfile
@export var rain_profile: LightingProfile
@export var storm_profile: LightingProfile

var _current: LightingProfile
@onready var _env: WorldEnvironment = get_parent().get_node("WorldEnvironment")

func set_weather(weather: StringName, animated: bool = true) -> void:
    var profile: LightingProfile
    match weather:
        &"clear": profile = clear_profile
        &"rain": profile = rain_profile
        &"storm": profile = storm_profile
        _: push_error("Unknown weather: %s" % weather); return
    _current = profile
    _apply(profile, animated)

func _apply(p: LightingProfile, animated: bool) -> void:
    if animated:
        var t := create_tween().set_parallel(true)
        t.tween_property(_env.environment, "ambient_light_energy", p.ambient_energy, 2.0)
        # ... etc
    else:
        _env.environment.ambient_light_energy = p.ambient_energy
```

## Anti-patterns

- ❌ Components reaching into parent (`get_parent().get_node(...)`) — use signals up.
- ❌ Components reaching across the tree (`get_tree().get_first_node_in_group("Player")`) — pass references through composition root.
- ❌ Shared mutable state on `Resource` — `resource.duplicate()` for runtime, never mutate the `.tres` in place.
- ❌ Components that exist only to call one method on parent — inline at the composition root instead.