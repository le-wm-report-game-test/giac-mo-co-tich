class_name DamagePopup
extends Label

enum Kind { PLAYER_HIT, ENEMY_HIT, CRITICAL }

const DAMAGE_FONT: FontFile = preload("res://Assets/UI/Fonts/Anton/Anton-Regular.ttf")

const NORMAL_FONT_SIZE: int = 44
const CRITICAL_FONT_SIZE: int = 64
const NORMAL_OUTLINE_SIZE: int = 7
const CRITICAL_OUTLINE_SIZE: int = 10

const NORMAL_SIZE := Vector2(180.0, 88.0)
const CRITICAL_SIZE := Vector2(260.0, 118.0)

var popup_kind: Kind = Kind.ENEMY_HIT
var _horizontal_drift: float = 0.0
var _float_distance: float = 90.0
var _float_duration: float = 0.72

func configure(amount: float, screen_position: Vector2, kind: Kind) -> void:
	popup_kind = kind
	name = "DamagePopup"
	text = str(int(round(amount)))
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clip_text = false

	size = CRITICAL_SIZE if kind == Kind.CRITICAL else NORMAL_SIZE
	custom_minimum_size = size
	pivot_offset = size * 0.5
	position = screen_position - size * 0.5 + Vector2(randf_range(-18.0, 18.0), -42.0)
	_horizontal_drift = randf_range(-32.0, 32.0)

	_apply_typography(kind)
	if kind == Kind.CRITICAL:
		_add_critical_tag()

func play() -> void:
	if not is_inside_tree():
		call_deferred("play")
		return

	var start_position := position
	var peak_scale := Vector2(1.34, 1.34) if popup_kind == Kind.CRITICAL else Vector2(1.22, 1.22)
	scale = Vector2(0.56, 0.56)
	rotation = deg_to_rad(randf_range(-4.0, 4.0))
	modulate.a = 0.0

	var impact_tween := create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(self, "scale", peak_scale, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(self, "position:y", start_position.y - 18.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(self, "modulate:a", 1.0, 0.04)
	impact_tween.chain()
	impact_tween.tween_property(self, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(self, "rotation", 0.0, 0.11)
	impact_tween.finished.connect(_play_float_animation)

func _apply_typography(kind: Kind) -> void:
	add_theme_font_override("font", DAMAGE_FONT)
	add_theme_constant_override("shadow_offset_x", 4)
	add_theme_constant_override("shadow_offset_y", 6)
	add_theme_constant_override("shadow_outline_size", 3)

	match kind:
		Kind.PLAYER_HIT:
			add_theme_font_size_override("font_size", NORMAL_FONT_SIZE)
			add_theme_color_override("font_color", Color("ff6b5f"))
			add_theme_color_override("font_outline_color", Color("4a1018"))
			add_theme_color_override("font_shadow_color", Color(0.08, 0.0, 0.01, 0.9))
			add_theme_constant_override("outline_size", NORMAL_OUTLINE_SIZE)
		Kind.CRITICAL:
			add_theme_font_size_override("font_size", CRITICAL_FONT_SIZE)
			add_theme_color_override("font_color", Color("fff7cf"))
			add_theme_color_override("font_outline_color", Color("6d32a8"))
			add_theme_color_override("font_shadow_color", Color(0.95, 0.24, 0.08, 0.92))
			add_theme_constant_override("outline_size", CRITICAL_OUTLINE_SIZE)
			_float_distance = 118.0
			_float_duration = 0.88
		_:
			add_theme_font_size_override("font_size", NORMAL_FONT_SIZE)
			add_theme_color_override("font_color", Color("f8fbff"))
			add_theme_color_override("font_outline_color", Color("352052"))
			add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.08, 0.9))
			add_theme_constant_override("outline_size", NORMAL_OUTLINE_SIZE)

func _add_critical_tag() -> void:
	var tag := Label.new()
	tag.name = "ImpactTag"
	tag.text = "CRITICAL!"
	tag.position = Vector2.ZERO
	tag.size = Vector2(size.x, 34.0)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", DAMAGE_FONT)
	tag.add_theme_font_size_override("font_size", 23)
	tag.add_theme_color_override("font_color", Color("ffd866"))
	tag.add_theme_color_override("font_outline_color", Color("551b75"))
	tag.add_theme_color_override("font_shadow_color", Color(0.25, 0.02, 0.1, 0.9))
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 3)
	add_child(tag)

func _play_float_animation() -> void:
	var float_tween := create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(
		self,
		"position",
		position + Vector2(_horizontal_drift, -_float_distance),
		_float_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(self, "scale", Vector2(0.92, 0.92), _float_duration)
	float_tween.tween_property(self, "modulate:a", 0.0, 0.28).set_delay(_float_duration - 0.28)
	float_tween.finished.connect(queue_free)
