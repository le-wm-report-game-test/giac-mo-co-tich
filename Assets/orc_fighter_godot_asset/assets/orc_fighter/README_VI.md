# Orc Fighter Godot Asset

Gói này là asset **prototype / low-poly stylized** cho Godot, dùng để test gameplay đánh nhau. Nó không phải model AAA chi tiết y hệt ảnh concept, nhưng đã có file 3D và animation state cơ bản để tích hợp ngay.

## File chính

- `orc_fighter.glb` — model 3D Godot import được, có animation.
- `orc_fighter.gltf` + `orc_fighter.bin` — bản tách file để kiểm tra/chỉnh sửa nếu cần.
- `orc_fighter.tscn` — scene mẫu Godot, đã instance model và gắn script controller.
- `orc_fighter_controller.gd` — script gọi trạng thái animation.
- `orc_fighter_example_usage.gd` — ví dụ gọi animation bằng input.
- `concept_reference.png` — ảnh concept tham khảo.

## Animation state có sẵn

- `idle` — đứng thở/nhấp nhô nhẹ.
- `attack` — vung rìu đánh.
- `hit` — bị đánh, giật lùi.
- `defeated` — hạ gục/ngã xuống.

## Cách tích hợp vào Godot 4.x

1. Copy nguyên thư mục `assets/orc_fighter` vào project Godot của bạn, đúng đường dẫn:

   `res://assets/orc_fighter/`

2. Mở Godot, chờ import `.glb` xong.

3. Kéo scene `res://assets/orc_fighter/orc_fighter.tscn` vào map/gameplay scene.

4. Gọi animation bằng script:

```gdscript
@onready var orc: OrcFighter = $OrcFighter

func _ready():
    orc.idle()

func do_attack():
    orc.attack()

func take_damage():
    orc.hit()

func die():
    orc.defeated()
```

## Ghi chú quan trọng

- Đây là model được dựng bằng node/mesh đơn giản, chưa có skeleton bone chuyên nghiệp.
- Animation được làm bằng transform của từng bộ phận, đủ dùng để prototype combat.
- Khi làm bản chính thức, nên thuê/triển khai pipeline Blender: retopology, rig humanoid, skin weight, texture PBR, animation frame chuẩn.
- Có thể thay model sau này nhưng giữ nguyên tên animation: `idle`, `attack`, `hit`, `defeated` để code gameplay không cần đổi nhiều.
