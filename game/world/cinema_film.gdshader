shader_type spatial;
render_mode unshaded, cull_back;
// The picture on the Starlight Cinema's open-air screen: four short looping
// films drawn on a coarse pixel grid (a gull stealing a fish by moonlight, a
// crab dancing on a beach, a ferris wheel turning at sunset, a runner chasing
// a ball over the dunes), with an old film's flicker, grain, scratches and a
// soft vignette. `leader` shows the countdown leader while a reel is changed.
// With motion at 0 the picture holds one still frame.

uniform float motion = 1.0;
uniform int reel = 0;
uniform float brightness = 0.7;
uniform float leader = 0.0;

const vec2 GRID = vec2(150.0, 66.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float disc(vec2 p, vec2 c, float r) {
	return step(length((p - c) * vec2(GRID.x / GRID.y, 1.0)), r);
}

float box(vec2 p, vec2 lo, vec2 hi) {
	return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y);
}

vec3 gull_thief(vec2 p, float t) {
	vec3 sky = mix(vec3(0.08, 0.12, 0.3), vec3(0.18, 0.32, 0.5), p.y);
	vec3 col = sky;
	col = mix(col, vec3(1.0, 0.95, 0.75), disc(p, vec2(0.78, 0.78), 0.12));
	float sea = step(p.y, 0.36 + 0.015 * sin(p.x * 30.0 + t * 1.5));
	col = mix(col, vec3(0.1, 0.25, 0.42), sea);
	col = mix(col, vec3(0.7, 0.85, 0.9), sea * step(0.94, fract(p.x * 9.0 + p.y * 3.0 + t * 0.3)) * step(0.2, p.y));
	float bob = 0.02 * sin(t * 1.8);
	vec2 boat = p - vec2(0.3, 0.33 + bob);
	col = mix(col, vec3(0.55, 0.3, 0.2), box(boat, vec2(-0.09, 0.0), vec2(0.09, 0.05)) * step(abs(boat.x) * 0.35, boat.y + 0.02));
	col = mix(col, vec3(0.95, 0.92, 0.85), box(boat, vec2(-0.003, 0.05), vec2(0.004, 0.2)));
	col = mix(col, vec3(0.95, 0.92, 0.85), step(0.0, boat.x) * step(boat.x, 0.08) * step(0.07, boat.y) * step(boat.y, 0.2 - boat.x * 1.6));
	// The gull flaps across with a fish in its beak.
	float x = fract(t * 0.07) * 1.4 - 0.2;
	vec2 g = p - vec2(x, 0.62 + 0.04 * sin(t * 2.0));
	float flap = 0.05 * sin(t * 9.0);
	float wing = step(abs(g.y - abs(g.x) * (0.6 + flap * 8.0)), 0.012) * step(abs(g.x), 0.07);
	col = mix(col, vec3(0.97), wing);
	col = mix(col, vec3(0.95, 0.6, 0.3), box(g, vec2(0.065, -0.03), vec2(0.1, -0.005)));
	return col;
}

vec3 crab_summer(vec2 p, float t) {
	vec3 col = mix(vec3(0.62, 0.85, 0.96), vec3(0.4, 0.7, 0.92), p.y);
	col = mix(col, vec3(1.0, 0.85, 0.35), disc(p, vec2(0.18, 0.8), 0.14));
	float shore = 0.34 + 0.02 * sin(p.x * 14.0 + t * 1.2);
	col = mix(col, vec3(0.25, 0.6, 0.75), step(shore, p.y) * step(p.y, shore + 0.08));
	col = mix(col, vec3(0.95, 0.97, 1.0), step(abs(p.y - shore - 0.002), 0.008));
	col = mix(col, vec3(0.92, 0.8, 0.55), step(p.y, shore));
	float cx = 0.5 + 0.28 * sin(t * 0.7);
	vec2 c = p - vec2(cx, 0.16 + 0.01 * abs(sin(t * 6.0)));
	float body = step(length(c * vec2(1.0, 1.9)), 0.07);
	col = mix(col, vec3(0.88, 0.3, 0.22), body);
	for (int side = -1; side <= 1; side += 2) {
		float s = float(side);
		col = mix(col, vec3(0.88, 0.3, 0.22), disc(p, vec2(cx + s * 0.09, 0.24 + 0.02 * sin(t * 4.0 + s)), 0.05));
		for (int leg = 0; leg < 3; leg++) {
			float lx = cx + s * (0.035 + float(leg) * 0.02);
			col = mix(col, vec3(0.7, 0.2, 0.15), box(p, vec2(lx - 0.004, 0.08 + 0.01 * sin(t * 12.0 + float(leg))), vec2(lx + 0.004, 0.14)));
		}
	}
	col = mix(col, vec3(1.0), disc(p, vec2(cx - 0.025, 0.2), 0.022) + disc(p, vec2(cx + 0.025, 0.2), 0.022));
	col = mix(col, vec3(0.1), disc(p, vec2(cx - 0.025, 0.2), 0.01) + disc(p, vec2(cx + 0.025, 0.2), 0.01));
	return col;
}

vec3 lost_wheel(vec2 p, float t) {
	vec3 col = mix(vec3(0.98, 0.6, 0.35), vec3(0.5, 0.3, 0.6), p.y);
	col = mix(col, vec3(1.0, 0.85, 0.5), disc(p, vec2(0.25, 0.42), 0.16) * 0.6);
	vec2 w = (p - vec2(0.6, 0.55)) * vec2(GRID.x / GRID.y, 1.0);
	float r = length(w);
	float a = atan(w.y, w.x) + t * 0.25;
	float rim = step(abs(r - 0.38), 0.018);
	float spokes = step(abs(sin(a * 6.0)), 0.06) * step(r, 0.38);
	col = mix(col, vec3(0.25, 0.15, 0.3), max(rim, spokes));
	for (int i = 0; i < 8; i++) {
		float ca = float(i) / 8.0 * 6.2832 - t * 0.25;
		vec2 cab = vec2(0.6, 0.55) + vec2(cos(ca) * 0.38 * GRID.y / GRID.x, sin(ca) * 0.38 - 0.05);
		col = mix(col, vec3(0.95, 0.4 + 0.08 * float(i % 3), 0.3), disc(p, cab, 0.035));
	}
	col = mix(col, vec3(0.2, 0.12, 0.22), step(p.y, 0.12 + 0.03 * sin(p.x * 8.0)));
	return col;
}

vec3 dune_run(vec2 p, float t) {
	vec3 col = mix(vec3(0.98, 0.9, 0.7), vec3(0.55, 0.78, 0.95), p.y);
	float far_dune = 0.35 + 0.06 * sin(p.x * 7.0 + 1.0);
	col = mix(col, vec3(0.88, 0.72, 0.48), step(p.y, far_dune));
	float near_dune = 0.2 + 0.05 * sin(p.x * 11.0 - t * 0.4);
	col = mix(col, vec3(0.8, 0.6, 0.38), step(p.y, near_dune));
	float x = fract(t * 0.09) * 1.3 - 0.15;
	float ground = 0.2 + 0.05 * sin(x * 11.0 - t * 0.4);
	float ball_x = x + 0.12;
	float ball_y = ground + 0.05 + 0.18 * abs(sin(t * 3.0));
	col = mix(col, vec3(0.9, 0.3, 0.3), disc(p, vec2(ball_x, ball_y), 0.035));
	float stride = sin(t * 12.0);
	col = mix(col, vec3(0.2, 0.25, 0.4), box(p, vec2(x - 0.008, ground + 0.05), vec2(x + 0.008, ground + 0.15)));
	col = mix(col, vec3(0.2, 0.25, 0.4), step(abs(p.x - x - stride * (p.y - ground - 0.05) * -0.4), 0.006) * box(p, vec2(x - 0.05, ground), vec2(x + 0.05, ground + 0.05)));
	col = mix(col, vec3(0.98, 0.8, 0.6), disc(p, vec2(x, ground + 0.19), 0.035));
	return col;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * motion;
	// Gate weave: the frame hops a pixel now and then.
	float frame = floor(t * 12.0);
	uv.y += (hash(vec2(frame, 1.0)) > 0.85 ? 1.0 : 0.0) / GRID.y;
	vec2 p = floor(uv * GRID) / GRID;
	vec3 col;
	if (reel == 1) col = crab_summer(p, t);
	else if (reel == 2) col = lost_wheel(p, t);
	else if (reel == 3) col = dune_run(p, t);
	else col = gull_thief(p, t);
	// Old film: flicker, grain, a scratch or two and a warm, darkened edge.
	float flicker = 0.92 + 0.08 * hash(vec2(frame, 7.0));
	float grain = (hash(p * 311.0 + frame) - 0.5) * 0.08;
	float scratch_x = hash(vec2(frame, 3.0));
	float scratch = step(abs(uv.x - scratch_x), 0.003) * step(0.7, hash(vec2(frame, 5.0)));
	col = col * flicker + grain + scratch * 0.3;
	vec2 edge = uv - 0.5;
	col *= 1.0 - dot(edge, edge) * 0.9;
	col = mix(col, col * vec3(1.05, 0.98, 0.86), 0.35);
	if (leader > 0.0) {
		// The countdown leader: grey rings and a sweeping hand.
		vec2 c = (uv - 0.5) * vec2(GRID.x / GRID.y, 1.0);
		float hand = step(abs(fract(atan(c.y, c.x) / 6.2832 + t * 1.5) - 0.5), 0.01);
		float rings = step(abs(length(c) - 0.3), 0.012) + step(abs(length(c) - 0.42), 0.008);
		vec3 lead = vec3(0.72) + vec3(0.2) * max(hand, rings) - vec3(0.25) * step(length(c), 0.3) * step(0.5, fract(atan(c.y, c.x) / 6.2832 + t * 1.5));
		col = mix(col, lead, leader);
	}
	ALBEDO = col * brightness;
}
