shader_type spatial;
render_mode blend_mix, depth_draw_never;

uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lid_color : source_color = vec4(0.14, 0.65, 0.62, 1.0);
uniform vec4 lash_color : source_color = vec4(0.14, 0.045, 0.24, 1.0);
uniform float smile : hint_range(0.0, 1.0) = 0.0;
uniform float yawn = 0.0;
varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	// Match the painted eyes in the model's front projection from the room camera.
	vec2 face = vec2(abs(model_position.z), model_position.y - 0.248 * model_position.x);
	vec2 eye = (face - vec2(0.142, 0.478)) / vec2(0.094, 0.093);
	float mask = 1.0 - smoothstep(0.92, 1.04, length(eye));
	float edge = mix(1.12, -1.08, closure) + 0.26 * (1.0 - eye.x * eye.x);
	float coverage = mask * smoothstep(edge - 0.07, edge + 0.04, eye.y);
	vec2 mouth = (face - vec2(0.0, 0.359)) / vec2(0.061, 0.032);
	float grin = (1.0 - smoothstep(0.08, 0.23, abs(mouth.y + 0.25 - mouth.x * mouth.x * 0.7)))
		* (1.0 - smoothstep(0.84, 1.0, mouth.x));
	float opening = 1.0 - smoothstep(0.82, 1.0, length(mouth / vec2(0.55, 0.2 + yawn)));
	float lips = max(smile * grin, opening * yawn);
	coverage *= step(0.001, closure);
	if (model_position.x < 0.10 || max(coverage, lips) < 0.01) {
		discard;
	}
	float lash_y = max(edge, -0.08 + 0.43 * (1.0 - eye.x * eye.x));
	float lash = (1.0 - smoothstep(0.044, 0.098, abs(eye.y - lash_y)))
		* (1.0 - smoothstep(0.70, 0.93, abs(eye.x))) * smoothstep(0.65, 0.91, closure);
	ALBEDO = mix(lid_color.rgb, lash_color.rgb, max(lash, lips));
	ROUGHNESS = 0.80;
	ALPHA = max(coverage, lips);
}
