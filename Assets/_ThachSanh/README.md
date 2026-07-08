# Thach Sanh (Thạch Sanh) — Sprite Asset Mapping Guide

This directory contains segmented, transparent 2.5D top-down sprite assets for the character **Thạch Sanh**.
Use this guide to map animation states and frame sequences in Godot (e.g., `Sprite3D`, `AnimatedSprite3D`, or `AnimationPlayer`).

---

## 📂 Directory Structure

All files follow the naming convention: `./[action]/[direction]_[action]_[frame].png`
Where `[direction]` is one of: `down`, `up`, `right`, `left`, `down_right`, `down_left`, `up_right`, `up_left`

```
thach_sanh_assets/
├── README.md               # This mapping guide
├── idle/                   # Breathing animations (2 frames per direction)
├── run/                    # Movement loop (3 frames per direction)
├── attack/                 # Melee attack animations with stone axe (2 frames per direction)
└── hurt/                   # Impact/damage reaction (1 frame per direction)
```

---

## 🎭 State Machine & Animation Mapping

### 1. IDLE STATE (Animation: `idle`)
*   **Description:** Breathing loop while standing still holding stone axe.
*   **Frame Count:** 2 frames per direction.
*   **Framerate:** 5.0 FPS (recommended).
*   **Mapping:**
    *   Down: `./idle/down_idle_0.png` to `./idle/down_idle_1.png`
    *   Up: `./idle/up_idle_0.png` to `./idle/up_idle_1.png`
    *   Right: `./idle/right_idle_0.png` to `./idle/right_idle_1.png`
    *   Left: `./idle/left_idle_0.png` to `./idle/left_idle_1.png`
    *   Down-Right: `./idle/down_right_idle_0.png` to `./idle/down_right_idle_1.png`
    *   Down-Left: `./idle/down_left_idle_0.png` to `./idle/down_left_idle_1.png`
    *   Up-Right: `./idle/up_right_idle_0.png` to `./idle/up_right_idle_1.png`
    *   Up-Left: `./idle/up_left_idle_0.png` to `./idle/up_left_idle_1.png`

### 2. RUN STATE (Animation: `run` / `walk`)
*   **Description:** Running loop animation.
*   **Frame Count:** 3 frames per direction.
*   **Framerate:** 8.0 FPS (recommended).
*   **Mapping:**
    *   Down: `./run/down_run_0.png` to `./run/down_run_2.png`
    *   Up: `./run/up_run_0.png` to `./run/up_run_2.png`
    *   Right: `./run/right_run_0.png` to `./run/right_run_2.png`
    *   Left: `./run/left_run_0.png` to `./run/left_run_2.png`
    *   Down-Right: `./run/down_right_run_0.png` to `./run/down_right_run_2.png`
    *   Down-Left: `./run/down_left_run_0.png` to `./run/down_left_run_2.png`
    *   Up-Right: `./run/up_right_run_0.png` to `./run/up_right_run_2.png`
    *   Up-Left: `./run/up_left_run_0.png` to `./run/up_left_run_2.png`

### 3. ATTACK STATE (Animation: `attack`)
*   **Description:** Heavy axe swinging action (Attack phase).
*   **Frame Count:** 2 frames per direction.
*   **Framerate:** 10.0 FPS (recommended).
*   **Hitbox Trigger:** Trigger hitbox monitoring on **Frame 0** or **Frame 1** depending on animation speed.
*   **Mapping:**
    *   Down: `./attack/down_attack_0.png` to `./attack/down_attack_1.png`
    *   Up: `./attack/up_attack_0.png` to `./attack/up_attack_1.png`
    *   Right: `./attack/right_attack_0.png` to `./attack/right_attack_1.png`
    *   Left: `./attack/left_attack_0.png` to `./attack/left_attack_1.png`
    *   Down-Right: `./attack/down_right_attack_0.png` to `./attack/down_right_attack_1.png`
    *   Down-Left: `./attack/down_left_attack_0.png` to `./attack/down_left_attack_1.png`
    *   Up-Right: `./attack/up_right_attack_0.png` to `./attack/up_right_attack_1.png`
    *   Up-Left: `./attack/up_left_attack_0.png` to `./attack/up_left_attack_1.png`

### 4. HURT STATE (Animation: `hurt`)
*   **Description:** Brief visual feedback when taking damage.
*   **Frame Count:** 1 frame per direction (static hit pose).
*   **Duration:** 0.3s (recommended transition back to idle).
*   **Mapping:**
    *   Down: `./hurt/down_hurt_0.png`
    *   Up: `./hurt/up_hurt_0.png`
    *   Right: `./hurt/right_hurt_0.png`
    *   Left: `./hurt/left_hurt_0.png`
    *   Down-Right: `./hurt/down_right_hurt_0.png`
    *   Down-Left: `./hurt/down_left_hurt_0.png`
    *   Up-Right: `./hurt/up_right_hurt_0.png`
    *   Up-Left: `./hurt/up_left_hurt_0.png`
