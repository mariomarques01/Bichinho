shader_type canvas_item;
uniform vec4 growth_tint : source_color = vec4(1.0);
uniform float growth_factor = 1.0;

// Restrict deformation to the Evolin and foam painted into the bathroom illustration.
uniform sampler2D atlas_art : source_color, filter_linear;
uniform float opening : hint_range(0.0, 1.0) = 0.0;
uniform float response : hint_range(0.0, 1.0) = 0.0;

vec4 eye_from_atlas(vec2 pixel, vec2 center, vec2 extent, vec2 source, vec2 source_extent) {
	vec2 point = (pixel - center) / extent;
	float mask = 1.0 - smoothstep(0.77, 1.0, length(point));
	vec2 sample_pos = (source + point * source_extent) / vec2(1280.0, 853.0);
	return vec4(texture(atlas_art, sample_pos).rgb, mask);
}

void fragment() {
	vec2 center = vec2(0.455, 0.382);
	vec2 radial = (UV - center) / vec2(0.295, 0.146);
	float mask = 1.0 - smoothstep(0.35, 1.0, length(radial));
	float lift = sin(TIME * 2.55) * 0.0028 + response * 0.010;
	float sway = sin(TIME * 13.0) * (0.0016 + response * 0.010);
	vec2 sample_uv = UV + mask * vec2(sway * (1.0 - radial.y * 0.42), lift);
	sample_uv += (UV - center) * (1.0 / growth_factor - 1.0) * mask;
	vec4 bath = texture(TEXTURE, sample_uv);
	float eyes_open = opening * (1.0 - smoothstep(0.03, 0.45, response));
	if (eyes_open > 0.0) {
		vec2 pixel = sample_uv * vec2(720.0, 1280.0);
		vec4 left = eye_from_atlas(pixel, vec2(300.0, 468.0), vec2(46.0, 39.0), vec2(109.0, 88.0), vec2(28.0, 25.0));
		vec4 right = eye_from_atlas(pixel, vec2(422.0, 441.0), vec2(33.0, 31.0), vec2(168.0, 82.0), vec2(20.0, 22.0));
		bath.rgb = mix(bath.rgb, left.rgb, left.a * eyes_open);
		bath.rgb = mix(bath.rgb, right.rgb, right.a * eyes_open);
	}
	bath.rgb *= mix(vec3(1.0), growth_tint.rgb, mask);
	COLOR = bath;
}
