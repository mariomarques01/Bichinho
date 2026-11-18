shader_type spatial;
render_mode blend_mix, depth_draw_never;

uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lid_color : source_color = vec4(0.12, 0.80, 0.72, 1.0);
uniform vec4 lash_color : source_color = vec4(0.14, 0.045, 0.24, 1.0);
varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	// Match the painted eyes in the model's front projection from the room camera.
	vec2 face = vec2(abs(model_position.x), model_position.y - 0.248 * model_position.z);
	vec2 eye = (face - vec2(0.291, 0.048)) / vec2(0.194, 0.179);
	float mask = 1.0 - smoothstep(0.92, 1.04, length(eye));
	float edge = mix(1.12, -1.08, closure) + 0.26 * (1.0 - eye.x * eye.x);
	float coverage = mask * smoothstep(edge - 0.07, edge + 0.04, eye.y);
	if (closure <= 0.0 || model_position.z < 0.24 || coverage < 0.01) {
		discard;
	}
	float lash_y = max(edge, -0.08 + 0.43 * (1.0 - eye.x * eye.x));
	float lash = (1.0 - smoothstep(0.044, 0.098, abs(eye.y - lash_y)))
		* (1.0 - smoothstep(0.70, 0.93, abs(eye.x))) * smoothstep(0.65, 0.91, closure);
	ALBEDO = mix(lid_color.rgb, lash_color.rgb, lash);
	ROUGHNESS = 0.80;
	ALPHA = coverage;
}
