# Refactoring Analysis: Splitting WorldManager into Child Component Nodes

This report details a clean, modular architecture to decompose the complex `world_manager.gd` (originally 697 lines of code) into four distinct, self-contained child component nodes, while preserving 100% backwards compatibility with all existing test cases.

---

## 1. Distribution of Variables, Functions, and Signal Connections

The responsibilities from the original `world_manager.gd` are split among the four child components as follows:

### A. `BossManager`
*   **Responsibility**: Managing boss lifecycle, spawning triggers, and tracking counts.
*   **Moved Variables**:
    *   `orcs_to_kill_for_boss: int`
    *   `orcs_killed: int`
    *   `boss_spawned: bool`
    *   `boss_instance: Node3D`
*   **Moved Functions**:
    *   `_on_enemy_died(enemy: Node3D) -> void`
    *   `_spawn_boss() -> void`
    *   `_setup_boss_stats(boss: CharacterBody3D) -> void` (extracted to helper)
*   **Connections**:
    *   Listens to `EventBus.enemy_died` to increment the kill count and trigger spawning.
    *   Emits local signals for communication: `boss_spawned_signal(boss)`, `boss_killed_signal()`, and `orc_killed_count_signal(count)`.
    *   Emits `EventBus.orc_killed_count` and `EventBus.boss_spawned` to maintain global events.

### B. `WeatherManager`
*   **Responsibility**: Managing weather states, rain particles, thunder strikes, sound effects, and lighting transitions.
*   **Moved Variables**:
    *   `weather_timer: float`
    *   `weather_duration: float`
    *   `weather_state: String`
    *   `rain_cycle_count: int`
    *   `rain_particles: GPUParticles3D`
    *   `lightning_timer: float`
    *   `is_raining: bool`
*   **Moved Functions**:
    *   `_update_weather(delta: float) -> void`
    *   `_start_rain() -> void`
    *   `_end_rain() -> void`
    *   `_create_rain_particles() -> void`
    *   `_stop_rain_particles() -> void` (extracted to helper)
    *   `_strike_lightning() -> void`
    *   `_spawn_lightning_flash() -> void` (extracted to helper)
    *   `_spawn_lightning_bolt(strike_pos: Vector3) -> void` (extracted to helper)
    *   `_apply_lightning_damage(strike_pos: Vector3) -> void` (extracted to helper)
    *   `_apply_ambient_darkening(factor: float) -> void`
    *   `_configure_lighting() -> void`
    *   `_configure_sun() -> void` (extracted to helper)
    *   `_configure_environment() -> void` (extracted to helper)
    *   `_configure_ambient() -> void` (extracted to helper)
    *   `_update_weather_lighting(is_rainy: bool) -> void`
*   **Connections**:
    *   Emits `EventBus.weather_changed` during weather transitions.
    *   Uses `AudioManager` singleton for ambience and SFX.

### C. `TreeFadeSystem`
*   **Responsibility**: Tree transparency calculations, camera clipping checks, and camera magnet targeting.
*   **Moved Variables**:
    *   `tree_list: Array[Node3D]`
    *   `camera_magnet_active: bool`
    *   `camera_magnet_target: Vector3`
    *   `camera_magnet_zoom: float`
    *   `camera_magnet_duration: float`
    *   `camera_magnet_timer: float`
*   **Moved Functions**:
    *   `_collect_trees() -> void`
    *   `_collect_tree_children(node: Node) -> void`
    *   `_update_tree_fade() -> void`
    *   `_set_tree_alpha(node: Node, alpha: float) -> void`
    *   `_apply_alpha_to_mesh(mesh_node: MeshInstance3D, alpha: float) -> void` (extracted to helper)
    *   `_update_tree_camera_clip() -> void`
    *   `_activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void`
    *   `_update_camera_magnet(delta: float) -> void`

### D. `HUDManager`
*   **Responsibility**: Initializing the HUD layer, updating the health bar, spawning damage numbers, and showing/hiding boss health bar.
*   **Moved Functions**:
    *   `_create_hud() -> void`
    *   `_create_player_health_bar(ui: CanvasLayer) -> void` (extracted to helper)
    *   `_create_orc_counter(ui: CanvasLayer) -> void` (extracted to helper)
    *   `_create_boss_health_bar(ui: CanvasLayer) -> void` (extracted to helper)
    *   `_update_ui_orc_counter(killed: int, total_needed: int) -> void`
    *   `_on_player_health_changed(current: float, max_h: float) -> void`
    *   `_show_boss_health_bar() -> void`
    *   `_hide_boss_health_bar() -> void`
    *   `update_boss_health(current: float, max_h: float) -> void`
    *   `_on_player_took_damage(amount: float, position: Vector3) -> void`
    *   `_on_enemy_damaged(enemy: Node3D, amount: float, position: Vector3) -> void`
    *   `_spawn_damage_number(amount: float, world_pos: Vector3, color: Color, is_critical: bool) -> void`
*   **Connections**:
    *   Listens to `EventBus` signals: `player_health_changed`, `player_took_damage`, and `enemy_damaged`.

---

## 2. Backwards Compatibility & Delegation Design

Because existing test cases cannot be modified, `WorldManager` acts as a facade. It exposes all original properties and functions, delegating internally to the appropriate child components.

### A. Property Getter/Setter Delegation
GDScript 2.0 properties with `get` and `set` are used to redirect access to the underlying child components. An internal fallback is used for `@export` properties during initial scene loading prior to `_ready()` initialization:

```gdscript
# Example of export property fallback
var _orcs_to_kill_fallback: int = 5
@export var orcs_to_kill_for_boss: int:
	get: return boss_manager.orcs_to_kill_for_boss if boss_manager else _orcs_to_kill_fallback
	set(v):
		_orcs_to_kill_fallback = v
		if boss_manager: boss_manager.orcs_to_kill_for_boss = v

# Example of standard property redirection
var weather_state: String:
	get: return weather_manager.weather_state if weather_manager else "clear"
	set(v): if weather_manager: weather_manager.weather_state = v
```

### B. Function Delegates
Functions accessed by the tests (e.g. `_collect_trees()`, `_activate_camera_magnet()`, `_spawn_boss()`) are declared on `WorldManager` and call the corresponding child methods:

```gdscript
func _collect_trees() -> void:
	if tree_fade_system: tree_fade_system._collect_trees()
```

### C. UI Path Preservation
Tests query UI nodes using paths like `WorldManager/UI/BossHealthContainer`. To satisfy this, the `HUDManager` instantiates the `UI` canvas layer and attaches it as a sibling under `WorldManager`:
```gdscript
# Inside HUDManager:
func _create_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	# Attach as child of WorldManager so paths like WorldManager/UI/ remain valid
	get_parent().add_child.call_deferred(ui)
```

---

## 3. Communication Patterns

A clean **Mediator Pattern** is utilized to keep the child components completely decoupled from one another:

1.  **Children to Parent (Upward)**: Child components emit signals (`boss_spawned_signal`, `boss_killed_signal`, `orc_killed_count_signal`) when events occur.
2.  **Parent Orchestration (Downward)**: `WorldManager` listens to child signals in `_ready()` and routes commands to other child components:
    ```gdscript
    func _ready() -> void:
        boss_manager.boss_spawned_signal.connect(_on_boss_spawned)
        boss_manager.boss_killed_signal.connect(_on_boss_killed)
        boss_manager.orc_killed_count_signal.connect(_on_orc_killed_count_changed)
    ```
    *   `_on_boss_spawned(boss)` triggers `tree_fade_system._activate_camera_magnet(...)` and `hud_manager._show_boss_health_bar()`.
    *   `_on_boss_killed()` triggers `hud_manager._hide_boss_health_bar()`.
    *   `_on_orc_killed_count_changed(count)` triggers `hud_manager._update_ui_orc_counter(...)`.
3.  **Global Events**: Systems hook into the global `EventBus` autoload for loosely coupled gameplay updates (e.g., `EventBus.player_health_changed`, `EventBus.enemy_damaged`).

---

## 4. File and Function Length Verification

Each proposed script is structured to be well below the limits specified in the coding guidelines:

| File Path | Purpose | Total Lines | Longest Function | Function Limit |
|---|---|---|---|---|
| `world_manager.gd` | Facade and Orchestrator | ~138 lines | `_on_boss_spawned` (12 lines) | Under 50 lines |
| `components/boss_manager.gd` | Boss lifecycle and spawning | ~69 lines | `_spawn_boss` (25 lines) | Under 50 lines |
| `components/weather_manager.gd` | Weather states & particles | ~192 lines | `_create_rain_particles` (25 lines) | Under 50 lines |
| `components/tree_fade_system.gd` | Tree fades & camera magnet | ~125 lines | `_update_tree_fade` (20 lines) | Under 50 lines |
| `components/hud_manager.gd` | HUD creation and popups | ~163 lines | `_create_player_health_bar` (43 lines) | Under 50 lines |

This decomposition divides a single monolithic 697-line script into five simple, single-responsibility files that are easily readable and maintainable, satisfying all clean coding rules.
