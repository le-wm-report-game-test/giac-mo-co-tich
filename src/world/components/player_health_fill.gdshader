shader_type canvas_item;
render_mode unshaded;

uniform vec2 bar_size = vec2(1.0);
uniform sampler2D mask_texture : source_color, filter_nearest;
uniform vec2 mask_texture_size = vec2(1.0);
uniform vec2 mask_region_position = vec2(0.0);
uniform vec2 mask_region_size = vec2(1.0);
uniform vec4 fill_color : source_color = vec4(0.78, 0.08, 0.1, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float fill_width = clamp(fill_ratio, 0.0, 1.0) * bar_size.x;
	vec2 pixel = UV * bar_size;
	float moving_alpha = 1.0 - smoothstep(fill_width - 0.5, fill_width + 0.5, pixel.x);
	vec2 mask_uv = (mask_region_position + UV * mask_region_size) / mask_texture_size;
	vec4 mask_pixel = texture(mask_texture, mask_uv);
	float luminance = dot(mask_pixel.rgb, vec3(0.299, 0.587, 0.114));
	float inner_alpha = mask_pixel.a * (1.0 - smoothstep(0.18, 0.36, luminance));
	float alpha = moving_alpha * inner_alpha * step(0.0001, fill_width);
	COLOR = vec4(fill_color.rgb, fill_color.a * alpha);
}
