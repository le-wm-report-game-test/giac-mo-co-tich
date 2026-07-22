shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial = 1.0 - smoothstep(0.18, 1.0, length(centered_uv * vec2(0.95, 1.2)));
	float vertical = smoothstep(1.0, 0.2, abs(centered_uv.y));
	COLOR = vec4(0.03, 0.05, 0.04, radial * vertical * 0.44);
}
