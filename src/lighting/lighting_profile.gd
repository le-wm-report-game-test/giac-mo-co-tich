class_name LightingProfile
extends Resource

@export_group("Identity")
@export var profile_name: StringName = &"clear"
@export_range(0.0, 8.0, 0.1) var transition_seconds: float = 2.5

@export_group("Sun")
@export var sun_color: Color = Color.WHITE
@export_range(0.0, 8.0, 0.01) var sun_energy: float = 1.0
@export var sun_rotation_degrees: Vector3 = Vector3(-52.0, -135.0, 0.0)
@export_range(0.0, 4.0, 0.01) var sun_volumetric_energy: float = 0.65

@export_group("Ambient")
@export var ambient_color: Color = Color("#21343A")
@export_range(0.0, 4.0, 0.01) var ambient_energy: float = 0.2

@export_group("Atmosphere")
@export_range(0.0, 0.1, 0.0005) var fog_density: float = 0.01
@export var fog_albedo: Color = Color("#8CB7C5")
@export var fog_emission: Color = Color("#10252B")
@export_range(0.0, 2.0, 0.01) var fog_emission_energy: float = 0.04
@export var sky_top_color: Color = Color("#17394A")
@export var sky_horizon_color: Color = Color("#8CBAC5")
@export var ground_bottom_color: Color = Color("#101A16")
@export var ground_horizon_color: Color = Color("#385A55")

@export_group("Color Grade")
@export_range(0.1, 4.0, 0.01) var exposure: float = 0.95
@export_range(0.1, 4.0, 0.01) var contrast: float = 1.12
@export_range(0.0, 2.0, 0.01) var saturation: float = 0.94

@export_group("Wet Surface")
@export_range(0.0, 1.0, 0.01) var wet_amount: float = 0.0

@export_group("Gameplay Readability")
@export var actor_fill_color: Color = Color("#BFD8D2")
@export_range(0.0, 2.0, 0.01) var actor_fill_energy: float = 0.12
@export var player_accent_color: Color = Color("#FFE2B0")
@export_range(0.0, 2.0, 0.01) var player_accent_energy: float = 0.05
@export var navigation_accent_color: Color = Color("#FFD08A")
@export_range(0.0, 8.0, 0.01) var navigation_accent_energy: float = 0.75
