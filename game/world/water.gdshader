shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.09, 0.52, 0.61, 1.0);
uniform float motion = 1.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = floor(world_position.xz * 7.0) / 7.0;
 float t = TIME * motion;
 float waves = sin(p.x * 2.0 + t) * cos(p.y * 2.2 - t * 0.7);
 float glint = step(0.88, sin(p.x * 1.9 + p.y * 2.7 + t * 0.6));
 ALBEDO = water_color.rgb + vec3(waves * 0.045 + glint * 0.11);
 ROUGHNESS = 0.26;
 METALLIC = 0.15;
}
