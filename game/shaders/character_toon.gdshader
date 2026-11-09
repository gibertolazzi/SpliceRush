shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 base_color : source_color = vec4(0.45, 0.1, 0.78, 1.0);
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.95);
uniform float rim_power : hint_range(0.5, 8.0) = 2.8;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
uniform float emission_boost : hint_range(0.0, 3.0) = 0.08;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.45;
	METALLIC = 0.05;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = base_color.rgb * emission_boost + rim_color * (rim * rim_strength);
}
