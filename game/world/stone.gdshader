shader_type spatial;
varying vec3 world_position;
uniform vec4 base_color : source_color = vec4(0.63, 0.71, 0.63, 1.0);
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz * vec2(1.35,1.65);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 f = fract(p);
	float grout = step(0.045, f.x) * step(0.045, f.y) * step(f.x,0.96) * step(f.y,0.96);
	float variation = fract(sin(dot(floor(p), vec2(12.9898,78.233))) * 43758.5453);
	float paper_speckle = fract(sin(dot(floor(world_position.xz*13.0),vec2(4.17,21.73)))*17431.3);
	float wash = 0.93 + variation * 0.09 + sin(world_position.x*2.4+world_position.z*0.3)*0.018;
	vec3 stone = base_color.rgb * wash;
	stone = mix(stone*0.56,stone,grout);
	stone *= 0.97 + paper_speckle*0.05;
	ALBEDO = stone;
	ROUGHNESS = 0.96;
}
