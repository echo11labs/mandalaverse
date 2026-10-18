shader_type spatial;
render_mode cull_disabled;
uniform float metres_per_unit = 100.0;
varying vec3 world_position;

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	// Keep the compact earth surface softly lit across terrain tessellation seams.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0,1.0,0.0,0.0)).xyz);
	vec2 ground = world_position.xz * metres_per_unit;
	float coarse = grain(floor(ground * 3.0));
	float fine = grain(floor(ground * 28.0));
	ALBEDO = mix(vec3(0.33,0.25,0.16),vec3(0.53,0.43,0.29),coarse*0.35 + fine*0.3);
	ROUGHNESS = 1.0;
}
