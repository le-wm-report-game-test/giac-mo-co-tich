# hurtbox_component.gd
class_name HurtboxComponent
extends Area3D

@export var health_component: HealthComponent

func _ready() -> void:
	# Configure Area3D default collision parameters for receiving hits
	monitoring = false
	monitorable = true

func receive_hit(amount: float, source: Node3D = null, is_critical: bool = false) -> void:
	if health_component:
		health_component.take_damage(amount, source, is_critical)
