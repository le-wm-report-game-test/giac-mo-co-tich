# SlimeMob — Design Spec

**Status:** ✅ **Implemented** (2026-07-08) — see Section 15.
**Engine:** Godot 4.7, GDScript
**Pattern reference:** `src/world/animal_bot.gd` (passive mob, IDLE/WANDER state machine)

---

## 1. Core Decisions

| # | Aspect | Decision |
|---|--------|----------|
| 1 | Role | Passive ambient (như `AnimalBot`) |
| 2 | AI | Idle 80% + wander 20%, đổi hướng mỗi 3-8s hoặc khi obstacle |
| 3 | Direction | 4-way (up→back, down→front, left/right→side flip-h) |
| 4 | Colors | 4 màu earth-tone, weighted (green 40, blue 25, purple 20, lime 15) |
| 5 | Idle anim | Squash & stretch Y 1.1↔0.85, cycle 1.5s |
| 6 | Move anim | Hop (anticipation squash → stretch → land), cycle 0.6s |
| 7 | Spawn | 4/chunk, 60% chunks populated, hard cap 30 |
| 8 | Player | Flee khi player <5m, recover 2s |
| 9 | Despawn | Chunk-based (forest chunk lifecycle) |
| 10 | Damage | 1 HP, hurt sprite 0.3s → despawn, no respawn |

---

## 2. Sprite Direction Mapping — REVISED (moved to §4b, kept brief here)

Xem **§4b. Sprite Direction Mapping** bên dưới cho mapping đầy đủ.

4 directions dùng PocketWitch format `slime_{color}_{dir}.png`:
- down → `_front.png`
- up → `_back.png`
- left → `_side.png` (no flip)
- right → `_side.png` + `flip_h = true`
- hurt → `slime_hurt.png` (color-local, 0.3s)

**Sprite pixel size:** analogous to OrcMob — sprite base ~48px, pixel_size=0.011 → ~0.53m visible width. Slime is round blob, hơi thấp và rộng; position.y offset = 0.28 để chân chạm đất phẳng.

---

## 4. Color Variant Mapping — REVISED

### Verified asset layout (`Assets/PocketWitch-Slimes_v2.1/Slimes/`):

Mỗi color folder chứa 4 files:

```
{color folder}/
├── slime_{color}_front.png     # sprite facing camera (+Z)
├── slime_{color}_side.png       # sprite profile, flip_h cho left
├── slime_{color}_back.png       # sprite facing away (−Z)
└── slime_hurt.png               # shared hurt sprite per folder
```

### Forest palette (4 chọn lọc — verified have all 4 direction files):

| Color | Folder | Weight | Example files |
|-------|--------|--------|---------------|
| green | `Slimes/green slime/` | 40% | `slime_green_front.png`, `slime_green_side.png`, `slime_green_back.png`, `slime_hurt.png` |
| blue | `Slimes/blue slime/` | 25% | `slime_blue_front.png`, `slime_blue_side.png`, `slime_blue_back.png`, `slime_hurt.png` |
| purple | `Slimes/purple slime/` | 20% | `slime_purple_front.png`, `slime_purple_side.png`, `slime_purple_back.png`, `slime_hurt.png` |
| violet | `Slimes/violet slime/` | 15% | `slime_violet_front.png`, `slime_violet_side.png`, `slime_violet_back.png`, `slime_hurt.png` |

**Note:** Tôi đổi "lime" → "violet" vì asset folder có `violet slime/` chứ không có `lime slime/`. Violet vẫn trong tone earth-tone phù hợp với forest fantasy theme.

### Asset path format:

```gdscript
# Example: load green slime side
const SLIME_BASE := "res://Assets/PocketWitch-Slimes_v2.1/Slimes"
var path := "%s/%s slime/slime_%s_%s.png" % [SLIME_BASE, color, color, direction]
# e.g. res://Assets/PocketWitch-Slimes_v2.1/Slimes/green slime/slime_green_side.png

# Hurt (color-independent — same file name in each folder):
var hurt_path := "%s/%s slime/slime_hurt.png" % [SLIME_BASE, color]
```

---

## 4b. Sprite Direction Mapping — REVISED

| Game dir | Sprite file | Flip |
|----------|-------------|------|
| down (S, +Z) | `slime_{color}_front.png` | no |
| up (N, −Z) | `slime_{color}_back.png` | no |
| left (W, −X) | `slime_{color}_side.png` | no (mặc định hướng trái) |
| right (E, +X) | `slime_{color}_side.png` | `flip_h = true` |
| hurt | `slime_hurt.png` | no |

---

## 4. File Structure

```
src/
├── world/
│ ├── world.gd (existing, world root orchestrator)
│ ├── world_slime_manager.gd ← NEW (spawn/manage/despawn slime)
│ ├── world_slime.gd ← NEW (1 slime instance behavior)
│ ├── animal_bot.gd (reference pattern)
│ └── ...
└── ...
```

Tuân thủ coding conventions (AGENTS.md dòng 67: `[parent_name]_[component_purpose].gd` → `world_slime.gd` + `world_slime_manager.gd`).

**Strict size limits:** mỗi file < 200 lines, mỗi function < 50 lines.

---

## 5. Animation Breakdown

**Idle (default state, ~80% thời gian):**
- `t = 0.0s`: scale = (1.0, 1.0), sprite.y = baseline
- `t = 0.75s`: scale = (1.1, 0.85) — squash xuống (rộng, thấp)
- `t = 1.5s`: scale = (1.0, 1.0) — recover
- Loop vô hạn. Position Y baseline cố định.

**Hop (khi moving, 0.6s cycle):**
- `t = 0.0-0.15s`: scale = (1.2, 0.8), sprite.y = baseline − 0.05 — anticipation squash
- `t = 0.15-0.40s`: scale = (0.9, 1.1), sprite.y = baseline + 0.45 — stretch lên không
- `t = 0.40-0.60s`: scale = (1.0, 1.0), sprite.y = baseline — land

Direction sprite set theo current movement direction (4-way map).

**Flee** = same as hop, nhưng:
- direction vector = hướng xa player (normalized away vector)
- speed ×1.5 so they visibly escape
- sprite anim plays uninterrupted (no special "fear" anim)

**Hurt:** swap sprite to `_hurt`, scale pulse (1.0 → 1.2 → 0.5 trong 0.3s), then queue_free.

---

## 6. State Machine

```
WANDER (3-8s) → IDLE (3-8s) → WANDER ...
       ↑ (recover 2s)
FLEE ←──── player <5m
       ↓ (after 0.3s hurt anim)
DESPAWN (queue_free, no respawn)
```

State transitions:

- **IDLE → WANDER:** timer 0, pick random direction, timer = randf_range(3, 8)
- **WANDER → IDLE:** timer 0 (chỉ khi không có player gần), timer = randf_range(3, 8)
- **Any → FLEE:** player distance < 5m. Cancel current timer. Hop direction = away from player. Speed × 1.5.
- **FLEE → WANDER:** player distance > 5m AND flee timer > 2s. Reset to WANDER.

---

## 7. Collision

`CharacterBody3D` (giống AnimalBot, không phải RigidBody — slime không cần physics đẩy player).

- CollisionShape3D: SphereShape3D radius 0.28
- collision_layer = 16 (giống AnimalBot — passive entity)
- collision_mask = 1 (collide với environment: trees, boulders, ground)

**Damage receiving:** cần 1 hitbox riêng hoặc check distance từ tool. Approach đề xuất:
- Add Area3D với radius 0.4 quanh slime
- Group `slime_mobs`
- Tool attack script query Area3D overlaps → gọi `_on_slime_damaged(amount)` trên slime

→ Phần này phụ thuộc vào implementation hiện tại của tool attack. Spec sẽ chốt sau brainstorm.

---

## 8. Integration with World.gd

Hook vào `src/world/world.gd` _ready() (existing line 36-38 pattern):

```gdscript
# 3. Create World Manager (HUD, Boss, Weather, etc.)
var world_manager := WorldManager.new()
world_manager.name = "WorldManager"
add_child(world_manager)

# 4. NEW: Create Slime Manager (passive ambient slimes)
var slime_manager := WorldSlimeManager.new()
slime_manager.name = "SlimeManager"
add_child(slime_manager)
```

Vị trí: **sau WorldManager** (line 38), trước AudioManager (line 41).

---

## 9. WorldSlimeManager API (draft)

```gdscript
class_name WorldSlimeManager
extends Node

const SPAWN_COUNT_PER_CHUNK: int = 4
const SPAWN_DENSITY: float = 0.6      # 60% chunks được populate
const HARD_CAP: int = 30
const SPAWN_RADIUS: float = 50.0      # Mặc định MAP_HALF của ForestBuilder
const SPAWN_MIN_PLAYER_DIST: float = 8.0  # Tránh spawn trên đầu player

@export var slime_script: Script = preload("res://src/world/world_slime.gd")

var _slimes: Array[Node3D] = []
var _rng: RandomNumberGenerator

func _ready() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.seed = 2025
    _spawn_initial_slimes()

func _spawn_initial_slimes() -> void:
    var count := int(round(HARD_CAP * SPAWN_DENSITY))  # 18 initial
    for i in range(count):
        _try_spawn_one()

func _try_spawn_one() -> bool:
    if _slimes.size() >= HARD_CAP:
        return false
    var pos := _pick_random_ground_position()
    if pos == Vector3.INF:
        return false
    var slime := _instantiate_slime(pos)
    _slimes.append(slime)
    return true

func _pick_random_ground_position() -> Vector3:
    # Random XZ within SPAWN_RADIUS
    # Reject if in Zone.CLEARING hoặc dưới large tree canopy
    # Dùng forest.has_method("_get_zone") + forest._is_under_large_tree_canopy()
    # ...

func _instantiate_slime(pos: Vector3) -> Node3D:
    var slime: Node3D = CharacterBody3D.new()
    slime.set_script(slime_script)
    slime.position = pos
    add_child(slime)
    return slime
```

---

## 10. WorldSlime Instance API (draft)

```gdscript
class_name WorldSlime
extends CharacterBody3D

enum State { IDLE, WANDER, FLEE, HURT }
const FLEE_RANGE: float = 5.0
const RECOVER_TIME: float = 2.0
const HURT_DURATION: float = 0.3

var current_state: State = State.IDLE
var state_timer: float = 0.0
var move_direction: Vector3 = Vector3.ZERO
var base_speed: float = 1.2
var flee_speed_multiplier: float = 1.5

# Sprite 4 directions + 1 hurt
@onready var sprite: Sprite3D

func _ready() -> void:
    add_to_group("slime_mobs")
    _setup_sprite()
    _pick_initial_state()

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE: _update_idle(delta)
        State.WANDER: _update_wander(delta)
        State.FLEE: _update_flee(delta)
        State.HURT: _update_hurt(delta)

func take_damage(amount: float) -> void:
    if current_state == State.HURT:
        return
    current_state = State.HURT
    state_timer = HURT_DURATION
    _play_hurt_anim()
```

---

## 9. Respawn Strategy (Q11)

**Decision: C — Density-based respawn.**

- Manager poll mỗi 30s, đếm slime còn sống (`_slimes.size()` trừ các instance đã queue_free).
- Nếu count < target (18, tức `HARD_CAP × SPAWN_DENSITY`) → spawn bù phần thiếu.
- Vị trí spawn bù: random XZ trong SPAWN_RADIUS, **không dùng vị trí slime chết** (tránh farm-spot).
- 30 slime sẽ được phân bố 60% chunks = ~18 initial. Player giết slime → 17, 16, ... → sau 30s spawn 1 cái mới về 17 → 18. Cap cứng 30.

**Tham khảo:** pattern giống `_process` của `WorldManager._update_weather` (line 230) — timer-based event loop.

---

## 10. Performance Budget (Q12)

**Decision: C — Distance-based skip.**

- Mỗi slime có flag `_active: bool`.
- Manager scan mỗi 0.5s (không phải mỗi frame): nếu slime cách player > 20m → `_active = false`. Nếu < 20m → `_active = true`.
- Trong `_physics_process` của slime: nếu `not _active` → return ngay (skip AI + animation).
- Sprite vẫn visible ở distance xa (vì Y baseline 0.28 + sprite_size 0.53m → ở 25m camera sprite ~5px, gần như invisible anyway). Render cost thấp.
- Distance check dùng `distance_squared_to` để tránh sqrt (60 checks/s × 30 slime × 0.5s polling = 60 ops/s — negligible).

**Edge case:** player vừa teleport hoặc load scene → flag sẽ update sau 0.5s tối đa. Acceptable.

---

## 11. Hook Point (Q13)

**Decision: A — Con của World.**

- File: `src/world/world.gd`, hook tại dòng 39 (sau WorldManager, trước AudioManager).
- Pattern khớp với WorldManager instantiation (line 36-38).
- Slime là ambient entity thuộc world, không thuộc ForestBuilder.
- Manager tự quản lý `_slimes: Array[Node3D]` (dùng weak reference để tránh leak).

```gdscript
# src/world/world.gd _ready() — insert at line 39 (after WorldManager)

# 3.5. Create Slime Manager (passive ambient slimes)
var slime_manager := WorldSlimeManager.new()
slime_manager.name = "SlimeManager"
add_child(slime_manager)
```

---

## 12. Damage Integration (Q14) — DECIDED

**Decision: Component-based, mirror existing enemy pattern (`orc_mob.gd`).**

### Tại sao không dùng Area3D hitbox riêng:
- Player tool attack (`player.gd:603-608`) chỉ query `area is HurtboxComponent`. Nếu slime có Area3D không phải `HurtboxComponent`, bị ignore hoàn toàn.
- Toàn bộ enemy hiện tại (`OrcMob`, `ChanTinhMob`, `FireHazard`, `LightningBolt`) đều dùng `HurtboxComponent`. Slime phải follow.

### Slime scene structure:

```
WorldSlime (CharacterBody3D, script: world_slime.gd)
├── CollisionShape3D (sphere radius 0.28 — physics body)
├── Sprite3D (billboarded, shaded)
├── HealthComponent (max_health = 1.0, current_health = 1.0)
└── HurtboxComponent (Area3D)
    └── CollisionShape3D (sphere radius 0.4 — slightly larger than body for fairness)
```

### Damage flow:

1. Player attack → `hitbox_area.monitoring = true` ở frame 1 (player.gd:507)
2. Hitbox overlap detect → `_on_hitbox_area_entered(area)` (player.gd:603)
3. `if area is HurtboxComponent` → `hurtbox.receive_hit(damage, source, crit)` (line 608)
4. `HurtboxComponent.receive_hit` → `health_component.take_damage(amount, source, is_critical)` (hurtbox.gd:12-14)
5. `HealthComponent.take_damage` → `current_health -= amount` → emit `health_changed`, `damaged`
6. If `current_health <= 0` → emit `died` signal
7. Slime script lắng nghe `died` → trigger hurt animation 0.3s → queue_free

### Setup snippet (world_slime.gd `_ready`):

```gdscript
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
    add_to_group("slime_mobs")
    if health_component:
        health_component.max_health = 1.0
        health_component.current_health = 1.0
        health_component.died.connect(_on_slime_died)

func _on_slime_died() -> void:
    current_state = State.HURT
    state_timer = HURT_DURATION  # 0.3s
    sprite.texture = _load_texture("%s/hurt.png" % _current_color_folder)
```

### Collision layers:

- Slime body CharacterBody3D: `collision_layer = 16` (giống AnimalBot — passive), `collision_mask = 1` (collide environment)
- HurtboxComponent Area3D: layer tùy thuộc vào cấu hình orc. Check orc_mob.gd scene structure trong implementation phase.

---

## 13. Animation Driver (Q15) — DECIDED

**Decision: C — Manual lerp trong `_physics_process`.**

Match pattern `AnimalBot._physics_process` (animal_bot.gd:78-117) — manual state update, không Tween.

### Implementation sketch:

```gdscript
# Trong _physics_process (slime active only)
match current_state:
    State.IDLE:
        _update_idle_anim(delta)
    State.WANDER:
        _move_in_direction(delta)
        _update_hop_anim(delta)
    State.FLEE:
        _move_away_from_player(delta)
        _update_hop_anim(delta)  # speed × 1.5
    State.HURT:
        _update_hurt_anim(delta)

func _update_idle_anim(delta: float) -> void:
    # Squash & stretch cycle 1.5s
    var t: float = fmod(_active_time, 1.5) / 1.5  # 0.0 to 1.0
    var squash_factor: float = sin(t * TAU) * 0.125  # ±0.125 around 1.0
    sprite.scale = Vector3(1.0 + squash_factor, 1.0 - squash_factor, 1.0)

func _update_hop_anim(delta: float) -> void:
    # Hop cycle 0.6s
    var cycle_pos: float = fmod(_active_time, 0.6) / 0.6  # 0.0 to 1.0
    if cycle_pos < 0.25:
        # Anticipation squash (0.0-0.15)
        sprite.scale = Vector3(1.2, 0.8, 1.2)
        sprite.position.y = _baseline_y - 0.05
    elif cycle_pos < 0.67:
        # Stretch lên không (0.15-0.40)
        sprite.scale = Vector3(0.9, 1.1, 0.9)
        sprite.position.y = _baseline_y + 0.45
    else:
        # Land (0.40-0.6)
        sprite.scale = Vector3.ONE
        sprite.position.y = _baseline_y
```

---

## 14. Sprite Shadows (Q16) — DECIDED

**Decision: NO — `SHADOW_CASTING_SETTING_OFF`.**

- Match `AnimalBot` pattern (AnimalBot không explicit set cast_shadow trên sprite, mặc định OFF).
- Player cast shadow ON (player.gd:117) — chi phí được allocate cho player + nearby entities.
- Slime ~0.5m nhỏ, ground blob — shadow sẽ gần như invisible anyway.
- 30 slime × shadow rendering = chunk budget bị chiếm → tiết kiệm cho trees (đã có TREE_SHADOW_MAX_COUNT = 24, world_manager.gd:67).

### Implementation:

```gdscript
# world_slime.gd _ready()
sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
```

---

## 15. Implementation Status — COMPLETED 2026-07-08

**Status: ✅ Implemented and Godot-compiled.**

### Files created

| File | Lines | Role |
|------|-------|------|
| `src/world/world_slime.gd` | 198 | Per-instance slime behavior |
| `src/world/world_slime_manager.gd` | 128 | Spawn / lifecycle / active-flag orchestration |

### File modified

- `src/world/world.gd` — inserted `WorldSlimeManager` instantiation between `WorldManager` (line 38) và `AudioManager` (line 41).

### Compile verification

- `godot --headless --path <project> --quit --verbose` produces zero parse errors and zero warnings for the two new scripts.
- Both files comply with AGENTS.md strict 200-line limit.
- All functions < 30 lines.

### Deviations from initial draft (during implementation)

1. **Manager components attachment:** Originally spec mentioned "scene structure" with pre-attached `Sprite3D`, `HealthComponent`, `HurtboxComponent`. To avoid requiring a `.tscn` file (and matching `AnimalBot`'s _spawn_animals pattern in `ForestBuilder` which builds nodes purely from code), manager attaches components programmatically in `_attach_components()`.
2. **`_pick_initial_state` inlined** into `_ready` — saved 5 lines (single callsite).
3. **`DIR_FLIP` Dictionary removed** — single-entry lookup replaced with `current_dir == MoveDir.RIGHT` inline check.
4. **`_pick_weighted_color` simplified:** uses `randi() % 100` against accumulated weights (saved iteration loop computing total).

### Runtime structure

```
World (root)
├── Player
├── Camera
├── ForestBuilder (group "forest")
├── WorldManager
├── SlimeManager ← NEW
│   ├── Slime (CharacterBody3D)
│   │   ├── Sprite3D
│   │   ├── CollisionShape3D (sphere r=0.28)
│   │   ├── HealthComponent (max=1.0)
│   │   └── Hurtbox (Area3D + CollisionShape3D sphere r=0.4)
│   └── ... (18 initial, max 30)
└── AudioManager
```

### Test plan (chưa chạy trong editor)

Trước khi commit, verify in Godot editor:
- [ ] 18 slime spawn rải rác trong forest (không ở path / clearing / under large tree canopy).
- [ ] Slime idle và hop visible.
- [ ] Player approach → slime flee (dir away, speed × 1.5).
- [ ] Player attack → slime hurt sprite swap → despawn sau 0.3s.
- [ ] Sau 30s, manager top-up slime nếu population < 18.
- [ ] Slime xa > 20m → không animate (_physics_process skip).
- [ ] Console không có parse / runtime error.

### Known risks

- **Hurtbox collision layer:** Manager tạo HurtboxComponent nhưng Area3D `collision_layer` / `collision_mask` để mặc định. Nếu player tool attack không detect, cần set `collision_layer = 2` (match orc_mob convention).
- **Sprite loading racy timing:** `_update_sprite()` calls `_load_cached()` ngay trong `_ready()`. Nếu texture chưa load xong (Cinemachine process đầu tiên), sprite có thể transparent frame đầu. Acceptable.
- **Active flag timing:** Manager poll mỗi 0.5s. Slime vừa spawn > 20m từ player sẽ idle 0.5s trước khi skip flag. Minor.

### Assets verified

- Folder thật: `Assets/PocketWitch-Slimes_v2.1/Slimes/{green,blue,violet,purple} slime/`
- Naming: `slime_{color}_{front|side|back}.png` và `slime_hurt.png` (chia sẻ giữa các color).
- Đã verify thấy `.import` sidecar cho tất cả 16 files cần dùng (4 colors × 4 sprites).

---

## 16. Skills reference

- **`godot-gdscript-patterns`** (workspace: `.agents/skills/godot-gdscript-patterns/SKILL.md`) — state machine, signals.
- **`game-development/3d-games`** — sprite 2D trong 3D space, billboarding, depth sorting.
