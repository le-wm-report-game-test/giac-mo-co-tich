# health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, source: Node3D)
signal died

@export var max_health: float = 100.0
@export var current_health: float = 100.0

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float, source: Node3D = null) -> void:
	if current_health <= 0.0:
		return
		
	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, source)
	
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
		
	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
