shader_type canvas_item;

// Restrict deformation to the Evolin and foam painted into the bathroom illustration.
uniform float response : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.455, 0.382);
	vec2 radial = (UV - center) / vec2(0.295, 0.146);
	float mask = 1.0 - smoothstep(0.35, 1.0, length(radial));
	float lift = sin(TIME * 2.55) * 0.0028 + response * 0.010;
	float sway = sin(TIME * 13.0) * (0.0016 + response * 0.010);
	vec2 sample_uv = UV + mask * vec2(sway * (1.0 - radial.y * 0.42), lift);
	COLOR = texture(TEXTURE, sample_uv);
}
