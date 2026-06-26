// wind_sway.gdshader
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float wind_speed = 1.2;
uniform float wind_strength = 0.25;
uniform float wind_frequency = 0.28;
uniform float alpha_multiplier = 1.0;
uniform float alpha_cutoff = 0.35;

void vertex() {
	// Hệ số độ cao: Giữ gốc cây đứng yên và chỉ đung đưa phần tán/nhánh phía trên.
	float height_factor = smoothstep(0.15, 4.5, max(0.0, VERTEX.y));
	
	// Tính toán độ lệch pha theo vị trí thế giới để các cây đung đưa so le.
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * wind_frequency;
	float gust = 0.65 + 0.35 * sin(TIME * 0.23 + phase);
	float offset = sin(TIME * wind_speed + phase + VERTEX.y * 0.42) * wind_strength * height_factor * gust;
	
	// Áp dụng dịch chuyển trục ngang X và Z
	VERTEX.x += offset;
	VERTEX.z += offset * 0.4;
}

void fragment() {
	vec4 albedo_tex = texture(albedo_texture, UV) * albedo_color;
	float cutout_alpha = step(alpha_cutoff, albedo_tex.a);
	ALBEDO = albedo_tex.rgb;
	ALPHA = cutout_alpha * alpha_multiplier;
	ALPHA_SCISSOR_THRESHOLD = 0.01; // Cắt nền lá nhưng vẫn cho phép tree fade bằng alpha_multiplier.
	METALLIC = 0.0;
	ROUGHNESS = 0.85;
}
