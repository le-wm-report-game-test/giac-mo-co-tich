# event_bus.gd
extends Node

# Global signals
signal player_spawned(player: CharacterBody3D)
signal player_died
signal player_health_changed(current: float, max_health: float)
signal player_took_damage(amount: float, position: Vector3)
signal enemy_damaged(enemy: Node3D, amount: float, position: Vector3)
signal enemy_died(enemy: Node3D)
signal boss_spawned(boss: Node3D)
signal player_stepped(position: Vector3)
signal orc_killed_count(count: int)
signal weather_changed(weather_type: String)
