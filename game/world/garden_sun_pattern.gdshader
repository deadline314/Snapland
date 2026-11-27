shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// Louvred sunlight on a plant bed: bright bars between the blades' shadows.
// With `spill` on, the same bars fall softly on the floor around the bed.

uniform vec2 bed_origin = vec2(0.0, 1.15);
uniform float bed_pitch = 2.75;
uniform float yaw = 0.0;
uniform float gain = 0.55;
uniform bool spill = false;
uniform vec4 light_color : source_color = vec4(1.0, 0.82, 0.38, 1.0);
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
	// Bars are cut on the same grain as the paving so the light reads as painted.
	vec2 grain_uv = floor(UV * vec2(40.0, 28.0)) / vec2(40.0, 28.0);
	float bands = abs(fract((grain_uv.y + yaw * (grain_uv.x - 0.5) * 0.38) * 5.0) - 0.5);
	float slats = 1.0 - smoothstep(0.24, 0.3, bands);
	ALBEDO = light_color.rgb;
	ALPHA = (spill ? (1.0 - on_bed) * 0.8 : on_bed) * aperture * (0.2 + 0.8 * slats) * gain * 2.0;
}
