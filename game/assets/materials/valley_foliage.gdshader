shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
	vec3 original_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 0.7 + original_world.x * 0.4 + original_world.z * 0.2);
	VERTEX.x += sway * clamp(VERTEX.y, 0.0, 7.0) * 0.009;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.1;
}

