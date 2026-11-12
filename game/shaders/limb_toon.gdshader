shader_type spatial;
// Loose / grafted / held limbs cut out of a character mesh.
// Target: GL Compatibility (web/mobile). One pass, no textures, no branches.
// Vertex colour carries the original surface colour; alpha marks cloth that takes the owner tint.
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(0.92, 0.82, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;
uniform float emission_boost : hint_range(0.0, 3.0) = 0.10;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Vertex colours are stored in sRGB: bring them to linear like a source_color uniform.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 col = mix(base, tint_color.rgb, clamp(tint_amount * COLOR.a, 0.0, 1.0));
	col = mix(col, flash_color, flash);
	ALBEDO = col;
	ROUGHNESS = 0.45;
	METALLIC = 0.05;
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - n_dot_v, rim_power);
	EMISSION = col * (emission_boost + flash * 1.5) + rim_color * (rim * rim_strength);
}
