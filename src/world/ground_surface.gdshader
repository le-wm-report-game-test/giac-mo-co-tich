shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.2, 0.32, 0.18, 1.0);
uniform vec4 variation_color : source_color = vec4(0.28, 0.4, 0.22, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float variation_strength : hint_range(0.0, 0.5) = 0.16;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;

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

	// Wet look: darken the albedo (water on surface absorbs light) and
	// drop roughness so the ground becomes reflective like a soaked surface.
	// wet_amount is tweened by WetSurfaceController when weather changes.
	vec3 wet_albedo = base_color.rgb * 0.62;
	vec3 wet_variation = variation_color.rgb * 0.62;
	ALBEDO = mix(ALBEDO, mix(wet_albedo, wet_variation, variation), wet_amount);
	ROUGHNESS = clamp(surface_roughness - fine * 0.04, 0.0, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.28, wet_amount);
	METALLIC = mix(0.0, 0.12, wet_amount);
}
