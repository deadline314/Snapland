shader_type spatial;
render_mode cull_disabled;
// Vertex-coloured plants drawn in batches: vines, hanging baskets, reeds, ferns
// and flowers. Each instance bends about its own origin with the shared island
// wind, more the further a vertex is from that origin, so hanging things swing
// and rooted things sway. `fold` makes leaves close up and droop when the walker
// brushes past (touch-me-not); `emission` lets night plants glow.

#include "res://game/world/wind.gdshaderinc"

uniform float flex = 0.12;
uniform float fold = 0.0;
uniform float bloom = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float reach = abs(VERTEX.y);
	float phase = root.x * 1.9 + root.z * 2.7;
	float gust = wind_gust(root.xz);
	float sway = (sin(snapland_wind_time * 1.3 + phase) * (0.5 + gust) + gust * 1.4) * flex * reach * reach;
	vec3 local = VERTEX;
	if (fold > 0.0) {
		float touched = walker_brush(root.xz, 1.5) * fold;
		local.xz *= 1.0 - 0.62 * touched;
		local.y *= 1.0 - 0.3 * touched;
	}
	// Flower heads (painted with alpha below 1) open with `bloom`.
	if (COLOR.a < 0.99) {
		local.xz *= mix(0.35, 1.0, bloom);
	}
	// Lean along the wind in world space, whatever the instance's rotation.
	vec3 lean = (inverse(MODEL_MATRIX) * vec4(WIND_DIRECTION.x, 0.0, WIND_DIRECTION.y, 0.0)).xyz;
	VERTEX = local + lean * sway;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.85;
	EMISSION = emission_color.rgb * emission_energy;
}
