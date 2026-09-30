shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float large = noise(world_position.xz * 0.16);
	float fine = noise(world_position.xz * 3.4);
	float detail = large * 0.1 + fine * 0.035;
	ALBEDO = COLOR.rgb * (0.91 + detail);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}

