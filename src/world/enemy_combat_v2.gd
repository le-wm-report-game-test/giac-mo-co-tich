# enemy_combat_v2.gd
# Combat V2 component for enemies. Owns the 3-phase attack state machine
# (ANTICIPATION → ATTACK → RECOVERY) and telegraph lifecycle for un-dodgeable
# AoE attacks. Mounted as a child node of OrcMob / OrcBossMob / ChanTinhMob.
#
# Phase semantics follow .agents/skills/combat-design-rules SKILL.md:
#   ANTICIPATION: enemy windups. Hitbox OFF. Telegraph decal visible.
#   ATTACK: hitbox ON for the active window (default 0.10s).
#   RECOVERY: hitbox OFF. Counter-attack window for player.
class_name EnemyCombatV2
extends Node

const AttackTelegraph = preload("res://src/world/attack_telegraph.gd")

enum AttackPhase { ANTICIPATION, ATTACK, RECOVERY }

@export var enabled: bool = true
@export_range(0.25, 0.6, 0.01) var anticipation_ratio: float = 0.30
@export_range(0.05, 0.15, 0.01) var active_ratio: float = 0.15
@export_range(0.30, 0.6, 0.01) var recovery_ratio: float = 0.55
@export_range(0.2, 1.0, 0.05) var telegraph_min_duration: float = 0.4

# Phase state
var phase: AttackPhase = AttackPhase.ANTICIPATION
var phase_timer: float = 0.0
var anticipation_dur: float = 0.0
var active_dur: float = 0.0
var recovery_dur: float = 0.0

# Lifecycle
var is_active: bool = false

# Telegraph configuration (set by enemy before attack starts)
var telegraph_radius: float = 1.0
var telegraph_duration_override: float = 0.0  # 0 means use anticipation_dur

# Owner wiring
var _hitbox_component: Node = null
var _telegraph_node: Node3D = null
var _enemy_owner: Node3D = null

func bind(owner: Node3D, hitbox: Node) -> void:
	_enemy_owner = owner
	_hitbox_component = hitbox

func on_attack_started(anim_fps: float, attack_frame_count: int) -> void:
	if not enabled:
		return
	is_active = true
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_init_phase_durations(anim_fps, attack_frame_count)
	_spawn_telegraph()
	_set_hitbox_monitoring(false)

func on_attack_ended() -> void:
	if not enabled:
		return
	is_active = false
	phase = AttackPhase.ANTICIPATION
	phase_timer = 0.0
	_remove_telegraph()
	_set_hitbox_monitoring(false)

func tick(delta: float) -> bool:
	# Returns true if this component is still driving the attack (enemy should
	# stay locked in attack state and not return to chase/AI logic).
	if not enabled or not is_active:
		return false
	phase_timer += delta
	match phase:
		AttackPhase.ANTICIPATION:
			_set_hitbox_monitoring(false)
			if phase_timer >= maxf(anticipation_dur, telegraph_min_duration):
				phase = AttackPhase.ATTACK
				phase_timer = 0.0
				_remove_telegraph()
		AttackPhase.ATTACK:
			_set_hitbox_monitoring(true)
			if phase_timer >= active_dur:
				phase = AttackPhase.RECOVERY
				phase_timer = 0.0
				_set_hitbox_monitoring(false)
		AttackPhase.RECOVERY:
			_set_hitbox_monitoring(false)
			if phase_timer >= recovery_dur:
				on_attack_ended()
				return false
	return true

func get_active_phase() -> AttackPhase:
	return phase

func _init_phase_durations(anim_fps: float, attack_frame_count: int) -> void:
	var frames: float = float(attack_frame_count)
	var total_dur: float = frames / maxf(anim_fps, 0.01)
	anticipation_dur = total_dur * anticipation_ratio
	active_dur = maxf(total_dur * active_ratio, 0.08)
	recovery_dur = total_dur * recovery_ratio

func _set_hitbox_monitoring(on: bool) -> void:
	if _hitbox_component and is_instance_valid(_hitbox_component):
		_hitbox_component.monitoring = on

func _spawn_telegraph() -> void:
	var dur: float = telegraph_duration_override
	if dur <= 0.0:
		dur = maxf(anticipation_dur, telegraph_min_duration)
	var telegraph: Node3D = AttackTelegraph.build_circle(_enemy_owner.global_position, telegraph_radius, dur)
	get_tree().current_scene.add_child(telegraph)
	_telegraph_node = telegraph

func _remove_telegraph() -> void:
	if _telegraph_node and is_instance_valid(_telegraph_node):
		_telegraph_node.cancel()
		_telegraph_node = null
