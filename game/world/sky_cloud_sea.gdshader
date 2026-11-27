shader_type spatial;
render_mode diffuse_burley, cull_back;
// The sea of cloud the Cloud Park's walkways float over: soft billows that
// drift slowly downwind, posterised into a few tones on the world's pixel
// grain. Bounded (on the island) it ends in a ragged edge inside the park's
// claim, so it never meets the lawn at a straight line; with motion at 0 it
// holds one still pose.

uniform float motion = 1.0;
uniform bool bounded = true;
// Object-space rect (min x, min z, max x, max z) the cloud keeps inside.
uniform vec4 bounds = vec4(-22.0, -18.0, 22.0, 18.0);
uniform float edge_depth = 3.2;
uniform vec4 top_tone : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mid_tone : source_color = vec4(0.91, 0.95, 1.0, 1.0);
uniform vec4 low_tone : source_color = vec4(0.78, 0.85, 0.96, 1.0);

const float TEXEL = 0.0625;
const vec2 WIND = vec2(0.86, 0.51);

varying vec2 local_xz;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	vec2 grain = floor(local_xz / TEXEL) * TEXEL;
	if (bounded) {
		float inside = min(min(grain.x - bounds.x, bounds.z - grain.x), min(grain.y - bounds.y, bounds.w - grain.y));
		float ragged = edge_depth * (0.25 + 0.75 * noise(grain * 0.35 + vec2(7.0, 3.0)));
		if (inside < ragged) {
			discard;
		}
	}
	vec2 drift = WIND * TIME * motion * 0.35;
	float billow = noise((grain - drift) * 0.22) * 0.6 + noise((grain - drift * 1.6) * 0.61 + vec2(11.0, 5.0)) * 0.4;
	float tone = floor(billow * 3.0 + 0.35) / 2.0;
	vec3 colour = tone >= 1.0 ? top_tone.rgb : (tone >= 0.5 ? mid_tone.rgb : low_tone.rgb);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
