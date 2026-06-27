// god_ray.gdshader
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 ray_color : source_color = vec4(1.0, 0.88, 0.65, 0.16);
uniform float beam_softness : hint_range(1.0, 10.0) = 2.2;
uniform float noise_scale = 1.8;
uniform float noise_speed = 0.4;
uniform float alpha_multiplier = 1.0;

// Simple 2D hash function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 2D Value Noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Offset vertices so local (0, 0, 0) is at the bottom of the beam.
	// Since height is 24.0, VERTEX.y originally goes from -12.0 to 12.0.
	// Adding 12.0 makes VERTEX.y go from 0 (bottom) to 24.0 (top).
	VERTEX.y += 12.0;
}

void fragment() {
	// UV.y goes from 0 (top) to 1 (bottom). Fade out at both ends (0 at bottom prevents intersection line).
	float vertical_fade = sin(UV.y * 3.14159);
	
	// Soft horizontal fade for the edges of the quad plane
	float horizontal_fade = pow(sin(UV.x * 3.14159), beam_softness);
	
	// Dynamic edge fade based on view angle (Fresnel/Silhouette)
	float edge_fade = pow(abs(dot(NORMAL, VIEW)), 2.0);
	
	// Scrolling noise to simulate dust/shimmer
	vec2 noise_uv = vec2(UV.x, UV.y * 0.5);
	noise_uv.y -= TIME * noise_speed;
	float n = noise(noise_uv * noise_scale) * 0.35 + 0.65;
	
	float alpha = vertical_fade * horizontal_fade * edge_fade * n * ray_color.a * alpha_multiplier;
	
	ALBEDO = ray_color.rgb;
	ALPHA = alpha;
}
