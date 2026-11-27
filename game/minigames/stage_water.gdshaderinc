// Water for the minigame dioramas. Top faces carry posterised swell bands,
// drifting crests and glints on a pixel grid (the shared island sea motion);
// side faces, seen when a tank or lock is cut open, darken with depth.
// stage_water.gdshader is opaque; stage_water_glass.gdshader defines
// SEE_THROUGH so hulls below the waterline stay visible.

#include "res://game/world/sea_motion.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.2, 0.44, 0.5, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.94, 0.88, 1.0);
uniform float motion = 1.0;
// Dioramas are a few metres across, so waves are finer than on the island.
uniform float wave_scale = 2.2;
uniform float texels_per_metre = 12.0;
#ifdef SEE_THROUGH
uniform float opacity = 0.78;
#endif

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME * motion;
	if (abs(world_normal.y) > 0.5) {
		vec2 texel = floor(world_position.xz * texels_per_metre);
		vec2 p = texel / texels_per_metre * wave_scale;
		float bands = floor((sea_swell(p, t) * 0.5 + 0.5) * 4.0) / 3.0;
		vec3 base = water_color.rgb * (0.86 + bands * 0.2) * (0.98 + wind_hash(texel) * 0.04);
		float light = sea_crests(p, t, 0.7) * 0.7 + sea_glints(p, t) * 0.65 + sea_ripples(p, t) * 0.3;
		ALBEDO = mix(base, foam_color.rgb, clamp(light, 0.0, 0.85));
	} else {
		// Box meshes map every side face top to bottom across half the UV height;
		// screen derivatives turn that into metres, so a tall tank and a thin
		// lock chamber get the same surface line and the same fall into the deep.
		float depth = fract(UV.y * 2.0);
		float metres = depth * abs(dFdy(world_position.y)) / max(0.00001, abs(dFdy(UV.y) * 2.0));
		vec2 texel = floor(vec2(world_position.x + world_position.z, world_position.y) * texels_per_metre);
		float sway = floor(t * 0.8);
		float glint = step(0.975, wind_hash(floor(vec2(texel.x / 5.0, texel.y)) + vec2(sway, 0.0))) * step(0.15, metres);
		float ripple = step(0.5, fract(texel.y * 0.25 + sin(texel.x * 0.12 + t) * 0.25)) * 0.03;
		vec3 body = water_color.rgb * (mix(1.04, 0.62, clamp(metres / 2.5, 0.0, 1.0)) + ripple) * (0.97 + wind_hash(texel) * 0.05);
		float surface = step(metres, 1.5 / texels_per_metre);
		ALBEDO = mix(body, foam_color.rgb, surface * 0.55 + glint * 0.2 * (1.0 - clamp(metres / 2.0, 0.0, 1.0)));
	}
#ifdef SEE_THROUGH
	ALPHA = opacity;
#endif
	ROUGHNESS = 0.5;
	SPECULAR = 0.2;
}
