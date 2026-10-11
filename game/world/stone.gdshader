shader_type spatial;
varying vec3 world_position;
uniform vec4 base_color : source_color = vec4(0.8, 0.74, 0.59, 1.0);
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz * 1.8;
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 f = fract(p);
 float edge = step(0.065, f.x) * step(0.065, f.y);
 float variation = fract(sin(dot(floor(p), vec2(12.9898,78.233))) * 43758.5453);
 ALBEDO = base_color.rgb * (0.76 + edge * 0.20 + variation * 0.06);
 ROUGHNESS = 0.9;
}
