shader_type canvas_item;
uniform bool idle = false;

vec2 sway(vec2 uv, vec2 base, vec2 center, vec2 radii, float angle) {
	float weight = 1.0 - smoothstep(0.62, 1.0, length((uv-center)/radii));
	float a = angle * weight;
	vec2 d = uv - base;
	return base + mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d;
}

varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	if (idle) {
		uv = sway(uv, vec2(0.65,0.81), vec2(0.75,0.71), vec2(0.094,0.135), 0.06*sin(TIME*2.3));
		uv = sway(uv, vec2(0.32,0.42), vec2(0.27,0.37), vec2(0.09,0.13), 0.035*sin(TIME*2.1));
		uv = sway(uv, vec2(0.67,0.42), vec2(0.74,0.37), vec2(0.09,0.13), -0.035*sin(TIME*2.1));
	}
	COLOR = texture(TEXTURE, uv) * tint;
}
