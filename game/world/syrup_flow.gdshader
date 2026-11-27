shader_type spatial;
// Thick glossy syrup that creeps along a ribbon mesh. UV is in metres (x across,
// y downstream) and UV2.x runs bank to bank. Slow folds, bright glints and a
// creamy foam line at both banks all travel with the flow; with motion at 0 the
// surface holds one still frame.

uniform vec4 deep_color : source_color = vec4(0.66, 0.33, 0.09, 1.0);
uniform vec4 light_color : source_color = vec4(0.93, 0.62, 0.19, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.86, 0.58, 1.0);
uniform float flow_speed = 0.35;
uniform float motion = 1.0;
// Raised at dusk and night so the river carries a faint warm light.
uniform float glow = 0.0;

const float TEXEL = 0.125;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(cell_hash(cell), cell_hash(cell + vec2(1.0, 0.0)), blend.x), mix(cell_hash(cell + vec2(0.0, 1.0)), cell_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	float travel = TIME * motion * flow_speed;
	// The middle of the stream runs ahead of the banks.
	float lane = 1.0 - abs(UV2.x * 2.0 - 1.0);
	vec2 stream = floor(vec2(UV.x, UV.y - travel * (0.55 + 0.45 * lane)) / TEXEL) * TEXEL;
	float folds = soft_noise(stream * vec2(1.3, 0.42)) * 0.62 + soft_noise(stream * vec2(2.9, 0.9) + vec2(17.0, 4.0)) * 0.38;
	float tone = floor(folds * 4.0) / 3.0;
	vec3 syrup = mix(deep_color.rgb, light_color.rgb, clamp(tone, 0.0, 1.0));
	// Long glints ride the crests of the folds.
	float crest = smoothstep(0.69, 0.71, folds) * (1.0 - smoothstep(0.72, 0.74, folds));
	float sparkle = step(0.55, cell_hash(floor(stream * vec2(1.0, 0.35) / TEXEL)));
	syrup = mix(syrup, glint_color.rgb, crest * sparkle * 0.9);
	// Banks: a darker edge under a broken line of cream foam.
	float bank = 1.0 - smoothstep(0.0, 0.16, lane);
	syrup *= 1.0 - bank * 0.28;
	float foam = step(lane, 0.05 + 0.035 * soft_noise(vec2(stream.y * 1.7, UV2.x * 3.0))) * step(0.35, soft_noise(vec2(stream.y * 0.9, 3.0)));
	syrup = mix(syrup, glint_color.rgb, foam * 0.7);
	ALBEDO = syrup * 0.72;
	ROUGHNESS = 0.22;
	SPECULAR = 0.6;
	EMISSION = syrup * glow;
}
