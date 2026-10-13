shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform int motion_kind : hint_enum("Foliage", "Actor", "Cloth") = 0;
uniform int idle_role : hint_enum("Hero", "Ticket", "Imp", "Announcer") = 0;
uniform float motion : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;
uniform float breath_rate : hint_range(0.1, 3.0) = 0.75;
uniform float wind_strength : hint_range(0.0, 0.1) = 0.035;
uniform float breath_pixels : hint_range(0.0, 1.0) = 0.65;
uniform float gesture_pixels : hint_range(0.0, 1.0) = 0.65;

void vertex() {
	// Sprite3D's generated quad keeps its authored scale and position while
	// facing the active camera; local animation below is weighted by UV height.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 camera_right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 camera_up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 camera_back = normalize(INV_VIEW_MATRIX[2].xyz);
	mat4 billboard = mat4(
		vec4(camera_right * scale.x, 0.0),
		vec4(camera_up * scale.y, 0.0),
		vec4(camera_back * scale.z, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	// The billboard transform replaces the sprite's model-view orientation.
	// Keep its normal transform in sync so shaded sprites still respond to
	// directional and point lights instead of inheriting the unbillboarded axes.
	MODELVIEW_NORMAL_MATRIX = transpose(inverse(mat3(MODELVIEW_MATRIX)));

	float time = TIME;
	vec2 local_uv = (UV - uv_rect.xy) / max(uv_rect.zw, vec2(0.000001));
	float top_weight = 1.0 - smoothstep(0.05, 0.95, local_uv.y);
	float root_safe_weight = top_weight * top_weight;
	if (motion_kind == 0) {
		VERTEX.x += sin(time * 0.72 + phase + local_uv.y * 0.35) * wind_strength * motion * root_safe_weight;
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 texture_size = vec2(textureSize(texture_albedo, 0));
	vec2 atlas_texel = 1.0 / texture_size;
	vec2 local_uv = clamp((UV - uv_rect.xy) / max(uv_rect.zw, vec2(0.000001)), vec2(0.0), vec2(1.0));
	// Sprite3D already submits atlas-normalized UVs. Keep those for sampling;
	// use local_uv only for masks so all profile regions are crop-relative.
	vec2 sample_uv = uv_rect.xy + atlas_texel * 0.5 + local_uv * max(vec2(0.0), uv_rect.zw - atlas_texel);
	float texel_height = texture_size.y;
	if (motion_kind == 1) {
		// Sprite3D is a four-vertex quad, so move sampled chest pixels in the
		// fragment stage. The face, hair and foot row remain outside the mask.
		float chest_weight = smoothstep(0.36, 0.44, local_uv.y) * (1.0 - smoothstep(0.58, 0.66, local_uv.y));
		float breathing = sin(TIME * breath_rate + phase) * breath_pixels * motion * chest_weight;
		sample_uv.y -= breathing / max(1.0, texel_height);
		float side_hair = max(1.0 - smoothstep(0.08, 0.31, local_uv.x), smoothstep(0.69, 0.92, local_uv.x));
		float hair_tips = (1.0 - smoothstep(0.15, 0.37, local_uv.y)) * side_hair;
		float hem = smoothstep(0.72, 0.81, local_uv.y) * (1.0 - smoothstep(0.90, 0.96, local_uv.y));
		float ticket_lapel = smoothstep(0.41, 0.49, local_uv.y) * (1.0 - smoothstep(0.69, 0.77, local_uv.y)) * smoothstep(0.23, 0.34, local_uv.x) * (1.0 - smoothstep(0.66, 0.77, local_uv.x));
		float imp_edges = (1.0 - smoothstep(0.09, 0.30, local_uv.x) + smoothstep(0.70, 0.91, local_uv.x)) * (1.0 - smoothstep(0.10, 0.40, local_uv.y));
		float imp_tail = smoothstep(0.70, 0.82, local_uv.x) * smoothstep(0.61, 0.72, local_uv.y) * (1.0 - smoothstep(0.89, 0.97, local_uv.y));
		float announcer_head = smoothstep(0.08, 0.15, local_uv.y) * (1.0 - smoothstep(0.35, 0.43, local_uv.y));
		if (idle_role == 0) {
			float hair_motion = sin(TIME * 0.68 + phase) * gesture_pixels * motion * hair_tips;
			float hem_motion = sin(TIME * 0.52 + phase + 1.2) * gesture_pixels * motion * hem;
			sample_uv.x += (hair_motion * 0.75 + hem_motion * 0.5) / max(1.0, texture_size.x);
		} else if (idle_role == 1) {
			// A brief, low-amplitude lapel twitch leaves the face and shoes still.
			float twitch = pow(max(0.0, sin(TIME * 0.46 + phase)), 10.0);
			sample_uv.x += twitch * gesture_pixels * motion * ticket_lapel / max(1.0, texture_size.x);
		} else if (idle_role == 2) {
			float ear_flick = sin(TIME * 2.1 + phase) * gesture_pixels * motion * imp_edges;
			float tail_flick = sin(TIME * 2.6 + phase * 1.3) * gesture_pixels * motion * imp_tail;
			sample_uv.x += (ear_flick * 0.65 + tail_flick) / max(1.0, texture_size.x);
			sample_uv.y += tail_flick * 0.35 / max(1.0, texel_height);
		} else {
			// Move the head's pixels together for a restrained nod; no screen-wide bob.
			float nod = sin(TIME * 0.42 + phase) * gesture_pixels * motion * announcer_head;
			sample_uv.y += nod / max(1.0, texel_height);
		}
	} else if (motion_kind == 2) {
		float hem_weight = smoothstep(0.62, 0.84, local_uv.y);
		float cloth_sway = sin(TIME * 1.05 + phase + local_uv.y) * gesture_pixels * motion * hem_weight;
		sample_uv.x += cloth_sway / max(1.0, texture_size.x);
	}
	vec4 texel = texture(texture_albedo, sample_uv) * tint;
	ALBEDO = texel.rgb;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.92;
}
