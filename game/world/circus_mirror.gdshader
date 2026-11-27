shader_type spatial;
render_mode cull_disabled;
// Funhouse mirror glass. Each fragment follows the camera ray off the glass: it
// fades from the floor in front of the mirror up into the sky, and where it
// crosses the walker it shows the walker's own sprite. UV is the position on the glass (0..1), and the
// vertex colour bends the reflection: r stretches it sideways, g stretches it in
// height, b is how strongly that changes across the glass (all centred on 0.5).
// With motion at 0 the glints hold still; the reflection always follows the walker.

uniform sampler2D walker_sprite : source_color, filter_nearest, repeat_disable;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
// World size of the sprite canvas, then how far down the canvas the feet are (0..1).
uniform vec3 walker_canvas = vec3(2.4, 2.4, 0.9);
uniform vec4 sky_high : source_color = vec4(0.62, 0.80, 0.90, 1.0);
uniform vec4 sky_low : source_color = vec4(0.84, 0.92, 0.92, 1.0);
uniform vec4 floor_light : source_color = vec4(0.66, 0.70, 0.80, 1.0);
uniform vec4 floor_dark : source_color = vec4(0.42, 0.47, 0.62, 1.0);
uniform float floor_y = 0.2;
uniform float glow = 0.0;
uniform float motion = 1.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 bend;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bend = COLOR.rgb;
}

void fragment() {
	// The follow camera is orthogonal, so every fragment shares one view direction.
	vec3 view = -normalize(INV_VIEW_MATRIX[2].xyz);
	vec3 normal = normalize(world_normal);
	if (dot(normal, view) > 0.0) {
		normal = -normal;
	}
	vec3 ray = reflect(view, normal);
	vec3 seen = mix(sky_low.rgb, sky_high.rgb, UV.y);
	if (ray.y < -0.02) {
		float reach = (world_position.y - floor_y) / -ray.y;
		vec3 paving = mix(floor_dark.rgb, floor_light.rgb, smoothstep(0.0, 2.6, reach));
		seen = mix(paving, seen, smoothstep(1.4, 4.4, reach));
	}
	vec2 heading = normalize(ray.xz + vec2(0.0001, 0.0));
	float along = dot(walker.xz - world_position.xz, heading) / max(length(ray.xz), 0.001);
	if (along > 0.0) {
		// The ray's fall is flattened, so a walker a few steps away still lands inside the glass.
		vec3 hit = world_position + ray * along * vec3(1.0, 0.3, 1.0);
		float lens = 1.0 + (bend.b - 0.5) * 1.6 * cos((UV.x - 0.5) * 6.2832);
		float wide = (0.35 + bend.r * 1.3) * lens;
		float tall = (0.35 + bend.g * 1.3) / lens;
		float across = dot(hit.xz - walker.xz, vec2(-heading.y, heading.x)) / wide;
		float up = (hit.y - walker.y) / tall;
		vec2 sprite_uv = vec2(0.5 - across / walker_canvas.x, walker_canvas.z - up / walker_canvas.y);
		if (sprite_uv.x > 0.0 && sprite_uv.x < 1.0 && sprite_uv.y > 0.0 && sprite_uv.y < 1.0) {
			vec4 figure = texture(walker_sprite, sprite_uv);
			seen = mix(seen, figure.rgb * vec3(0.9, 0.96, 1.0), step(0.5, figure.a));
		}
	}
	// Glints: two slanted bands drift across the silvering, with a darker rim.
	float slant = UV.x + UV.y * 0.55 - TIME * motion * 0.05;
	float glint = smoothstep(0.86, 0.9, fract(slant * 1.3)) * (1.0 - smoothstep(0.94, 0.98, fract(slant * 1.3)));
	glint += 0.5 * smoothstep(0.3, 0.33, fract(slant * 1.3)) * (1.0 - smoothstep(0.36, 0.39, fract(slant * 1.3)));
	vec2 rim = min(UV, 1.0 - UV);
	seen *= 0.8 + 0.2 * smoothstep(0.0, 0.12, min(rim.x, rim.y));
	seen += vec3(0.2) * glint;
	ALBEDO = seen;
	EMISSION = seen * glow;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
