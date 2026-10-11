shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.055, 0.34, 0.42, 1.0);
uniform float motion = 1.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = floor(world_position.xz * 5.0) / 5.0;
 float t = TIME * motion;
 float broad = sin(p.x * 0.57 + p.y * 0.18 + t * 0.55) * cos(p.y * 0.66 - t * 0.32);
 float ripples = sin(p.x * 1.7 - p.y * 0.4 + t * 0.85);
 float paper_grain = fract(sin(dot(floor(p * 2.0), vec2(12.9898,78.233))) * 43758.5453);
 float glint = step(0.94, sin(p.x * 1.2 + p.y * 1.6 + t * 0.45));
 vec3 deep = water_color.rgb * (0.90 + broad * 0.12 + ripples * 0.025);
 vec3 ink = vec3(0.045,0.16,0.19) * (1.0 - step(0.62,paper_grain)) * 0.10;
 ALBEDO = deep + ink + vec3(glint * 0.065);
 ROUGHNESS = 0.48;
 METALLIC = 0.04;
}
