shader_type spatial;
// Painted parts that light up after dark: the ferris wheel's bulbs and the
// cabins' windows. Vertex colour is the paint; a vertex alpha below 1 marks a
// bulb or window, which glows by `glow` in a blend of its own colour and warm light.

uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.56, 1.0);

void fragment() {
	float lamp = 1.0 - step(0.99, COLOR.a);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	EMISSION = mix(glow_color.rgb, COLOR.rgb, 0.55) * glow * lamp;
}
