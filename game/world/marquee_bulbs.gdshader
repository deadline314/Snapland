shader_type spatial;
render_mode unshaded, shadows_disabled;
// Marquee and string-light bulbs. The instance colour is the bulb's tint and its
// alpha the bulb's place in the run (0..1). `chase` > 0 makes every third bulb
// light in a travelling wave; at 0 the bulbs only shimmer. `level` follows the
// time of day and with motion at 0 every bulb glows steadily.

uniform float level = 1.0;
uniform float chase = 0.0;
uniform float motion = 1.0;

varying vec4 bulb;

void vertex() {
	bulb = COLOR;
}

void fragment() {
	float step_at = bulb.a * 64.0;
	float lit = 0.8;
	if (motion > 0.0) {
		if (chase > 0.0) {
			lit = 0.35 + 0.65 * step(0.66, fract(step_at / 3.0 - TIME * motion * chase));
		} else {
			lit = 0.72 + 0.28 * sin(TIME * motion * 2.3 + step_at * 2.4);
		}
	}
	ALBEDO = bulb.rgb * (0.55 + level * lit);
}
