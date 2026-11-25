shader_type canvas_item;
render_mode unshaded;

// R stores film thickness, G cooking, B reclaimed batter, A heat intensity.
uniform sampler2D fold_source : filter_nearest;
uniform float pan_radius = 0.948;
uniform vec2 tilt = vec2(0.0);
uniform vec2 fold_axis = vec2(1.0, 0.0);
uniform float fold_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = false;

vec2 field_uv(vec2 point) {
	return point * 0.5 + vec2(0.5);
}

float inside_pan(vec2 point) {
	return step(dot(point, point), pan_radius * pan_radius);
}

float grain(vec2 pixel) {
	vec2 uv = fract(pixel * vec2(0.06711056, 0.00583715));
	return fract(52.9829189 * (uv.x + uv.y));
}

void fragment() {
	vec2 point = UV * 2.0 - vec2(1.0);
	vec4 batter = texture(TEXTURE, field_uv(point)) * inside_pan(point);
	float lit_fold = 0.0;
	if (fold_amount > 0.0) {
		float against_fold = dot(point, fold_axis);
		float width = cos(fold_amount * PI);
		if (against_fold < 0.0 && texture(fold_source, field_uv(point)).r > 0.5) {
			batter.rgb = vec3(0.0);
		}
		if (abs(width) > 0.025) {
			float original = against_fold / width;
			if (original < 0.0) {
				vec2 lookup = point + (original - against_fold) * fold_axis;
				vec4 moving = texture(TEXTURE, field_uv(lookup)) * inside_pan(lookup);
				if (moving.r > 0.018 && texture(fold_source, field_uv(lookup)).r > 0.5) {
					batter.rgb = moving.rgb;
					lit_fold = sin(fold_amount * PI);
				}
			}
		}
	}
	float coverage = smoothstep(0.008, 0.098, batter.r);
	float solid = smoothstep(0.11, 0.2286, batter.g);
	float toasted = smoothstep(0.26, 0.77, batter.g);
	float charred = smoothstep(0.7714, 0.93, batter.g);
	float fleck = grain(floor(UV * vec2(198.0)));
	float pores = smoothstep(0.86, 0.99, fleck) * solid;
	vec3 film = mix(vec3(0.96, 0.77, 0.48), vec3(0.84, 0.53, 0.24), solid);
	film = mix(film, vec3(0.68, 0.40, 0.19), toasted);
	film = mix(film, vec3(0.36, 0.19, 0.13), charred);
	film *= 1.0 + (fleck - 0.52) * 0.15 - pores * 0.24;
	film += vec3(0.16, 0.10, 0.04) * (1.0 - solid) * smoothstep(-0.6, 0.95, dot(point, -tilt) + 0.3);
	// A diagonal accent distinguishes batter physically brought back from the rim.
	float returned = smoothstep(0.48, 0.83, batter.b);
	float stripe = step(0.68, fract((point.x * 0.74 - point.y) * 13.0));
	film = mix(film, vec3(0.94, 0.72, 0.39), returned * stripe * 0.28);
	float highlight = reduced_motion ? 0.0 : lit_fold * 0.1;
	film = mix(film, vec3(1.0, 0.88, 0.67), highlight);
	float heat = smoothstep(0.45, 1.0, batter.a) * 0.27;
	COLOR = vec4(mix(vec3(0.83, 0.28, 0.10), film, coverage), heat * (1.0 - coverage) + coverage);
}
