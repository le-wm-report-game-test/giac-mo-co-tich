// wind_sway.gdshader
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D ao_texture : filter_linear_mipmap_anisotropic;
uniform bool has_normal_texture = false;
uniform bool has_roughness_texture = false;
uniform bool has_metallic_texture = false;
uniform bool has_ao_texture = false;
uniform int roughness_channel = 0;
uniform int metallic_channel = 0;
uniform int ao_channel = 0;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float wind_speed = 1.2;
uniform float wind_strength = 0.25;
uniform float wind_frequency = 0.28;
uniform float alpha_multiplier = 1.0;
uniform float alpha_cutoff = 0.35;

float sample_channel(vec4 value, int channel) {
	if (channel == 1) {
		return value.g;
	}
	if (channel == 2) {
		return value.b;
	}
	if (channel == 3) {
		return value.a;
	}
	return value.r;
}

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
	vec2 material_uv = UV * uv1_scale.xy + uv1_offset.xy;
	vec4 albedo_tex = texture(albedo_texture, material_uv) * albedo_color;
	if (albedo_tex.a < alpha_cutoff) {
		discard;
	}
	// Screen-door fade dùng cùng threshold cho mọi lớp cành tại một pixel,
	// tránh nhiều lớp alpha 0.3 cộng dồn thành gần như opaque.
	if (alpha_multiplier < 0.999) {
		float dither = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (dither > alpha_multiplier) {
			discard;
		}
	}
	// Cân lại normal cho mặt sau của foliage hai mặt để tránh tán cây thành silhouette đen.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = albedo_tex.rgb;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = base_roughness;
	METALLIC = base_metallic;
	if (has_normal_texture) {
		NORMAL_MAP = texture(normal_texture, material_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	if (has_roughness_texture) {
		ROUGHNESS *= sample_channel(texture(roughness_texture, material_uv), roughness_channel);
	}
	if (has_metallic_texture) {
		METALLIC *= sample_channel(texture(metallic_texture, material_uv), metallic_channel);
	}
	if (has_ao_texture) {
		AO = sample_channel(texture(ao_texture, material_uv), ao_channel);
	}
}
