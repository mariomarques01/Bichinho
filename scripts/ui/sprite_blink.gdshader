shader_type canvas_item;

uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform float mouth_shape = 0.0;
uniform vec2 mouth_center;
uniform vec4 left_eye;
uniform vec4 right_eye;
uniform vec4 lid_color : source_color = vec4(0.18, 0.77, 0.79, 1.0);

vec2 paint_lid(vec2 pixel, vec4 eye) {
	vec2 at = (pixel - eye.xy) / eye.zw;
	float inside = 1.0 - smoothstep(0.90, 1.05, length(at));
	float arc = -0.10 - 0.26 * (1.0 - at.x * at.x);
	float edge = mix(-1.13, 1.23, closure) + 0.12 * (1.0 - at.x * at.x);
	float cover = (1.0 - smoothstep(edge - 0.11, edge, at.y)) * inside;
	float lash = (1.0 - smoothstep(0.060, 0.13, abs(at.y - arc))) *
		(1.0 - smoothstep(0.70, 0.91, abs(at.x))) * smoothstep(0.65, 0.95, closure);
	return vec2(cover, lash);
}

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 offset = UV - mouth_center;
	float mask = 1.0 - smoothstep(0.5, 1.0, length(offset / vec2(0.15, 0.11)));
	vec2 warp = vec2(offset.x * min(mouth_shape, 0.0) * 0.32, -offset.y * max(mouth_shape, 0.0) * 0.58);
	vec4 base = texture(TEXTURE, UV + warp * mask) * tint;
	if (closure > 0.0 && base.a > 0.0) {
		vec2 left = paint_lid(UV, left_eye);
		vec2 right = paint_lid(UV, right_eye);
		vec2 lid = max(left, right);
		vec3 skin = lid_color.rgb * mix(1.07, 0.92, UV.y);
		base.rgb = mix(base.rgb, skin, lid.x);
		base.rgb = mix(base.rgb, vec3(0.095, 0.042, 0.18), lid.y);
	}
	COLOR = base;
}
