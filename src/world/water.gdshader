shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Màu sắc nước: xanh lam ngọc lục bảo sâu đậm đà
uniform vec4 water_color : source_color = vec4(0.08, 0.28, 0.38, 0.78);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.0;
uniform float wave_amplitude : hint_range(0.01, 0.5) = 0.04;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Sóng nhấp nhô theo hàm thời gian và tọa độ thực tế
	float wave1 = sin(world_position.x * 0.7 + TIME * wave_speed) * cos(world_position.z * 0.7 + TIME * wave_speed);
	float wave2 = sin(world_position.x * 1.3 - TIME * wave_speed * 1.2) * cos(world_position.z * 1.1 + TIME * wave_speed * 0.8);
	
	VERTEX.y += (wave1 * 0.65 + wave2 * 0.35) * wave_amplitude;
}

void fragment() {
	// Gợn sóng nhấp nhô nhẹ trên bề mặt tạo bóng nước lóng lánh
	float wave_height = sin(world_position.x * 1.8 + TIME * 0.8) * cos(world_position.z * 1.8 + TIME * 0.8);
	vec3 final_color = mix(water_color.rgb, water_color.rgb * 1.25, wave_height * 0.12 + 0.12);
	
	ALBEDO = final_color;
	ALPHA = water_color.a;
	
	// Cấu hình phản chiếu cao độ ẩm
	ROUGHNESS = 0.06;
	METALLIC = 0.12;
	SPECULAR = 0.95;
}
