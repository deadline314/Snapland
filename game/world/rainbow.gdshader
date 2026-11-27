shader_type spatial;
// The rainbow after the afternoon shower: a soft seven-band arc on a quad
// that faces the camera. It sits a few metres behind the walker, so the
// walker and nearby trees stand in front of it and the land closer to the
// camera hides its feet, as if it rose from the far side of the island.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Inner and outer radius of the band, as a share of the quad's half width.
uniform float inner = 0.74;
uniform float outer = 0.97;

vec3 band(float t) {
	// Red outside, violet inside; pastel so it sits in the painted palette.
	vec3 colours[7] = vec3[](vec3(0.98, 0.42, 0.40), vec3(1.0, 0.66, 0.36), vec3(1.0, 0.90, 0.46),
		vec3(0.55, 0.86, 0.48), vec3(0.42, 0.78, 0.96), vec3(0.48, 0.55, 0.95), vec3(0.72, 0.50, 0.92));
	float x = clamp(t, 0.0, 0.999) * 6.0;
	int index = int(floor(x));
	return mix(colours[index], colours[min(index + 1, 6)], smoothstep(0.25, 0.75, fract(x)));
}

void fragment() {
	// Arc centre on the quad's bottom edge.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float r = length(p);
	float t = (outer - r) / (outer - inner);
	float body = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.88, 1.0, t));
	// Brighter overhead, fading toward the feet and fully gone at the ground line.
	float rise = smoothstep(0.0, 0.55, p.y);
	ALBEDO = band(t);
	ALPHA = body * rise * strength * 0.55;
}
