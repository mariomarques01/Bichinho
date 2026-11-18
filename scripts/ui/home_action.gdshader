shader_type canvas_item;

uniform vec4 light : source_color;
uniform vec4 deep : source_color;

float round_plate(vec2 p, vec2 extents, float radius) {
	vec2 q = abs(p) - extents + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 position = vec2((UV.x - 0.5) * 2.3333, UV.y - 0.47);
	float edge = round_plate(position, vec2(1.13, 0.435), 0.31);
	float aa = max(fwidth(edge), 0.004);
	float fill_mask = 1.0 - smoothstep(-aa, aa, edge);
	float shadow = (1.0 - smoothstep(-0.01, 0.046, round_plate(position - vec2(0.0, 0.05), vec2(1.13, 0.437), 0.32))) * 0.62;
	vec3 paint = mix(light.rgb, deep.rgb, smoothstep(0.02, 0.88, UV.y));
	float gloss = (1.0 - smoothstep(0.10, 0.43, UV.y)) * 0.26;
	paint = mix(paint, vec3(1.0), gloss);
	float rim = smoothstep(-0.043, -0.012, edge);
	vec3 border = mix(light.rgb * 0.68, mix(light.rgb, vec3(1.0), 0.49), 1.0 - UV.y);
	paint = mix(paint, border, rim);
	float bottom = smoothstep(0.81, 0.92, UV.y);
	paint *= 1.0 - 0.23 * bottom;
	COLOR = vec4(mix(vec3(0.10, 0.025, 0.16), paint, fill_mask), max(fill_mask, shadow));
}
