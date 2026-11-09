shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 beam_color : source_color = vec4(1.0, 0.76, 0.18, 1.0);
uniform float pulse_speed : hint_range(0.5, 8.0) = 2.5;

void fragment() {
	float v_fade = clamp(1.0 - UV.y, 0.0, 1.0);
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed + UV.y * 6.0);
	float edge = sin(UV.x * 3.14159265);
	ALBEDO = beam_color.rgb * (v_fade * v_fade * pulse * (0.45 + 0.55 * edge));
	ALPHA = clamp(v_fade * 0.78 * pulse, 0.0, 1.0);
}
