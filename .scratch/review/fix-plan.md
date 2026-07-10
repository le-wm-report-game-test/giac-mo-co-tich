# Combat & World Plan — Critical Fixes

> Built from 3-reviewer audit. Recalibrated against `combat-design-rules` (game intentionally has no dash/dodge; uses 3-phase attack + IASA + telegraph instead).

> **STATUS (2026-07-09): All critical issues closed.** Phase 0–3 complete and committed. Phase 1.6 (split player.gd) and the pre-existing slime regression remain as low-priority follow-ups.

---

## Scope (đã xác nhận)

| ID | Vấn đề | Fix scope | Approach đã chọn |
|---|---|---|---|
| **C1** | Boss health bar no-op | UI mới | Top-screen bar (`CenterContainer`) |
| **C3** | Enemy telegraph thiếu | Boss + Orc thường | Component mới `attack_telegraph.gd` |
| **C4** | `_spawn_boss` bypass class | Refactor | `OrcBossMob.new() + configure_arena()` |
| **C5** | Player interrupt-on-hit | `player.gd` chỉnh penalty | Damage-per-frame tăng khi attack |
| **C6** | Map walls missing | Thêm boundary | Invisible walls quanh `MAP_HALF = 50` |
| **C7** | Boss arena enclosure | Thêm boulders ring | Stone-ring dùng existing rock asset |
| **NEW-P2** | IASA / Input buffer | Player + Boss + Orc + Chằn Tinh | Attack-only IASA + movement cancel ở Recovery |
| **NEW-S1** | 3-phase Attack structure | 4 files (Player/Orc/Boss/Chằn Tinh) | `AttackPhase` enum + state split |

---

## Priority order (Phase 0 → Phase 4)

### **Phase 0 — Quick wins (½ ngày, no-risk)**

1. **C1 Boss Health Bar** — tạo `src/ui/boss_health_bar.gd` + `boss_health_bar.tscn`
   - `CenterContainer` trong `UI` CanvasLayer (layer=11, trên HUD)
   - `TextureProgressBar` với 2 texture (background + fill)
   - `connect(boss.health_component.health_changed, _update)` + `connect(boss.died, queue_free)`
   - Trong `world_manager._spawn_boss`: tạo BossHealthBar, gọi `attach(boss)`, store ref
   - Trong `world_manager._on_enemy_died` (khi boss chết): tween alpha về 0 + queue_free
   - **Verify**: spawn boss → bar hiện trên top → nhận damage → fill giảm → boss chết → bar fade out

### **Phase 1 — Core mechanics (3–4 ngày)**

2. **3-phase Attack structure (S1)** — áp dụng cho Player + Orc + Boss + Chằn Tinh

   **Pattern** (theo `combat-design-rules/SKILL.md`):
   ```gdscript
   enum AttackPhase { ANTICIPATION, ATTACK, RECOVERY }
   @export var anticipation_ratio: float = 0.30
   @export var attack_ratio: float = 0.10
   @export var recovery_ratio: float = 0.35
   var attack_phase: AttackPhase = AttackPhase.ANTICIPATION
   ```

   Per-file changes:
   - `src/player/player.gd`: extend `AnimState` enum với `DASH, BLOCK` nếu cần; implement AttackPhase sub-state bên trong ATTACK state; hitbox chỉ ON ở `AttackPhase.ATTACK`; recovery window mở movement + buffered-attack
   - `src/world/orc_mob.gd`: thêm `attack_phase` sub-state; telegraph spawn ở ANTICIPATION, hitbox ON ở ATTACK (chỉ 1 frame), recovery = 0.35*duration
   - `src/world/orc_boss_mob.gd`: same pattern, áp dụng `E3 boss_cooldown_multiplier = 1.5`
   - `src/world/chan_tinh_mob.gd`: same pattern
   - **Verify**: từng enemy attack có 3 phase rõ ràng, hitbox key vào frame ATTACK đúng 1 frame

3. **Input Buffer + IASA (P2)** — chỉ cho attack chain + cancel-to-movement

   - Trong `player.gd`:
     ```gdscript
     var _buffered_attack: bool = false
     const BUFFER_WINDOW_SEC: float = 0.15
     ```
   - Trong `_input`: nếu đang locked phase (Anticipation/Attack) mà `event.is_action_pressed("attack")` → set `_buffered_attack = true`
   - Trong `_physics_process`: nếu `attack_phase == AttackPhase.RECOVERY`:
     - Nếu có movement input → cancel-to-idle (IASA)
     - Nếu `_buffered_attack` → bắt đầu attack mới ngay (consume buffer)
   - Verify: tap attack ngay cuối recovery → attack mới fire tức thì, không chờ cooldown

4. **C5 Player interrupt penalty** — damage +50% khi đang ATTACK

   - Trong `player.gd._on_damaged`:
     ```gdscript
     var was_attacking := anim_state == AnimState.ATTACK
     if was_attacking:
         amount *= 1.5  # punish commit-on-hit
     ```
   - Verify: player attack → bị enemy hit → nhận damage gấp 1.5; không attack → damage gốc
   - Lưu ý: phải log/ghi rõ trong code để balance team biết tại sao nhân 1.5

### **Phase 2 — Telegraph component + Map enclosure (2 ngày)**

5. **AttackTelegraph component**

   - Tạo `src/world/attack_telegraph.gd` (extends `MeshInstance3D` hoặc composite node)
   - `static func build_circle(center: Vector3, radius: float, color: Color, duration: float) -> Node3D`
   - Pattern: low-poly disc mesh flat trên mặt đất, animate alpha 0.3 → 0.7
   - Auto-free sau `duration`
   - Dùng cho **AoE un-dodgeable attacks** (E2)

   Wiring per enemy:
   - `orc_mob.gd`: ở ANTICIPATION phase entry, telegraph radius = `attack_range * 1.2`, color = red, duration = anticipation phase length
   - `orc_boss_mob.gd`: same, radius lớn hơn (`attack_range * 1.5`)
   - **Verify**: telegraph xuất hiện đỏ trên đất trước khi hitbox bật, biến mất sau hit

6. **C6 Map walls**
   - Trong `forest_builder._ready`, sau khi spawn terrain:
     ```gdscript
     for boundary in [
         {"pos": Vector3(0, 0, -50), "size": Vector3(100, 6, 1)},
         {"pos": Vector3(0, 0, 50),  "size": Vector3(100, 6, 1)},
         {"pos": Vector3(-50, 0, 0), "size": Vector3(1, 6, 100)},
         {"pos": Vector3(50, 0, 0),  "size": Vector3(1, 6, 100)},
     ]:
         var body := StaticBody3D.new()
         body.position = boundary["pos"]
         var col := CollisionShape3D.new()
         col.shape = BoxShape3D.new()
         col.shape.size = boundary["size"]
         body.add_child(col)
         add_child(body)
     ```
   - Walls outside cull range (visually invisible — không cần mesh)

7. **C7 Boss arena enclosure** — dùng boulder lớn ring
   - Trong `forest_builder._scatter_boulders()`, thêm 8 boulder positions đặt thành vòng tròn quanh `BOSS_ARENA_CENTER = (-15, -15)`, radius 9m
   - Scale boulder to 2.5–3.0 (large blocking)
   - Verify: player không chạy qua boulder arena, vào arena = camera magnet fire (đã có)

### **Phase 3 — Class refactor (1 ngày)**

8. **C4 `_spawn_boss` class fix**
   - Refactor:
     ```gdscript
     func _spawn_boss() -> void:
         if boss_spawned: return
         boss_spawned = true

         var boss := OrcBossMob.new()
         boss.name = "BossChằnTinh"
         boss.configure_arena(Vector3(-15.0, 0.2, -15.0))
         get_parent().add_child(boss)

         boss_instance = boss
         _show_boss_health_bar(boss)
         _activate_camera_magnet(Vector3(-15.0, 0.0, -15.0), 25.0, 8.0)

         EventBus.boss_spawned.emit(boss)
     ```
   - Trong `orc_boss_mob.gd`: thêm method `configure_arena(pos: Vector3)` set `position = pos`, `boss_arena_*` stats, đăng ký group
   - Xoá tất cả `boss.set(...)` ad-hoc → thay bằng typed assignment
   - Verify: spawn boss → bar hiện (Phase 0) + camera magnet cut + scene tree clean

### **Phase 4 — Polish & verify (½ ngày)**

9. **Full system check**
   - Chạy `tests/test_runner.gd` headless, đảm bảo không regress test nào
   - Visual QA: chạy game, test từng boss, đảm bảo telegraph hiển thị rõ
   - README + CHANGELOG update

---

## File-level impact

| File | Action | Lines (est.) |
|---|---|---|
| `src/ui/boss_health_bar.gd` | NEW | ~80 |
| `src/ui/boss_health_bar.tscn` | NEW | ~20 |
| `src/world/attack_telegraph.gd` | NEW | ~120 |
| `src/world/orc_boss_mob.gd` | EDIT (configure_arena method) | +20 |
| `src/player/player.gd` | EDIT (3-phase + IASA + interrupt penalty) | +60, refactor ~ -40 (split helpers) |
| `src/world/orc_mob.gd` | EDIT (3-phase + telegraph) | +40 |
| `src/world/chan_tinh_mob.gd` | EDIT (3-phase) | +40 |
| `src/world/world_manager.gd` | EDIT (spawn refactor + wire boss_health_bar) | -50 (clean up _show/_hide stubs) |
| `src/world/forest_builder.gd` | EDIT (map walls + boss arena boulders) | +50 |

**Total**: 7 files mới/sửa, ~350 LOC delta.

---

## Estimate

| Phase | Effort | Cumulative |
|---|---|---|
| Phase 0 (C1 Boss bar) | ½ ngày | 0.5 |
| Phase 1 (3-phase + IASA + C5 penalty) | 3–4 ngày | 4.0 |
| Phase 2 (Telegraph + Walls + Arena) | 2 ngày | 6.0 |
| Phase 3 (C4 class refactor) | 1 ngày | 7.0 |
| Phase 4 (Verify) | ½ ngày | 7.5 |

**Total: ~7.5 ngày làm việc** (1.5 sprint).

---

## Risk register

| Risk | Mitigation |
|---|---|
| Player refactor (S1 + IASA + C5) chạm critical logic | Wrap trong feature flag `_combat_v2_enabled = true` ở `project.godot`; nếu regression → fallback `_combat_v2_enabled = false` dùng code path cũ |
| Orc telegraph có thể giảm FPS (24 orc × telegraph mesh) | Dùng MeshInstance3D share material; pool telegraph nodes |
| Boss arena boulders che camera | Test FOV/distance, giảm scale nếu cần |
| ChanTinhMob extends OrcMob đụng code OrcBossMob mới | Phase 3 chỉ đụng `world_manager._spawn_boss` + `orc_boss_mob.gd`, không đụng `chan_tinh_mob.gd` |

---

| Phase | Status | Commit | Critical closed |
|---|---|---|---|
| Plan + Grill | ✅ done | — | — |
| Phase 0 (C1 Boss Health Bar) | ✅ committed | `7388570` | C1 |
| Phase 1 (Player Combat V2) | ✅ committed | `7b5d617` | C5, IASA, 3-phase player |
| Phase 1.5 (Enemy Combat V2) | ✅ committed | `70af739` | 3-phase Orc/Boss/ChanTinh |
| Self-review fixes | ✅ committed | `a43ea70` | S1+E2 ratio compliance |
| Phase 2 (Telegraph + Walls + Arena) | ✅ committed | `c08984d` | C3, C6, C7 |
| Phase 3 (Boss class refactor) | ✅ committed | `3d94a6c` | C4 |
| Phase 1.6 (split player.gd 720 lines) | ⏳ pending | — | — |
| Fix slime regression (`world_slime_manager.gd:166`) | ⏳ pending | — | pre-existing, not critical |

## Critical review issues closed: 7/7 + 2 NEW

- ✅ C1 Boss Health Bar — Phase 0
- ✅ C3 Enemy Telegraph — Phase 2
- ✅ C4 `_spawn_boss` class refactor — Phase 3
- ✅ C5 Player interrupt penalty 1.5x — Phase 1
- ✅ C6 Map walls — Phase 2
- ✅ C7 Boss arena enclosure — Phase 2
- ✅ C2 (Dash) — confirmed NOT a gap (game intentionally has no dash per `combat-design-rules`)
- ✅ NEW-P2 IASA + input buffer — Phase 1
- ✅ NEW-S1 3-phase attack structure — Phase 1 + 1.5
