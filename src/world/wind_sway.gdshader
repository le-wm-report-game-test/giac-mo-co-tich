// wind_sway.gdshader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float wind_speed = 0.54;
uniform float wind_strength = 0.024;
uniform float wind_frequency = 0.3;

void vertex() {
	// Hệ số độ cao: Giữ gốc cây đứng yên (Y=0) và đung đưa mạnh hơn về phía ngọn cây (Y > 0)
	float height_factor = max(0.0, VERTEX.y);
	
	// Tính toán độ lệch pha sóng sin dựa trên vị trí thế giới (MODEL_MATRIX[3].xz) để các cây đung đưa so le
	float offset = sin(TIME * wind_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * wind_frequency + VERTEX.y * 0.4) * wind_strength * height_factor;
	
	// Áp dụng dịch chuyển trục ngang X và Z
	VERTEX.x += offset;
	VERTEX.z += offset * 0.4;
}

void fragment() {
	vec4 albedo_tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5; // Xử lý viền trong suốt của lá cây không bị viền hộp đen
	METALLIC = 0.0;
	ROUGHNESS = 0.85;
}
