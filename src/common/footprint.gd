# footprint.gd
class_name Footprint
extends Sprite3D

var lifetime: float = 4.0
const MAX_LIFETIME: float = 4.0

func _ready() -> void:
	billboard = StandardMaterial3D.BILLBOARD_DISABLED
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# Rotate flat on ground
	rotation_degrees = Vector3(-90.0, rotation.y, 0.0)
	pixel_size = 0.006
	modulate = Color(0.18, 0.15, 0.12, 0.65) # Muted dust/dirt color
	
	# Programmatically generate footprint texture
	texture = _generate_footprint_tex()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var dist_fade: float = 1.0
	if player:
		var dist: float = global_position.distance_to(player.global_position)
		if dist >= 10.0:
			queue_free()
			return
		elif dist > 3.0:
			dist_fade = 1.0 - (dist - 3.0) / 7.0
			
	var time_fade: float = lifetime / MAX_LIFETIME
	modulate.a = 0.65 * time_fade * dist_fade

func _generate_footprint_tex() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dist := Vector2(x - 7.5, y - 7.5).length()
			if dist < 6.0:
				# Circular/oval soft footprint dot
				var alpha := (6.0 - dist) / 6.0 * 0.9
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
