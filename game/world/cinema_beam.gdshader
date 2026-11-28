shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// A beam of light through dusty air: the projector's throw to the screen and
// the searchlights sweeping the night. UV.y runs from the lamp (0) to the far
// end (1); the beam fades along its length and toward its silhouette edges,
// and dust drifts through it. With motion at 0 the dust holds still.

uniform vec4 tint : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float strength = 0.4;
uniform float fade_power = 0.8;
uniform float motion = 1.0;

varying vec3 world_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = pow(1.0 - clamp(UV.y, 0.0, 1.0), fade_power);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.05, 0.75, facing);
	vec3 cell = floor(world_position * 5.0 + vec3(0.0, TIME * motion * 0.6, 0.0));
	float dust = 0.82 + 0.35 * step(0.93, hash(cell));
	ALBEDO = tint.rgb * strength * along * edge * dust;
}
