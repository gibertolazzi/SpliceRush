shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 rim_color : source_color = vec3(0.88, 0.72, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;
uniform float emission_boost : hint_range(0.0, 3.0) = 0.05;

// Warmth and saturation boost for skin & hands (Più colore)
uniform float skin_warmth_boost : hint_range(0.0, 1.0) = 0.50;
uniform vec3 skin_tint : source_color = vec3(1.15, 0.88, 0.76);
uniform float purple_shift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = base_color;
	if (use_texture) {
		vec4 tex = texture(albedo_texture, UV);
		col *= tex;

		// Detect pale/clay skin tones and enrich with warm golden-peach brawler pigment
		float max_c = max(col.r, max(col.g, col.b));
		float min_c = min(col.r, min(col.g, col.b));
		float sat = (max_c > 0.001) ? (max_c - min_c) / max_c : 0.0;
		if (col.r > 0.65 && col.g > 0.52 && col.b > 0.42 && sat < 0.42) {
			col.rgb = mix(col.rgb, col.rgb * skin_tint * vec3(1.12, 0.94, 0.82), skin_warmth_boost);
			float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
			col.rgb = mix(vec3(luma), col.rgb, 1.35);
		}

		// Signature hero shirt: shift the blue fabric toward the key-art violet.
		if (purple_shift > 0.001) {
			float blue_dom = smoothstep(0.02, 0.16, col.b - max(col.r, col.g));
			vec3 violet = vec3(col.r * 0.62 + 0.20, col.g * 0.50, col.b * 1.05);
			col.rgb = mix(col.rgb, violet, blue_dom * purple_shift);
		}
	}

	ALBEDO = col.rgb;
	ROUGHNESS = 0.45;
	METALLIC = 0.05;

	// Stylized Toon Rim Light (Luce di bordo)
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - n_dot_v, rim_power);
	EMISSION = col.rgb * emission_boost + rim_color * (rim * rim_strength);
}
