shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	vec2 step_px = TEXTURE_PIXEL_SIZE;
	vec3 nearby = (
		texture(TEXTURE, UV + vec2(step_px.x, 0.0)).rgb +
		texture(TEXTURE, UV - vec2(step_px.x, 0.0)).rgb +
		texture(TEXTURE, UV + vec2(0.0, step_px.y)).rgb +
		texture(TEXTURE, UV - vec2(0.0, step_px.y)).rgb
	) * 0.25;
	COLOR = vec4(clamp(center.rgb + (center.rgb - nearby) * 0.40, 0.0, 1.0), center.a);
}
