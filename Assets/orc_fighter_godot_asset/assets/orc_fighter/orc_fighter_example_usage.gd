extends Node3D

@onready var orc: OrcFighter = $OrcFighter

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		orc.attack()
	elif Input.is_action_just_pressed("ui_left"):
		orc.hit()
	elif Input.is_action_just_pressed("ui_down"):
		orc.defeated()
	elif Input.is_action_just_pressed("ui_up"):
		orc.idle()
