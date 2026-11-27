shader_type canvas_item;
// Ticket-punch iris: a scalloped, pixel-stepped circle that closes over the
// view. `plain_fade` swaps it for a flat fade when motion is reduced.

uniform float closed : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.03, 0.1, 0.14, 1.0);
uniform vec4 accent : source_color = vec4(0.44, 0.78, 0.72, 1.0);
uniform float aspect = 1.7778;
uniform bool plain_fade = false;

const float CELL = 0.012;
const float MAX_RADIUS = 1.08;
const float RIM = 0.018;

void fragment() {
	if (plain_fade) {
		COLOR = vec4(ink.rgb, closed);
	} else {
		vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
		p = (floor(p / CELL) + 0.5) * CELL;
		float scallop = 0.014 * sin(atan(p.y, p.x) * 22.0);
		float radius = (1.0 - closed) * MAX_RADIUS;
		float distance_out = length(p) + scallop - radius;
		float cover = step(0.0, distance_out);
		// A thin lighter rim just inside the cover reads as a punched paper edge.
		float rim = cover * (1.0 - step(RIM, distance_out)) * step(0.001, closed) * (1.0 - step(0.999, closed));
		COLOR = vec4(mix(ink.rgb, accent.rgb, rim * 0.85), cover);
	}
}
