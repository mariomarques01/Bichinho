shader_type canvas_item;

// Motion stays within the painted pet, blanket and sleep glyphs.
uniform float sleeping : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 body_pos = (UV - vec2(0.49, 0.448)) / vec2(0.37, 0.133);
	float body = 1.0 - smoothstep(0.23, 1.0, length(body_pos));
	vec2 dream_pos = (UV - vec2(0.601, 0.28)) / vec2(0.137, 0.065);
	float dream = 1.0 - smoothstep(0.33, 1.0, length(dream_pos));
	float breathe = sin(TIME * 2.06) * mix(0.0038, 0.0075, sleeping);
	float drift = sin(TIME * 2.25) * mix(0.0035, 0.009, sleeping);
	vec2 sample_uv = UV + vec2(breathe * body_pos.x * body * 0.65, breathe * body + drift * dream);
	vec4 art = texture(TEXTURE, sample_uv);
	float glow = dream * clamp((art.b - art.r) * 2.0, 0.0, 1.0) * smoothstep(0.47, 0.73, art.g);
	art.rgb *= 1.0 + glow * (0.09 + 0.08 * sin(TIME * 2.25));
	COLOR = art;
}
