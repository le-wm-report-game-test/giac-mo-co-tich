# player_combat_v2.gd
# Combat V2 component for Player. Owns:
#   - 3-phase attack state machine (ANTICIPATION → ATTACK → RECOVERY)
#   - Input buffer + IASA (cancel-to-movement, attack chain)
#   - Hit-phase driven hitbox monitoring
#   - Punish multiplier when player is interrupted mid-attack
#
# Mounted as a child node of Player. Player reads `phase`, `is_active`, and
# routes _input/_physics_process through this component.
class_name PlayerCombatV2
extends Node

const COMBAT_V2_INTERRUPT_DAMAGE_MULT: float = 1.5
const IASA_BUFFER_WINDOW_SEC: float = 0.15
const IASA_MOVEMENT_INPUT_MIN: float = 0.01

enum AttackPhase { ANTICIPATION, ATTACK, RECOVERY }

@export var enabled: bool = true
@export_range(0.25, 0.6, 0.01) var anticipation_ratio: float = 0.30
@export_range(0.05, 0.15, 0.01) var active_ratio: float = 0.15
@export_range(0.30, 0.6, 0.01) var recovery_ratio: float = 0.55

# Phase state
var phase: AttackPhase = AttackPhase.ANTICIPATION
var phase_timer: float = 0.0
var anticipation_dur: float = 0.0
var active_dur: float = 0.0
var recovery_dur: float = 0.0

# IASA buffer
var _buffer_remaining: float = 0.0
var _buffered_attack: bool = false

# Lifecycle
var is_active: bool = false

# Owner wiring
var _hitbox_area: Area3D = null

func bind(player: CharacterBody3D) -> void:
	_hitbox_area = player.get_node_or_null("HitboxArea") as Area3D

func on_attack_started(anim_fps: float, attack_frame_count: int) -> void:
	if not enabled:
		return
	is_active = true
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_buffered_attack = false
	_buffer_remaining = 0.0
	_init_phase_durations(anim_fps, attack_frame_count)
	_set_hitbox_monitoring(false)

func on_attack_interrupted() -> void:
	if not enabled:
		return
	is_active = false
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_buffered_attack = false
	_buffer_remaining = 0.0
	_set_hitbox_monitoring(false)

func try_buffer_input() -> bool:
	# Returns true if the input was buffered (i.e. press happened during
	# non-cancelable phase). Call this from Player._input before _start_attack.
	if not enabled or not is_active:
		return false
	if phase == AttackPhase.RECOVERY:
		return false
	_buffered_attack = true
	_buffer_remaining = IASA_BUFFER_WINDOW_SEC
	return true

func consume_recovery_buffer() -> bool:
	# Player may call this when player wants to start a new attack while still
	# in RECOVERY. Returns true if there was a buffered attack to consume.
	if not enabled or not is_active:
		return false
	if phase != AttackPhase.RECOVERY:
		return false
	if not _buffered_attack:
		return false
	_buffered_attack = false
	_buffer_remaining = 0.0
	return true

func tick(delta: float) -> bool:
	# Returns true if this component is still driving the attack state and
	# Player should skip its own movement/state update for this frame.
	if not enabled or not is_active:
		return false
	if _buffer_remaining > 0.0:
		_buffer_remaining -= delta
		if _buffer_remaining <= 0.0:
			_buffered_attack = false
	phase_timer += delta
	match phase:
		AttackPhase.ANTICIPATION:
			_set_hitbox_monitoring(false)
			if phase_timer >= anticipation_dur:
				phase = AttackPhase.ATTACK
				phase_timer = 0.0
		AttackPhase.ATTACK:
			_set_hitbox_monitoring(true)
			if phase_timer >= active_dur:
				phase = AttackPhase.RECOVERY
				phase_timer = 0.0
				_set_hitbox_monitoring(false)
		AttackPhase.RECOVERY:
			_set_hitbox_monitoring(false)
			if _buffered_attack:
				return false  # let Player call _start_attack
			if _has_movement_input() and phase_timer >= 0.05:
				_cancel_to_idle()
				return false
			if phase_timer >= recovery_dur:
				_finish_attack()
	return true

func should_apply_interrupt_penalty() -> bool:
	return enabled and is_active

func _cancel_to_idle() -> void:
	is_active = false
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_buffered_attack = false
	_buffer_remaining = 0.0
	_set_hitbox_monitoring(false)

func _finish_attack() -> void:
	is_active = false
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_buffered_attack = false
	_buffer_remaining = 0.0
	_set_hitbox_monitoring(false)

func _init_phase_durations(anim_fps: float, attack_frame_count: int) -> void:
	var frames: float = float(attack_frame_count)
	var total_dur: float = frames / maxf(anim_fps, 0.01)
	anticipation_dur = total_dur * anticipation_ratio
	active_dur = total_dur * active_ratio
	recovery_dur = total_dur * recovery_ratio

func _set_hitbox_monitoring(on: bool) -> void:
	if _hitbox_area and is_instance_valid(_hitbox_area):
		_hitbox_area.monitoring = on

func _has_movement_input() -> bool:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > IASA_MOVEMENT_INPUT_MIN
