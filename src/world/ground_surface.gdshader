shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.2, 0.32, 0.18, 1.0);
uniform vec4 variation_color : source_color = vec4(0.28, 0.4, 0.22, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float variation_strength : hint_range(0.0, 0.5) = 0.16;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Hai tần số nhẹ phá mảng màu phẳng mà không cần texture/noise sample bổ sung.
	float broad = sin(world_position.x * 0.23 + sin(world_position.z * 0.17) * 1.7) * 0.5 + 0.5;
	float fine = sin((world_position.x + world_position.z) * 1.35)
		* cos((world_position.x - world_position.z) * 1.05) * 0.5 + 0.5;
	float variation = clamp(broad * 0.72 + fine * 0.28, 0.0, 1.0) * variation_strength;
	ALBEDO = mix(base_color.rgb, variation_color.rgb, variation);
	ROUGHNESS = clamp(surface_roughness - fine * 0.04, 0.0, 1.0);
	METALLIC = 0.0;
}
