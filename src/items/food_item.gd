# food_item.gd
class_name FoodItem
extends Area3D

signal signal_respawn_requested(food: FoodItem)

enum FoodType { APPLE_RED, ORANGE, PEAR, GRAPES }

const WORLD_RENDER_MASK: int = 1

@export var food_type: FoodType = FoodType.APPLE_RED
@export var heal_amount: float = 20.0
@export var speed_boost_percent: float = 0.25
@export var speed_boost_duration: float = 5.0
@export var respawn_time: float = 45.0
@export var bob_amplitude: float = 0.05
@export var bob_speed: float = 2.0

var _original_position: Vector3
var _collected: bool = false
var _respawn_timer: float = 0.0
var _bob_offset: float = 0.0

var sprite: Sprite3D
var collision: CollisionShape3D
var _tween: Tween

const FOOD_SPRITE_PATH := "res://food_health.png"


func _ready() -> void:
	add_to_group("food_items")
	area_entered.connect(_on_area_entered)
	_setup_nodes()
	_original_position = global_position
	set_physics_process(false)


func _setup_nodes() -> void:
	sprite = Sprite3D.new()
	sprite.name = "Sprite3D"
	add_child(sprite)

	var tex := load(FOOD_SPRITE_PATH) as Texture2D
	if tex:
		sprite.texture = tex
		sprite.hframes = 4
		sprite.vframes = 1
		sprite.frame = food_type
		sprite.region_enabled = false
	else:
		push_warning("Food sprite not found: " + FOOD_SPRITE_PATH)

	# Atlas có bốn cell 256x256; scale này cho pickup cao khoảng 0.9m.
	sprite.pixel_size = 0.0035
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.layers = WORLD_RENDER_MASK

	collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	add_child(collision)

	_start_bob_animation()


func _start_bob_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_loops()
	var tween_y := _tween.tween_property(self, "_bob_offset", TAU, bob_speed)
	tween_y.set_ease(Tween.EASE_IN_OUT)
	tween_y.set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if _collected:
		return
	var bob := sin(_bob_offset) * bob_amplitude
	sprite.position.y = bob


func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent() as Player
	if player == null or _collected:
		return

	_apply_effect(player)
	_play_pickup_effect()
	_collect()


func _apply_effect(player: Player) -> void:
	_apply_heal(player)
	match food_type:
		FoodType.APPLE_RED:
			pass
		FoodType.ORANGE:
			_apply_speed_boost(player)
		FoodType.PEAR:
			pass
		FoodType.GRAPES:
			_apply_shield(player)


func _apply_heal(player: Player) -> void:
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.current_health = health.max_health
		health.health_changed.emit(health.current_health, health.max_health)
		EventBus.player_health_changed.emit(health.current_health, health.max_health)


func _apply_speed_boost(player: Player) -> void:
	player.apply_speed_boost(speed_boost_percent, speed_boost_duration)


func _apply_shield(player: Player) -> void:
	player.apply_shield()
	EventBus.player_shield_applied.emit()


func _play_pickup_effect() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "PickupParticles"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat

	particles.mesh = mesh
	particles.amount = 8
	particles.explosiveness = 0.8
	particles.one_shot = true
	particles.lifetime = 0.4
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 60.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.damping_min = 3.0
	particles.damping_max = 5.0

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	match food_type:
		FoodType.APPLE_RED, FoodType.PEAR:
			gradient.colors = PackedColorArray([Color.GREEN, Color(0.8, 0.4, 0.1), Color(1.0, 0.9, 0.7)])
		FoodType.ORANGE:
			gradient.colors = PackedColorArray([Color.ORANGE, Color(1.0, 0.6, 0.1), Color(1.0, 1.0, 0.8)])
		FoodType.GRAPES:
			gradient.colors = PackedColorArray([Color.PURPLE, Color(0.6, 0.3, 0.8), Color(1.0, 1.0, 1.0)])
	particles.color_ramp = gradient

	add_child(particles)
	particles.global_position = global_position + Vector3(0.0, 0.2, 0.0)
	particles.emitting = true
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)


func _collect() -> void:
	_collected = true
	collision.disabled = true

	if _tween and _tween.is_valid():
		_tween.kill()

	var collect_tween := create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(sprite, "scale", Vector3(0.0, 0.0, 0.0), 0.2)
	collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	collect_tween.chain().tween_callback(_schedule_respawn)


func _schedule_respawn() -> void:
	_respawn_timer = respawn_time
	visible = false
	set_physics_process(true)


func respawn_at(world_position: Vector3) -> void:
	global_position = world_position
	_respawn()


func _respawn() -> void:
	_collected = false
	visible = true
	collision.disabled = false
	sprite.scale = Vector3.ONE
	sprite.modulate = Color.WHITE
	_bob_offset = 0.0
	_start_bob_animation()
	_original_position = global_position
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _collected:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		if signal_respawn_requested.get_connections().is_empty():
			_respawn()
		else:
			signal_respawn_requested.emit(self)
