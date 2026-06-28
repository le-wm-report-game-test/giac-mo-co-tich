class_name MovementDustTrail
extends Node3D

const DUST_TEXTURE := preload(
	"res://Assets/Smoke FX Lite Zip 5.25.23/SmokeFX Lite SpriteSheet 4A-1.png"
)
const WORLD_RENDER_MASK: int = 1

@export_range(1, 12, 1) var pool_size: int = 6
@export_range(1, 32, 1) var frame_count: int = 16
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 24.0
@export_range(0.001, 0.02, 0.0001) var pixel_size: float = 0.0085
@export_range(0.0, 0.5, 0.01) var vertical_offset: float = 0.08
@export var tint: Color = Color(0.93, 0.86, 0.72, 0.72)

var _sprites: Array[Sprite3D] = []
var _elapsed: Array[float] = []
var _next_sprite_index: int = 0


func _ready() -> void:
	_build_pool()


func _process(delta: float) -> void:
	for index in range(_sprites.size()):
		if _elapsed[index] < 0.0:
			continue

		_elapsed[index] += delta
		var frame_index := int(_elapsed[index] * frames_per_second)
		if frame_index >= frame_count:
			_elapsed[index] = -1.0
			_sprites[index].visible = false
			continue

		_sprites[index].frame = frame_index


func spawn_at(world_position: Vector3, facing_y_rad: float = 0.0) -> void:
	if _sprites.is_empty() or not is_inside_tree():
		return

	var sprite := _sprites[_next_sprite_index]
	_elapsed[_next_sprite_index] = 0.0
	_next_sprite_index = (_next_sprite_index + 1) % _sprites.size()

	sprite.global_position = world_position + Vector3.UP * vertical_offset
	sprite.global_rotation.y = facing_y_rad
	sprite.frame = 0
	sprite.visible = true


func get_active_count() -> int:
	var active_count := 0
	for sprite in _sprites:
		if sprite.visible:
			active_count += 1
	return active_count


func get_pool_sprites() -> Array[Sprite3D]:
	return _sprites


func _build_pool() -> void:
	for index in range(pool_size):
		var sprite := Sprite3D.new()
		sprite.name = "DustSprite%d" % index
		sprite.texture = DUST_TEXTURE
		sprite.hframes = frame_count
		sprite.vframes = 1
		sprite.frame = 0
		sprite.pixel_size = pixel_size
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.layers = WORLD_RENDER_MASK
		sprite.modulate = tint
		sprite.visible = false
		add_child(sprite)
		# Giữ từng puff bụi tại vị trí bước chân thay vì kéo theo player.
		sprite.top_level = true
		_sprites.append(sprite)
		_elapsed.append(-1.0)
