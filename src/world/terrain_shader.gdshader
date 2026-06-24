// terrain_shader.gdshader
shader_type spatial;

// Textures
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap;

// Road Textures
uniform sampler2D road_albedo : source_color, filter_linear_mipmap;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap;
uniform vec3 road_color_tint : source_color = vec3(0.5, 0.4, 0.3);

// Blending settings
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.75;
uniform float slope_blend : hint_range(0.01, 1.0) = 0.15;
uniform vec2 uv_scale = vec2(20.0, 20.0);

varying vec3 v_world_normal;

void vertex() {
	// Pass world normal to fragment shader
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	// Slope is the vertical component of the world normal
	float slope = n.y; // 1.0 is perfectly flat, 0.0 is vertical wall

	// Scale UVs for tile repeating
	vec2 scaled_uv = UV * uv_scale;

	// Sample terrain textures
	vec4 grass_color = texture(grass_albedo, scaled_uv);
	vec4 rock_color = texture(rock_albedo, scaled_uv);
	vec3 grass_norm = texture(grass_normal, scaled_uv).rgb;
	vec3 rock_norm = texture(rock_normal, scaled_uv).rgb;

	// Sample road textures with tint
	vec4 road_color = texture(road_albedo, scaled_uv) * vec4(road_color_tint, 1.0);
	vec3 road_norm = texture(road_normal, scaled_uv).rgb;

	// Calculate blend weight based on slope
	// slope goes from 0.0 (cliff) to 1.0 (flat ground)
	float weight = smoothstep(slope_threshold - slope_blend, slope_threshold + slope_blend, slope);

	// Blend terrain albedo, normal and roughness
	vec3 terrain_blend = mix(rock_color.rgb, grass_color.rgb, weight);
	vec3 terrain_norm = mix(rock_norm, grass_norm, weight);
	float terrain_rough = mix(0.9, 0.7, weight);

	// Final blend with road using vertex color red channel (COLOR.r is road weight)
	ALBEDO = mix(terrain_blend, road_color.rgb, COLOR.r);
	NORMAL_MAP = mix(terrain_norm, road_norm, COLOR.r);
	ROUGHNESS = mix(terrain_rough, 0.8, COLOR.r);
	SPECULAR = 0.1;
}
