shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Giữ lại các uniform để tương thích hoàn toàn với forest_builder.gd
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D path_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic;

uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 vertex_color;

// ─── Procedural Noise Functions ─────────────────────────────────────────────
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
	mat2 rot = mat2(vec2(0.87758, 0.47942), vec2(-0.47942, 0.87758));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

// Nhiễu kéo giãn tạo cấu trúc thớ rễ cây/vân gỗ ngoằn ngoèo
float stretched_noise(vec2 p) {
	vec2 stretched_p = p * vec2(0.35, 5.0);
	float n1 = noise(stretched_p);
	float n2 = noise(stretched_p + vec2(n1 * 1.8, TIME * 0.02)); // Đung đưa rất khẽ
	return n2;
}

// Trả về bản đồ độ gồ ghề (displacement) để tính toán pháp tuyến nổi khối
float get_displacement(vec2 p) {
	// 1. Độ lồi của rễ cây bò ngầm (Chỉ xuất hiện rải rác)
	float root_mask = smoothstep(0.64, 0.82, fbm(p * 0.45));
	float roots = stretched_noise(p * 1.8) * 0.18 * root_mask;
	
	// 2. Độ gồ ghề của đất cát micro
	float soil = fbm(p * 8.5) * 0.035;
	
	// 3. Đá tảng nứt nhỏ
	float rocks = fbm(p * 2.5) * 0.07;
	
	return roots + soil + rocks;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vertex_color = COLOR;
}

void fragment() {
	vec2 pos_xz = world_position.xz;

	// ─── 1. Tính toán pháp tuyến nổi khối 3D động (Procedural Normal Mapping) ────
	vec2 eps = vec2(0.015, 0.0);
	float h = get_displacement(pos_xz);
	float hx = get_displacement(pos_xz + eps.xy);
	float hz = get_displacement(pos_xz + eps.yx);
	
	// Độ dốc cục bộ trong không gian tiếp tuyến
	vec3 local_normal = normalize(vec3((h - hx) * 4.2, eps.x, (h - hz) * 4.2));
	
	// Khớp pháp tuyến cục bộ vào hướng nghiêng gốc của địa hình (world_normal)
	vec3 up = vec3(0.0, 1.0, 0.0);
	if (abs(world_normal.y) > 0.999) {
		up = vec3(1.0, 0.0, 0.0);
	}
	vec3 tangent = normalize(cross(up, world_normal));
	vec3 binormal = normalize(cross(world_normal, tangent));
	
	vec3 final_normal = normalize(
		tangent * local_normal.x +
		world_normal * local_normal.y +
		binormal * local_normal.z
	);
	
	NORMAL = mix(world_normal, final_normal, 0.82); // Áp dụng 82% độ gồ ghề

	// ─── 2. Phối trộn màu sắc đa tầng của nền rừng tự nhiên (Earth Tones) ──────────
	
	// Đất mùn ẩm (Rich forest soil) làm nền
	float n_soil = fbm(pos_xz * 5.0);
	vec3 soil_col1 = vec3(0.24, 0.16, 0.12); // Đất nâu tối
	vec3 soil_col2 = vec3(0.30, 0.22, 0.16); // Đất nâu xám sáng
	vec3 soil_col = mix(soil_col1, soil_col2, n_soil);
	
	// Đốm lá mục/mảnh gỗ rải rác trên đất (Leaf litter / Debris)
	float leaf_noise = fbm(pos_xz * 12.0);
	vec3 leaf_col = mix(vec3(0.46, 0.28, 0.16), vec3(0.56, 0.36, 0.22), noise(pos_xz * 22.0));
	soil_col = mix(soil_col, leaf_col, step(0.76, leaf_noise) * 0.45);

	// Thảm cỏ/rêu ẩm mọc loang lổ (Patchy vegetation)
	float grass_mask_noise = fbm(pos_xz * 0.16); // Tần số thấp tạo mảng cỏ to nhỏ tự nhiên
	float grass_factor = smoothstep(0.34, 0.58, grass_mask_noise);
	
	float n_grass = fbm(pos_xz * 3.8);
	vec3 grass_col1 = vec3(0.22, 0.34, 0.18); // Xanh cỏ úa/rêu ẩm rừng già
	vec3 grass_col2 = vec3(0.32, 0.44, 0.22); // Xanh lục bảo tự nhiên
	vec3 grass_col = mix(grass_col1, grass_col2, n_grass);
	
	// Màu vân rễ cây/vỏ cành mục bò nổi trên mặt đất
	float root_val = stretched_noise(pos_xz * 1.5);
	float root_mask = smoothstep(0.64, 0.82, fbm(pos_xz * 0.45));
	vec3 root_col = mix(vec3(0.32, 0.22, 0.14), vec3(0.42, 0.30, 0.20), root_val);

	// Trộn cỏ và đất
	vec3 ground_color = mix(soil_col, grass_col, grass_factor);
	
	// Đè rễ cây lên trên nền đất cỏ
	ground_color = mix(ground_color, root_col, root_mask * 0.75);

	// Đường sỏi đá (Path)
	float n_path = fbm(pos_xz * 5.5);
	vec3 path_col1 = vec3(0.34, 0.30, 0.26); // Sỏi xám xỉn
	vec3 path_col2 = vec3(0.44, 0.40, 0.36); // Sỏi đá sáng nhạt
	vec3 path_col = mix(path_col1, path_col2, n_path);
	
	// Trộn đường sỏi đá (vertex_color.r)
	float blend_noise = sin(world_position.x * 2.2) * cos(world_position.z * 2.2) * 0.05;
	float path_factor = clamp(vertex_color.r + blend_noise, 0.0, 1.0);
	ground_color = mix(ground_color, path_col, path_factor);

	// Vách đá dốc đứng (Rock cliffs)
	float slope_factor = clamp(world_normal.y, 0.0, 1.0);
	float rock_factor = 1.0 - smoothstep(0.70, 0.86, slope_factor);
	float n_rock = fbm(pos_xz * 2.5);
	vec3 rock_col1 = vec3(0.24, 0.24, 0.26); // Xám vách núi
	vec3 rock_col2 = vec3(0.34, 0.34, 0.32); // Rêu đá cổ
	vec3 rock_col = mix(rock_col1, rock_col2, n_rock);
	
	vec3 final_color = mix(ground_color, rock_col, rock_factor);

	// Lòng hồ nước đáy bùn ngập sâu (vertex_color.b)
	if (vertex_color.b > 0.01) {
		vec3 lakebed_col = path_col * vec3(0.18, 0.20, 0.16); // Bùn ngập xám đen
		final_color = mix(final_color, lakebed_col, vertex_color.b);
	}

	ALBEDO = final_color;

	// ─── 3. Thiết lập độ phản xạ PBR ──────────────────────────────────────────
	// Cỏ và rêu nhám cao, đá và rễ cây lì mịn hơn
	float base_roughness = mix(0.92, 0.84, path_factor);
	base_roughness = mix(base_roughness, 0.82, rock_factor);
	base_roughness = mix(base_roughness, 0.78, root_mask); // Rễ cây láng mịn hơn xíu

	// Hiệu ứng đất ẩm ướt khi có mưa giông
	vec3 wet_albedo = ALBEDO * 0.58;
	ALBEDO = mix(ALBEDO, wet_albedo, wet_amount);
	ROUGHNESS = mix(base_roughness, 0.20, wet_amount);
	METALLIC = mix(0.0, 0.12, wet_amount);
}
