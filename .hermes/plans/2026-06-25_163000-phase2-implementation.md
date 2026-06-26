# GiacMoCoTich — Implementation Plan (Phase 2)

> **Goal:** Hoàn thiện game GiacMoCoTich với boss Chằn Tinh, collision, âm thanh, animation, và các tính năng còn lại.

**Architecture:** Godot 4.6, GDScript, 3D isometric với orthographic camera, sprite-based characters.

**Tech Stack:** Godot 4.6, GDScript, GPUParticles3D, Jolt Physics

---

## Công việc còn lại

### Task 1: Kiểm tra & fix collision đá to chặn người

**Objective:** Đảm bảo các tảng đá lớn trong rừng có collision shape chặn player và monster.

**Files:**
- Modify: `src/world/forest_builder.gd`
- Verify: `src/player/player.tscn` (collision layer/mask)

**Phân tích:**
Forest builder tạo đá (`LargeRock_01` đến `LargeRock_04`) từ `Stylized Nature MegaKit`. Các mesh này có thể đã có collision body hoặc chưa. Cần kiểm tra và thêm `StaticBody3D` + `CollisionShape3D` nếu thiếu.

**Cách fix:**
Trong `forest_builder.gd`, sau khi instantiate rock mesh, kiểm tra xem có `StaticBody3D` không. Nếu không, wrap mesh trong `StaticBody3D` với `CollisionShape3D` dùng `ConcavePolygonShape3D` từ mesh data.

**Step 1: Đọc forest_builder.gd phần spawn rock**

```bash
grep -n "rock\|Rock\|LargeRock\|StaticBody" src/world/forest_builder.gd
```

**Step 2: Thêm collision cho rock**

Trong hàm spawn rock, thêm đoạn code:
```gdscript
# Ensure rock has collision
if not rock_node is StaticBody3D:
    var static_body := StaticBody3D.new()
    static_body.name = rock_node.name + "_Collision"
    rock_node.reparent(static_body)
    static_body.add_child(rock_node)
    var col_shape := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    # Get mesh data
    var mesh_instance := rock_node as MeshInstance3D
    if mesh_instance and mesh_instance.mesh:
        shape.set_faces(mesh_instance.mesh.get_faces())
    col_shape.shape = shape
    static_body.add_child(col_shape)
    add_child(static_body)
```

**Step 3: Verify player collision layers**

Player: collision_layer=2, collision_mask=7 (includes layer 1 = terrain)
Đá nên ở collision_layer=1 (terrain) để player mask 7 chặn được.

---

### Task 2: Fix animation animal không mượt

**Objective:** Animation animal (cat, rabbit, parrot) chạy mượt mà hơn, không giật.

**Files:**
- Modify: `src/world/animal_bot.gd`

**Phân tích:**
Hiện tại `anim_fps = 6.0` và frame timer dùng delta tích lũy. Vấn đề có thể do:
1. FPS quá thấp
2. Frame transition không smooth
3. Sprite texture load lại mỗi frame gây lag

**Fix:**
1. Tăng anim_fps lên 8.0
2. Thêm interpolation giữa các frame
3. Cache texture để tránh load lại mỗi frame

**Step 1: Sửa animal_bot.gd**

```gdscript
# Increase FPS
var anim_fps: float = 8.0

# Cache loaded textures
var texture_cache: Dictionary = {}

func _update_sprite_texture() -> void:
    if sprite == null:
        return
    
    var anim_frame := current_frame
    if anim_frame == 3:
        anim_frame = 1
    
    var path := _get_texture_path()
    if path.is_empty():
        return
    
    # Use cached texture
    if not texture_cache.has(path):
        if ResourceLoader.exists(path):
            texture_cache[path] = load(path)
    
    if texture_cache.has(path):
        sprite.texture = texture_cache[path]
```

---

### Task 3: Âm thanh cho game objects

**Objective:** Thêm âm thanh cho player attack, monster hurt, monster death, ambient forest.

**Files:**
- Create: `src/systems/audio_manager.gd`
- Modify: `src/world/world.gd` (add AudioManager)
- Modify: `src/player/player.gd` (play attack sound)
- Modify: `src/world/orc_mob.gd` (play hurt/death sound)

**Cách làm:**
Dùng `AudioStreamPlayer2D` (hoặc 3D) với âm thanh tự tạo procedural (không cần file external):
- Attack: short burst sine wave
- Hurt: low frequency thud
- Death: descending tone
- Ambient: low forest hum

**Step 1: Tạo AudioManager**

```gdscript
# audio_manager.gd
class_name AudioManager
extends Node

func play_sfx(sound_name: String, position: Vector3 = Vector3.ZERO) -> void:
    var player := AudioStreamPlayer3D.new()
    player.stream = _generate_sound(sound_name)
    player.global_position = position
    add_child(player)
    player.play()
    await player.finished
    player.queue_free()

func _generate_sound(name: String) -> AudioStreamWAV:
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = 22050
    
    var samples := PackedInt16Array()
    var duration := 0.2
    var sample_count := int(22050 * duration)
    
    match name:
        "attack_swing":
            # Rising frequency sweep
            for i in sample_count:
                var t := float(i) / sample_count
                var freq := 200.0 + t * 800.0
                var val := sin(2.0 * PI * freq * t * duration) * 0.3 * (1.0 - t)
                samples.append(int(val * 32767))
        "hit":
            # Low thud
            for i in sample_count:
                var t := float(i) / sample_count
                var val := sin(2.0 * PI * 80.0 * t * duration) * 0.5 * exp(-t * 10.0)
                samples.append(int(val * 32767))
        "death":
            # Descending tone
            for i in sample_count:
                var t := float(i) / sample_count
                var freq := 300.0 * (1.0 - t * 0.8)
                var val := sin(2.0 * PI * freq * t * duration) * 0.4 * (1.0 - t)
                samples.append(int(val * 32767))
    
    wav.data = samples.to_byte_array()
    return wav
```

**Step 2: Tích hợp vào player.gd**

Trong `_start_attack()`:
```gdscript
# Play attack sound
var audio := get_node("/root/World/WorldManager/AudioManager") as AudioManager
if audio:
    audio.play_sfx("attack_swing", global_position)
```

**Step 3: Tích hợp vào orc_mob.gd**

Trong `_on_damaged()`:
```gdscript
var audio := get_node("/root/World/WorldManager/AudioManager") as AudioManager
if audio:
    audio.play_sfx("hit", global_position)
```

Trong `_on_died()`:
```gdscript
var audio := get_node("/root/World/WorldManager/AudioManager") as AudioManager
if audio:
    audio.play_sfx("death", global_position)
```

---

## Verification Plan

1. **Collision đá:** Tạo player chạy vào đá → bị chặn lại
2. **Animation animal:** Quan sát animal di chuyển mượt, không giật
3. **Âm thanh:** Attack → nghe tiếng vung rìu, monster bị đánh → tiếng thụt, monster chết → tiếng rên
4. **Boss:** Diệt 5 orc → boss xuất hiện, có thanh máu boss
5. **Weather:** Đợi 5 phút → mưa, sau 3 lần mưa → bão có sấm sét
6. **Damage numbers:** Đánh monster → số damage bay lên, 15% crit → chữ to màu vàng

---

## Risks & Notes

- Collision đá: Nếu dùng `ConcavePolygonShape3D` quá nặng, có thể dùng `BoxShape3D` đơn giản hơn
- Âm thanh procedural: Chất lượng thấp hơn file audio thật, nhưng không cần download
- Boss spawn: Cần đảm bảo boss không spawn chồng lên cây/đá
- Weather: GPUParticles3D có thể ảnh hưởng performance trên máy yếu
