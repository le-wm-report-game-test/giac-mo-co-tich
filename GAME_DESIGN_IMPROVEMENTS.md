# Game Design Review — Giac Mo Co Tich

Audit performed with the `game-designer` skill's lens (atmosphere, juice, particles,
transitions, viral first-impression), adapted from its Phaser/Three.js default to this
project's actual stack: **Godot 4.7, 3D, billboard 2D sprites, Terrain3D-style modular
forest**. Concepts are translated, not copy-pasted — there is no `Constants.js`/`EventBus.js`
here, the equivalents are `EventBus` (`src/common/event_bus.gd`) and per-system constants at
the top of each script.

This audit is scoped to **game feel, atmosphere, and spectacle** — not UI chrome/typography,
which `UI_REVIEW_CURRENT.md` already tracks in detail (menu/dialog visual language, minimap
icons, settings grouping). Where the two overlap, this doc points at the existing entry
instead of repeating it.

## Score Table

| Area | Score /5 | Notes |
|---|---|---|
| Background & Atmosphere | 4 | Procedural weather (`lighting_director.gd`) with clear/rain/storm profiles, dynamic sky, fog, SSAO, volumetric fog. Genuinely cinematic for a student project. |
| Color Palette | 4 | `ui_theme.gd` gold/forest palette is cohesive for UI; lighting profiles give weather-appropriate grading. Combat-side color language (damage popups, telegraphs) is well chosen. |
| Animations & Tweens | 4 | Extensive use of `Tween` with proper easing (`DamagePopup`, `VictoryDialog`, `DeathDialog`, main menu hover). |
| Particle Effects | 3 | Dust trail, footprints, rain, lightning, pickup burst all exist — but **combat itself has zero particles** (no hit spark, no blood/impact FX, no death burst). |
| Screen Transitions | 3 | Scene changes go through a real `LoadingScreen` with async load + rotating lore tips — better than most student projects. Missing: transition *into* combat moments (boss intro, hit reactions). |
| Typography | 4 (tracked in `UI_REVIEW_CURRENT.md`) | Not re-audited here. |
| Game Feel / Juice | **2** | This is the single biggest gap — see "Combat Juice" below. Camera shake is fully implemented and *never called*. |
| Game Over / Victory | 4 | `DeathDialog`/`VictoryDialog` already have fade+scale+stagger tweens, chime SFX, contextual copy tied to the "Thạch Sanh" story. |
| Entity Prominence | 4 | Player/boss are readable; boss uses an oversized tint (`BOSS_SPRITE_TINT`) and its own health bar. |
| First Impression / Viral Appeal | **2** | No entrance flash, no ambient motion before input, camera does a nice zoom-in intro but nothing *happens* on screen during it. |
| Thematic Identity | 5 | This is the project's strength: real Vietnamese folklore ("Thạch Sanh" vs "Chằn Tinh"), Vietnamese UI copy, forest/village aesthetic carried consistently through victory/death text. Don't touch this — protect it. |
| Expression/Reactivity | N/A | No personality-character system in this game (not applicable — skip). |

**Two areas fall below the skill's "must fix" threshold of 4: Game Feel / Juice, and First
Impression / Viral Appeal.** Both point at the same root cause: this game has all the
*infrastructure* for juice (camera shake API, EventBus signals for every combat event,
particle systems elsewhere in the world) but combat itself doesn't consume any of it.

## 1. Combat has no hit feedback — the highest-impact fix available

Grep across `src/` confirms:

- `GameCamera.shake(duration, amplitude)` is fully implemented (`src/camera/game_camera.gd:198`)
  — PhantomCamera noise + trauma decay tween, ready to use — **but it is never called from
  anywhere in the codebase.** Every hit, every crit, every boss slam currently produces zero
  camera feedback.
- There is no hit-flash (sprite `modulate` flash to white/red) anywhere in `player.gd`,
  `orc_mob.gd`, or `orc_boss_mob.gd` when `_on_damaged`/`hurtbox` fires.
- There is no hit-freeze / time-scale dip on impact (`Engine.time_scale` is only touched in
  `base_test_case.gd`, never in gameplay).
- `EventBus` already emits everything needed to wire this for free:
  `enemy_damaged(enemy, amount, position, is_critical)`, `player_took_damage(amount, position)`,
  `boss_spawned(boss)`, `enemy_died(enemy)` — no new signals required.

**Suggested fix** (small, additive, doesn't touch combat/physics logic — respects the "When
NOT to Change" rule): in whatever node currently listens to these signals for audio/HUD
(`AudioManager`, `HUDManager`), add a sibling reaction:

```gdscript
# on EventBus.enemy_damaged / player_took_damage
var camera := get_tree().get_first_node_in_group("camera") as GameCamera
if camera:
    camera.shake(0.12, is_critical ? 6.0 : 3.0)
```

```gdscript
# sprite flash on hurtbox receive_hit / player _on_damaged
sprite.modulate = Color(3.0, 3.0, 3.0)  # overbright flash
create_tween().tween_property(sprite, "modulate", base_modulate, 0.12)
```

Boss hits deserve a stronger shake (`camera.shake(0.2, 10.0)` on `boss_spawned`, tied to the
existing `thunder`/`boss_roar` SFX in `audio_manager.gd:159`) — the roar already plays, the
screen just doesn't react to it.

## 2. No impact particles on combat hits

`food_item.gd:129` (`_play_pickup_effect`) proves the pattern already exists in this codebase
— a one-shot `CPUParticles3D` burst with a color gradient, auto-freed after 0.5s. Combat has
nothing equivalent:

- No spark/slash burst on `HurtboxComponent.receive_hit` (`src/components/hurtbox_component.gd:12`).
- No death burst when `HealthComponent.died` fires for orcs/boss (compare to how tidy the
  pickup burst is — this is a copy-paste-and-retint job, not new infrastructure).
- `AttackTelegraph` (`src/world/attack_telegraph.gd`) is genuinely well-built (pulsing ring,
  proper `E2` design-rule compliance) but the *resolution* of the telegraphed attack — the
  moment the AoE actually lands — has no burst/flash to punctuate it. Right now a telegraphed
  attack fades from "warning ring" straight to "damage number," with nothing marking the
  actual impact frame.

## 3. First 3 seconds: intro has motion but no event

`GameCamera.play_startup_intro()` (`src/camera/game_camera.gd:118`) does a genuine
close-zoom → hold → zoom-out, which is good bones for a viral-clip opening. But nothing
happens *during* it:

- No entrance flash (`cameras.main.flash`-equivalent: fade a full-screen `ColorRect` from
  white, cheap and already patterned in `world_weather_manager.gd:87` `trigger_screen_flash`).
- Player sprite just appears already standing — no slam-in/pop-in.
- Ambient particles (dust motes, pollen, forest atmosphere) are absent; the world is
  beautifully lit but static in frame 1. `MovementDustTrail` only fires on footsteps
  (`player.gd:445` `_handle_footprints`), so a standing/idle player produces zero motion.

A cheap, high-leverage addition: reuse `trigger_screen_flash` at world load, and spawn a
few looping ambient `CPUParticles3D` (pollen/dust motes drifting in the spawn clearing) —
same pattern as the rain emitter (`src/world/components/world_rain_emitter.gd`) but always-on
at low density instead of weather-gated.

## 4. Weather/lighting system is under-leveraged as a spectacle tool

`LightingDirector` (`src/lighting/lighting_director.gd`) is the most sophisticated system in
the codebase — three full `LightingProfile` presets, tweened transitions on every environment
property, navigation accent lights that reposition toward the active objective
(`_refresh_navigation_lights`, line 290). This is a strong foundation nobody outside the code
would notice, because:

- Weather transitions are gated behind a slow real-time clock (`weather_timer = 300.0`
  seconds in `world_weather_manager.gd:63`) — a 13-second promo clip will almost certainly
  never see a rain/storm transition.
- `strike_lightning()` (`world_weather_manager.gd:79`) already has a nice bias toward
  striking near the player (15% chance) — but the payoff (`LightningBolt`,
  `trigger_screen_flash`) isn't synced to a camera shake, so a lightning strike feels louder
  in audio than on screen.

Suggestion: add a debug/dev fast-forward for weather cycling during a capture session isn't
required for the game itself, but pairing `strike_lightning()` with a small `camera.shake`
would make existing storms hit harder for free.

## 5. Boss encounter framing — good bones, missing punctuation

`GameCamera.activate_magnet()`/`deactivate_magnet()` (game_camera.gd:175) already re-frames
the camera for boss arenas via a dedicated `PhantomCamera3D` with a 2s cubic tween — this is
exactly the kind of "arena reveal" moment the skill's spectacle philosophy asks for. It's
just missing the punctuation that would sell it:

- No screen flash / shake on `boss_spawned` (see §1) to mark the moment the magnet camera
  engages.
- `BossHealthBar` (`src/ui/boss_health_bar.gd`) fades in instantly on `attach()` (no `show()`
  animation) — contrast with how much care went into `DeathDialog`/`VictoryDialog` fade-ins.
  A quick slide-down + scale-in on `attach()` (mirroring the existing `_on_boss_died` fade-out
  tween at line 147) would match the polish level already set elsewhere in the same file.

## 6. Minor / cheap wins

- `player.gd` invulnerability blink (`sprite.modulate.a = 0.5` toggle, line 354) is a fine
  i-frame indicator but reads as "half transparent," not "just got hit" — a brief red tint
  pass before the blink starts would separate "I'm invulnerable" from "I got hit" as distinct
  readable signals.
- `Minimap` marker shapes (diamond orc / horned boss / diamond item, `src/ui/minimap.gd`) are
  already a nice bit of iconography — worth the same treatment on the boss health bar name
  plate (a small horn/motif next to "Chằn Tinh" per `UI_REVIEW_CURRENT.md` priority 2 item).
- `AudioManager` boosts SFX/footstep volume well above 0dB (`+8dB`, `+13dB` — audio_manager.gd
  lines 62, 86) to compensate for something upstream being quiet; if that's compensating for
  the missing visual feedback above, fixing the visual side may let those gain boosts come
  back down instead of relying on loudness alone to sell impact.

## Suggested order of work

1. Wire `GameCamera.shake()` to `enemy_damaged` / `player_took_damage` / `boss_spawned` —
   the single highest ratio of impact to effort; the API already exists.
2. Add a hit-flash tween to hurtbox/player damage handlers.
3. Port `FoodItem._play_pickup_effect`'s particle pattern to enemy hits and enemy deaths.
4. Give `BossHealthBar.attach()` an entrance tween to match its own exit tween.
5. Add an entrance flash + idle ambient particles to the world/spawn intro.
6. (Lower priority, larger scope) Make weather cycle fast enough to matter for a short
   capture, or expose a manual trigger for demo purposes.

None of the above touch physics, collision, scoring, spawn timing, or input handling —
all are additive juice layered onto systems that already exist and already emit the right
events.
