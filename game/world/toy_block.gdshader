shader_type spatial;
render_mode diffuse_burley;
// Painted wooden toy blocks. One batch of unit shapes builds a whole town: the
// instance colour is the paint, and the shader adds what makes a block read as a
// block at any size: a worn lighter chamfer along every edge, a faint wood grain
// along the longest side and the pixel speckle the other painted surfaces share.

// 1 for unit boxes; other shapes skip the per-face chamfer.
uniform float chamfer = 1.0;
// 1 for shapes turned around their local Y axis (columns, cones).
uniform float turned = 0.0;
// Courses per metre down a slope, for roof prisms; 0 leaves the face plain.
uniform float courses = 0.0;

const float TEXEL = 0.0625;
const float CHAMFER_WIDTH = 0.055;

varying vec3 paint;
varying vec3 local_position;
varying vec3 local_normal;
varying vec3 half_size;
varying vec3 world_position;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_position = VERTEX * size;
	local_normal = NORMAL;
	half_size = size * 0.5;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	paint = COLOR.rgb;
}

void fragment() {
	vec3 facing = abs(normalize(local_normal));
	vec2 along;
	vec2 reach;
	if (facing.y >= facing.x && facing.y >= facing.z) {
		along = local_position.xz;
		reach = half_size.xz;
	} else if (facing.x >= facing.z) {
		along = local_position.zy;
		reach = half_size.zy;
	} else {
		along = local_position.xy;
		reach = half_size.xy;
	}
	float edge = min(reach.x - abs(along.x), reach.y - abs(along.y));
	if (turned > 0.5) {
		// A column's rim is at its top and bottom; its cap wears around the circle.
		edge = facing.y > 0.7 ? half_size.x - length(local_position.xz) : half_size.y - abs(local_position.y);
	}
	float worn = (1.0 - smoothstep(CHAMFER_WIDTH * 0.45, CHAMFER_WIDTH, edge)) * max(chamfer, turned);
	// Grain runs along the longer side of the face, a few texels wide.
	vec2 grain_cell = reach.x >= reach.y ? vec2(floor(along.x / 0.5), floor(along.y / TEXEL)) : vec2(floor(along.y / 0.5), floor(along.x / TEXEL));
	float grain = (cell_hash(grain_cell + floor(world_position.xz)) - 0.5) * 0.07;
	float speckle = (cell_hash(floor(world_position.xy / TEXEL) + floor(world_position.zz / TEXEL)) - 0.5) * 0.04;
	float shade = 1.0 + grain + speckle;
	if (courses > 0.0) {
		float row = local_position.y * courses;
		shade -= step(fract(row), 0.14) * 0.16;
		shade += (cell_hash(vec2(floor(row), floor(world_position.x * 2.0 + world_position.z * 2.0))) - 0.5) * 0.08;
	}
	vec3 color = paint * shade;
	ALBEDO = mix(color, color * 1.16 + vec3(0.05), worn * 0.75);
	ROUGHNESS = 0.62;
	SPECULAR = 0.3;
}
