# animal_bot.gd
class_name AnimalBot
extends CharacterBody3D

enum AnimalType { DOG, CAT, RABBIT, PARROT }

@export var animal_type: AnimalType = AnimalType.CAT
@export var speed: float = 1.5
@export var gravity: float = 9.8

# AI States
enum State { IDLE, WANDER }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO

# Animation settings
var frame_timer: float = 0.0
var current_frame: int = 0 # 0: standing/idle, 1: walk frame 1, 2: walk frame 2
var current_dir: int = 0   # 0: Down, 1: Left, 2: Right, 3: Up
var anim_fps: float = 4.0

# Randomized subtype for visual variety (cat colors 0-7, cat1/cat2, parrot rows 0-7)
var subtype_idx: int = 0
var is_cat2: bool = false
var _texture_cache: Dictionary = {}

var sprite: Sprite3D

func _ready() -> void:
	# Cat scale: ~0.3m width. Sprite is ~32px, pixel_size=0.009 → 32*0.009=0.288m
	scale = Vector3(4.0, 4.0, 4.0)
	add_to_group("animals")
	
	if animal_type == AnimalType.CAT:
		add_to_group("cats")
	# 1. Tự động tạo Sprite3D nhận ánh sáng và đổ bóng phong cách retro
	sprite = Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true # Rất quan trọng: Giúp sprite 2D nhận ánh sáng/bóng đổ 3D thật hơn
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Pixel art sắc nét, không bị nhòe
	sprite.position.z = 0.15 # Đẩy nhẹ về phía trước để tránh clipping trên dốc
	add_child(sprite)
	
	# Định vị trí Y của sprite dựa theo kích thước loài vật để chân chạm đất phẳng
	match animal_type:
		AnimalType.CAT:
			sprite.position.y = 0.32
		AnimalType.DOG:
			sprite.position.y = 0.16
		AnimalType.RABBIT:
			sprite.position.y = 0.34
		AnimalType.PARROT:
			sprite.position.y = 0.32

	# 2. Tự động tạo CollisionShape3D hình cầu nhỏ để va chạm chướng ngại vật
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	col.position.y = 0.25
	add_child(col)

	# 3. Khởi tạo ngẫu nhiên
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	subtype_idx = rng.randi() % 8
	is_cat2 = rng.randf() > 0.5
	
	current_state = State.IDLE
	state_timer = rng.randf_range(1.0, 3.0)
	
	_update_sprite_texture()


func _physics_process(delta: float) -> void:
	# Áp dụng trọng lực
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Đếm ngược chuyển trạng thái AI
	state_timer -= delta
	if state_timer <= 0.0:
		_choose_new_state()

	# Di chuyển theo trạng thái
	if current_state == State.WANDER:
		velocity.x = wander_direction.x * speed
		velocity.z = wander_direction.z * speed
		
		# Cập nhật hướng quay của sprite theo vector vận tốc
		_update_direction_row(wander_direction)
		
		# Chạy vòng lặp animation đi bộ
		frame_timer += delta
		if frame_timer >= 1.0 / anim_fps:
			frame_timer = 0.0
			var max_frames := 2
			match animal_type:
				AnimalType.PARROT:
					max_frames = 4
				AnimalType.CAT, AnimalType.RABBIT:
					max_frames = 3
				AnimalType.DOG:
					max_frames = 10
			current_frame = (current_frame + 1) % max_frames
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta)
		current_frame = 0 # Trả về frame đứng yên khi idle

	move_and_slide()
	_update_sprite_texture()


func _choose_new_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if current_state == State.IDLE:
		current_state = State.WANDER
		state_timer = rng.randf_range(2.0, 5.0)
		var angle := rng.randf_range(0.0, TAU)
		wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	else:
		current_state = State.IDLE
		state_timer = rng.randf_range(1.0, 3.0)
		wander_direction = Vector3.ZERO


func _update_direction_row(dir: Vector3) -> void:
	# Quy đổi vector 3D thành 4 hướng (0: Down, 1: Left, 2: Right, 3: Up)
	if abs(dir.x) > abs(dir.z):
		if dir.x > 0.0:
			current_dir = 2 # Right
		else:
			current_dir = 1 # Left
	else:
		if dir.z > 0.0:
			current_dir = 0 # Down
		else:
			current_dir = 3 # Up


func _update_sprite_texture() -> void:
	if sprite == null:
		return
		
	# Quy đổi frame vòng lặp 0, 1 -> 0, 1 (2 walk frames)
	var anim_frame := current_frame
		
	var path := ""
	match animal_type:
		AnimalType.CAT:
			var prefix := "cat2" if is_cat2 else "cat1"
			path = "res://Assets/Animals_DesireFantasy/cropped/%s_%d_d%d_f%d.png" % [prefix, subtype_idx, current_dir, anim_frame]
		AnimalType.DOG:
			path = "res://Assets/Animals_DesireFantasy/cropped/dog_d%d_f%d.png" % [current_dir, anim_frame]
		AnimalType.RABBIT:
			path = "res://Assets/Animals_DesireFantasy/cropped/rabbit_d%d_f%d.png" % [current_dir, anim_frame]
		AnimalType.PARROT:
			# Vẹt có 8 hàng hành động khác nhau, dùng r0 đến r7. Cho ngẫu nhiên row theo subtype hoặc hướng di chuyển
			var parrot_row = current_dir
			if subtype_idx >= 4:
				parrot_row += 4 # Dùng các hàng hành động phụ để đa dạng hơn
			path = "res://Assets/Animals_DesireFantasy/cropped/parrot_r%d_f%d.png" % [parrot_row, anim_frame]
			
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path) as Texture2D
		else:
			_texture_cache[path] = null
			
	var tex: Texture2D = _texture_cache[path]
	if tex:
		sprite.texture = tex
