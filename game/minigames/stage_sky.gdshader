shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Backdrop for side-on minigame dioramas: a stepped sky gradient with dithered
// band edges, slow two-tone clouds and a hazy far shore, all on a pixel grid.
// It replaces the single flat background colour behind the play area.

uniform vec4 zenith : source_color = vec4(0.42, 0.68, 0.82, 1.0);
uniform vec4 horizon : source_color = vec4(0.83, 0.92, 0.9, 1.0);
uniform vec4 cloud : source_color = vec4(0.98, 0.97, 0.92, 1.0);
uniform vec4 shore : source_color = vec4(0.45, 0.63, 0.66, 1.0);
// World height of the sea horizon and how far above it the gradient runs.
uniform float horizon_height = 0.0;
uniform float span = 6.0;
uniform float motion = 1.0;
uniform float texels_per_metre = 14.0;

varying vec3 world_position;

float sky_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float sky_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(sky_hash(cell), sky_hash(cell + vec2(1.0, 0.0)), blend.x), mix(sky_hash(cell + vec2(0.0, 1.0)), sky_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float cloud_field(vec2 p, float drift) {
	return sky_noise(vec2(p.x * 0.3 + drift, p.y * 1.5)) * 0.62 + sky_noise(vec2(p.x * 0.85 + drift * 1.7, p.y * 3.2 + 4.0)) * 0.38;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 texel = floor(world_position.xy * texels_per_metre);
	vec2 p = texel / texels_per_metre;
	float height = clamp((p.y - horizon_height) / span, 0.0, 1.0);
	float step_at = height * 6.0;
	float band = floor(step_at);
	// Checker dither on the upper part of each band softens the steps.
	if (fract(step_at) > 0.7 && mod(texel.x + texel.y, 2.0) < 1.0) {
		band += 1.0;
	}
	vec3 color = mix(horizon.rgb, zenith.rgb, clamp(band / 6.0, 0.0, 1.0));
	float drift = TIME * motion * 0.035;
	float body = cloud_field(p, drift) * smoothstep(0.08, 0.3, height) * (1.0 - smoothstep(0.75, 1.0, height));
	if (body > 0.52) {
		// The underside of each cloud is a shade darker than its lit top.
		float lit = step(0.52, cloud_field(p + vec2(0.0, 0.16), drift) * smoothstep(0.08, 0.3, height));
		color = mix(color, mix(mix(cloud.rgb, zenith.rgb, 0.3), cloud.rgb, lit), 0.9);
	}
	float ridge = horizon_height + 0.1 + sky_noise(vec2(p.x * 0.24, 3.0)) * 0.6 * smoothstep(0.35, 0.6, sky_noise(vec2(p.x * 0.07, 9.0)));
	if (p.y < ridge) {
		color = mix(shore.rgb, horizon.rgb, 0.3 + 0.2 * step(ridge - 0.14, p.y));
	}
	ALBEDO = color;
}
