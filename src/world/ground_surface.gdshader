shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Giữ lại các uniform để tránh lỗi gọi set_shader_parameter từ forest_builder.gd
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D path_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic;

uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 vertex_color;

// ─── Procedural Noise Helper Functions ──────────────────────────────────────
float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	return fract(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	// Xoay hướng để tránh bị hiện tượng sọc thẳng hàng trục X/Z
	mat2 rot = mat2(vec2(0.87758, 0.47942), vec2(-0.47942, 0.87758));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vertex_color = COLOR;
}

void fragment() {
	// 1. Sinh cấu trúc màu cỏ rừng ngẫu nhiên chân thực (Procedural Grass - Minecraft Vibrant Style)
	float n_grass = fbm(world_position.xz * 3.5);
	vec3 grass_col1 = vec3(0.32, 0.56, 0.18); // Màu xanh cỏ tươi bão hòa cao (Minecraft Grass)
	vec3 grass_col2 = vec3(0.48, 0.72, 0.24); // Màu xanh lá mạ sáng (Minecraft Side Grass)
	vec3 grass_col = mix(grass_col1, grass_col2, n_grass);
	
	// Trộn thêm mảng đất ẩm tối dưới tán cây để tạo chiều sâu
	float n_grass_dirt = fbm(world_position.xz * 0.7);
	vec3 forest_dirt = vec3(0.42, 0.32, 0.22); // Đất màu nâu ấm sáng (Minecraft Dirt)
	grass_col = mix(grass_col, forest_dirt, clamp(n_grass_dirt - 0.25, 0.0, 0.40));

	// 2. Sinh cấu trúc màu đất sỏi đường mòn chân thực (Procedural Dirt Path)
	float n_path = fbm(world_position.xz * 4.5);
	vec3 path_col1 = vec3(0.36, 0.28, 0.22); // Đất đỏ vàng
	vec3 path_col2 = vec3(0.46, 0.38, 0.32); // Đá sỏi nâu xám nhạt
	vec3 path_col = mix(path_col1, path_col2, n_path);
	
	// Tạo các viên sỏi nhỏ rải rác trên đường đi (High frequency noise)
	float pebble = step(0.85, hash(world_position.xz * 12.0));
	path_col = mix(path_col, vec3(0.58, 0.56, 0.54), pebble * 0.3);

	// 3. Sinh cấu trúc đá vách núi dốc đứng chân thực (Procedural Rock)
	float n_rock = fbm(world_position.xz * 2.8);
	vec3 rock_col1 = vec3(0.28, 0.28, 0.28); // Đá xám tối cổ kính
	vec3 rock_col2 = vec3(0.38, 0.40, 0.36); // Đá phong rêu ngả xanh
	vec3 rock_col = mix(rock_col1, rock_col2, n_rock);

	// 4. Hòa trộn đất đá tự động theo sườn dốc (Slope-based blend)
	float slope_factor = clamp(world_normal.y, 0.0, 1.0);
	// Dưới 0.85 (dốc ~30 độ trở lên) chuyển sang đá vách núi phong rêu
	float rock_factor = 1.0 - smoothstep(0.72, 0.88, slope_factor);

	// 5. Hòa trộn giữa cỏ rừng và đường mòn sỏi dựa trên COLOR.r (độ lớn zone path)
	// Nhiễu hữu cơ ở rìa giúp đường đi hòa quyện mượt mà vào cỏ rừng không răng cưa
	float blend_noise = sin(world_position.x * 2.2) * cos(world_position.z * 2.2) * 0.06;
	float path_factor = clamp(vertex_color.r + blend_noise, 0.0, 1.0);

	vec3 ground_color = mix(grass_col, path_col, path_factor);
	vec3 final_color = mix(ground_color, rock_col, rock_factor);

	// 6. Nếu ở khu vực lòng hồ nước (COLOR.b > 0.0), trộn sang bùn đất tối ngập nước ở đáy hồ
	if (vertex_color.b > 0.01) {
		vec3 lakebed_col = path_col * vec3(0.20, 0.22, 0.18); // Tối sẫm, ngả sắc rêu ngập nước
		final_color = mix(final_color, lakebed_col, vertex_color.b);
	}

	ALBEDO = final_color;

	// 7. Thiết lập độ nhám PBR
	float base_roughness = mix(0.92, 0.82, path_factor);
	base_roughness = mix(base_roughness, 0.85, rock_factor);

	// Cấu hình ẩm ướt khi có mưa bão (Wet surface)
	vec3 wet_albedo = ALBEDO * 0.60;
	ALBEDO = mix(ALBEDO, wet_albedo, wet_amount);
	ROUGHNESS = mix(base_roughness, 0.22, wet_amount);
	METALLIC = mix(0.0, 0.12, wet_amount);
}
