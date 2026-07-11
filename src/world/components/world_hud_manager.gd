extends Node

const PlayerHudBuilder := preload("res://src/world/components/player_hud_builder.gd")
const MinimapManagerScript := preload("res://src/world/components/world_minimap_manager.gd")
const BOSS_DISPLAY_NAME: String = "Chằn Tinh"

var _owner: Node = null
var _minimap_manager: Node = null
var _boss_health_bar: BossHealthBar = null


func setup(owner: Node) -> void:
	_owner = owner
	_minimap_manager = MinimapManagerScript.new() as Node
	_minimap_manager.name = "MinimapManager"
	add_child(_minimap_manager)
	_minimap_manager.setup(owner)


func create_hud() -> void:
	var existing := _owner.get_node_or_null("UI")
	if existing:
		existing.name = "UI_PendingFree"
		existing.queue_free()
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	_owner.add_child(ui)
	PlayerHudBuilder.build(ui, _owner)
	_minimap_manager.build(ui)


func update_health(current: float, maximum: float) -> void:
	var bar := _owner.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(maximum, current)
		bar.value = current
	var fill := _owner.get("player_health_fill") as ColorRect
	if is_instance_valid(fill):
		var material := fill.material as ShaderMaterial
		if material:
			var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
			material.set_shader_parameter("fill_ratio", ratio)
	var text := _owner.get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText") as Label
	if text:
		text.text = "%d / %d" % [current, maximum]


func update_orc_counter() -> void:
	var label := _owner.get_node_or_null("UI/OrcCounter/OrcCountLabel") as Label
	if label:
		label.text = format_orc_counter()


func format_orc_counter() -> String:
	return "Orc da ha: %d/%d" % [
		int(_owner.get("orcs_killed")),
		int(_owner.get("orcs_to_kill_for_boss")),
	]


func show_boss_health_bar(boss: Node3D) -> void:
	hide_boss_health_bar()
	var ui := _owner.get_node_or_null("UI") as CanvasLayer
	if ui == null or boss == null:
		return
	_boss_health_bar = BossHealthBar.new()
	_boss_health_bar.name = "BossHealthBar"
	ui.add_child(_boss_health_bar)
	_boss_health_bar.attach(boss, BOSS_DISPLAY_NAME)


func hide_boss_health_bar() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.detach()
		_boss_health_bar.queue_free()
	_boss_health_bar = null


func spawn_damage_number(
	amount: float,
	world_position: Vector3,
	popup_kind: DamagePopup.Kind
) -> void:
	var camera := _owner.get_viewport().get_camera_3d()
	var ui := _owner.get_node_or_null("UI")
	if camera == null or ui == null:
		return
	var screen_position := camera.unproject_position(world_position + Vector3(0.0, 1.5, 0.0))
	var popup := DamagePopup.new()
	popup.configure(amount, screen_position, popup_kind)
	ui.add_child(popup)
	popup.play()


func update_minimap(delta: float, force: bool = false) -> void:
	_minimap_manager.update(delta, force)


func toggle_minimap_zoom() -> void:
	_minimap_manager.toggle_zoom()


func is_orc_attacking(candidate: Variant) -> bool:
	return _minimap_manager.is_orc_attacking(candidate)


func is_orc_marker(candidate: Variant) -> bool:
	return _minimap_manager.is_orc_marker(candidate)
