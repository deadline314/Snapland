shader_type spatial;
// A firework's light on the bay: a shimmering streak of colour lying on the
// water under the burst, stretched toward the camera like a reflection.
// Additive, so overlapping bursts mix. The script owns the clock.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float clock = 0.0;
instance uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
instance uniform float strength = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Soft on every side, so the quad's edges never show.
	float across = 1.0 - smoothstep(0.0, 1.0, abs(p.x));
	across *= across * across;
	float along = 1.0 - smoothstep(0.35, 1.0, abs(p.y));
	// Broken into glints by the swell.
	float swell = sin(UV.y * 38.0 + clock * 4.0 + sin(UV.x * 7.0 + clock * 1.3) * 2.0);
	float glints = 0.55 + 0.45 * smoothstep(0.1, 0.9, swell);
	ALBEDO = glow_color.rgb * across * along * glints * strength * 0.9;
}
