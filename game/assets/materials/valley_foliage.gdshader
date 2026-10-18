shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 trunk_color : source_color = vec3(0.20, 0.13, 0.08);
uniform vec3 leaf_color : source_color = vec3(0.14, 0.26, 0.11);
uniform vec3 leaf_highlight : source_color = vec3(0.22, 0.35, 0.15);
uniform float canopy_fraction : hint_range(0.0, 1.0) = 0.20;
uniform float canopy_blend : hint_range(0.01, 1.0) = 0.22;
uniform float model_height : hint_range(1.0, 40.0) = 15.0;
uniform float model_base_y : hint_range(-5.0, 5.0) = 0.0;
uniform float wind_strength : hint_range(0.0, 0.1) = 0.006;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.0;

varying vec3 world_position;
varying float norm_y;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	norm_y = clamp((VERTEX.y - model_base_y) / max(0.1, model_height), 0.0, 1.0);
	float sway = sin(TIME * wind_speed + world_pos.x * 3.0 + world_pos.z * 3.0);
	VERTEX.x += sway * norm_y * norm_y * wind_strength;
	VERTEX.z += sway * norm_y * norm_y * wind_strength * 0.6;
	world_position = world_pos;
}

void fragment() {
	float t = smoothstep(canopy_fraction, canopy_fraction + canopy_blend, norm_y);
	float sun = clamp(NORMAL.y * 0.40 + 0.50, 0.0, 1.0);
	vec3 base_foliage = mix(leaf_color, leaf_highlight, sun);
	ALBEDO = mix(trunk_color, base_foliage, t);
	ROUGHNESS = 0.88;
	SPECULAR = 0.05;
	BACKLIGHT = base_foliage * 0.28 * t;
}
