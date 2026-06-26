# hitbox_component.gd
class_name HitboxComponent
extends Area3D

@export var damage: float = 10.0

func _ready() -> void:
	# Configure Area3D default collision parameters for hitbox detection
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		# Call receive hit on the hurtbox, passing this hitbox's damage and owner
		hurtbox.receive_hit(damage, owner)
