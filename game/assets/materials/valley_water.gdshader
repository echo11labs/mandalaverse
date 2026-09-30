shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_position.z * 0.6 + TIME * 0.6) * 0.016;
}
void fragment() {
	float a = sin(world_position.x * 2.4 + world_position.z * 1.2 - TIME * 1.6);
	float b = sin(world_position.z * 3.1 - world_position.x * 1.8 - TIME * 1.1);
	float streak = pow(max(0.0, sin(world_position.z * 4.5 + world_position.x * 6.0 - TIME * 1.7)), 20.0);
	float edges = pow(abs(UV.x * 2.0 - 1.0), 12.0);
	ALBEDO = mix(vec3(0.035, 0.13, 0.14), vec3(0.065, 0.20, 0.19), 0.4 + a * 0.055 + b * 0.04);
	ALBEDO = mix(ALBEDO, vec3(0.32, 0.40, 0.29), edges * (0.19 + streak * 0.23));
	ALBEDO += vec3(0.018, 0.025, 0.025) * streak;
	ROUGHNESS = 0.24;
	METALLIC = 0.05;
	SPECULAR = 0.58;
}

