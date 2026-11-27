shader_type spatial;
render_mode cull_disabled;
// Wind flags and windsocks in the Cloud Park. They are built pointing
// downwind; the island's shared gusts (wind.gdshaderinc) make them snap out
// and flutter harder, so a flag shows a gust coming before it reaches the
// walker. UV2.x says how free a vertex is (0 at the staff, 1 at the loose
// end); the instance colour tints the cloth. With motion at 0 they hold still.

#include "res://game/world/wind.gdshaderinc"

uniform float motion = 1.0;
uniform float strength = 0.13;

varying vec3 tint;

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = wind_gust(anchor.xz);
	float phase = anchor.x * 1.9 + anchor.z * 2.7 + anchor.y;
	float t = TIME * motion;
	float wave = sin(t * (3.0 + gust * 4.0) + phase - UV.x * 5.0) + 0.4 * sin(t * 6.1 + phase * 1.7 - UV.x * 9.0);
	float free_end = UV2.x;
	VERTEX += NORMAL * wave * free_end * strength * (0.6 + gust * 1.4) * motion;
	// In a lull the cloth droops; in a gust it flies out flat.
	VERTEX.y -= free_end * free_end * (1.0 - gust) * 0.18;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
