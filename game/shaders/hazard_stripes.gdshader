shader_type spatial;

uniform vec4 color_yellow : source_color = vec4(1.0, 0.768, 0.0, 1.0);
uniform vec4 color_black : source_color = vec4(0.102, 0.102, 0.12, 1.0);
uniform float stripe_freq : hint_range(1.0, 20.0) = 6.0;

void fragment() {
	float pattern = fract((UV.x + UV.y) * stripe_freq);
	float mask = step(0.5, pattern);
	vec3 col = mix(color_black.rgb, color_yellow.rgb, mask);
	ALBEDO = col;
	ROUGHNESS = 0.55;
}
