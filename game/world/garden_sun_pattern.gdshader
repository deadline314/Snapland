shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec2 bed_origin = vec2(0.0, 1.15);
uniform float bed_pitch = 2.75;
uniform float yaw = 0.0;
uniform float gain = 0.55;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 bed_uv = world.xz - bed_origin;
	float slot = clamp(round(bed_uv.x / bed_pitch), -1.0, 1.0);
	vec2 from_bed = bed_uv - vec2(slot * bed_pitch, 0.0);
	float on_bed = (1.0 - smoothstep(0.89, 0.96, abs(from_bed.x))) * (1.0 - smoothstep(0.49, 0.56, abs(from_bed.y)));
	float aperture = 1.0 - smoothstep(0.40, 1.0, length((UV - vec2(0.5)) * vec2(1.85, 1.8)));
	float bands = abs(fract((UV.y + yaw * (UV.x - 0.5) * 0.38) * 5.0) - 0.5);
	float slats = 1.0 - smoothstep(0.25, 0.38, bands);
	ALBEDO = vec3(1.0, 0.80, 0.34);
	ALPHA = on_bed * aperture * slats * gain;
}
