shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 beam_color : source_color = vec4(1.0, 0.78, 0.18, 0.75);
uniform float pulse_speed : hint_range(0.5, 8.0) = 2.4;

void fragment() {
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	float core = sin(clamp(UV.x, 0.0, 1.0) * 3.14159265);
	float v_fade = clamp(1.0 - UV.y * 0.45, 0.0, 1.0);
	ALBEDO = beam_color.rgb * 1.6;
	ALPHA = clamp(beam_color.a * core * v_fade * pulse, 0.0, 1.0);
}
