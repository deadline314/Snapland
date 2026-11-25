shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D stone_atlas : source_color, filter_linear, repeat_disable;
uniform bool has_stone_atlas = false;
uniform bool rooftop = false;
uniform vec4 stone_tint : source_color = vec4(0.63, 0.65, 0.69, 1.0);
uniform vec4 reflected_sky : source_color = vec4(0.29, 0.38, 0.52, 1.0);
uniform vec4 west_lantern : source_color = vec4(1.0);
uniform vec4 east_lantern : source_color = vec4(1.0);
uniform vec4 roof_lantern : source_color = vec4(1.0);
uniform vec2 west_pool;
uniform vec2 east_pool;
uniform vec2 roof_pool;
uniform vec4 shelter_rect;
uniform float reflection_energy = 0.62;
uniform bool reflections_move = true;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 sample_stone(vec2 at) {
	if (!has_stone_atlas) {
		vec2 row = at * vec2(2.1, 3.8);
		row.x += mod(floor(row.y), 2.0) * 0.5;
		vec2 seam = abs(fract(row) - 0.5);
		float face = 1.0 - smoothstep(0.43, 0.49, max(seam.x, seam.y));
		return mix(vec3(0.26), vec3(0.55), face);
	}
	// Disjoint atlas tile. Keep its sampling footprint inside the stone cell.
	vec2 position = fract(at / 3.65);
	vec2 inset = vec2(2.0 / 1774.0, 2.0 / 887.0);
	return texture(stone_atlas, inset + position * (vec2(0.25, 0.5) - inset * 2.0)).rgb;
}

float sheltered_floor(vec2 position) {
	vec2 edge = min(position - shelter_rect.xy, shelter_rect.zw - position);
	return smoothstep(-0.15, 0.36, min(edge.x, edge.y));
}

float lantern_reflection(vec2 position, vec2 source, vec2 front, float surface_wet, float facet) {
	// The near end stays at the lamp; the softer tail points toward the view.
	// Color and origin come from the existing local lights.
	vec2 offset = position - source;
	float along = dot(offset, front);
	float across = dot(offset, vec2(front.y, -front.x));
	float extent = rooftop ? 1.62 : 3.36;
	float width = 0.46 + max(along, 0.0) * 0.17;
	if (along < -0.8 || along > extent || abs(across) > width + 0.63) {
		return 0.0;
	}
	float ripple_clock = reflections_move ? TIME * 1.14 : 0.0;
	float ripple = 0.5 + 0.5 * sin(dot(position, vec2(3.8, 11.4)) + ripple_clock);
	float spill = (1.0 - smoothstep(0.10, width + 0.63, abs(across)))
			* smoothstep(-0.79, 0.30, along) * (1.0 - smoothstep(extent * 0.23, extent, along));
	float ribbon = (1.0 - smoothstep(0.035, width * 0.76, abs(across + ripple * 0.09)))
			* smoothstep(-0.40, 0.44, along) * (1.0 - smoothstep(extent * 0.49, extent, along));
	return spill * 0.12 + ribbon * surface_wet * mix(0.24, 0.63, facet) * mix(0.82, 1.0, ripple);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 axis = abs(normal);
	vec2 pave_position = world_position.xz;
	if (axis.y < max(axis.x, axis.z)) {
		pave_position = axis.x >= axis.z ? world_position.zy : world_position.xy;
	}
	vec3 stone = sample_stone(pave_position);
	float detail = dot(stone, vec3(0.27, 0.60, 0.13));
	float facet = smoothstep(0.27, 0.56, detail);
	vec3 paving = mix(stone, vec3(detail), 0.69) * stone_tint.rgb;
	ALBEDO = paving;
	ROUGHNESS = 0.86;
	SPECULAR = 0.13;

	if (normal.y > 0.12) {
		vec2 at = world_position.xz;
		float shelter = rooftop ? 0.0 : sheltered_floor(at);
		float surface = sin(at.x * 1.72 + sin(at.y * 0.87)) * sin(at.y * 1.97 - at.x * 0.42);
		float wet = smoothstep(-0.37, 0.62, surface);
		wet = mix(0.39, 0.94, wet) * (rooftop ? 0.54 : mix(1.0, 0.30, shelter));

		// Mortar stays legible as the open stones pick up diffuse blue sky.
		ALBEDO *= mix(1.0, 0.74, wet) * mix(1.0, 0.89, shelter);
		ROUGHNESS = mix(0.85, 0.37, wet * facet);
		SPECULAR = mix(0.15, 0.32, wet * facet);
		vec3 glow = reflected_sky.rgb * (0.043 + wet * (0.045 + 0.042 * facet));
		vec2 front = normalize(INV_VIEW_MATRIX[2].xz + vec2(0.0001, 0.0001));
		vec3 lamps = vec3(0.0);
		if (rooftop) {
			lamps = roof_lantern.rgb * lantern_reflection(at, roof_pool, front, wet, facet);
		} else if (at.x < -3.0) {
			lamps = west_lantern.rgb * lantern_reflection(at, west_pool, front, wet, facet);
		} else if (at.x > 3.0) {
			lamps = east_lantern.rgb * lantern_reflection(at, east_pool, front, wet, facet);
		}
		EMISSION = glow + lamps * reflection_energy * 0.72;
	}
}
