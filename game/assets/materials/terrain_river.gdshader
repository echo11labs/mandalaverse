shader_type spatial;
render_mode cull_disabled, depth_draw_never;

uniform vec4 albedo_shallow : source_color = vec4(0.07, 0.20, 0.18, 1.0);
uniform vec4 albedo_deep : source_color = vec4(0.025, 0.10, 0.12, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.84, 0.73, 1.0);
uniform float flow_speed = 0.12;
uniform float normal_scale = 0.22;
uniform float roughness = 0.30;
uniform sampler2D normal_bump_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D i_flowmap : filter_linear, repeat_disable;
uniform sampler2D i_distmap : filter_linear, repeat_disable;
uniform sampler2D i_texture_foam_noise : repeat_enable;
uniform bool i_valid_flowmap = false;
uniform int i_uv2_sides = 1;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

vec3 view_position(vec2 screen_uv, float depth, mat4 inverse_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 position = inverse_projection * vec4(ndc, 1.0);
	return position.xyz / position.w;
}

void fragment() {
	vec2 atlas = (UV2 + 1.0 / float(i_uv2_sides)) * float(i_uv2_sides) / float(i_uv2_sides + 2);
	vec4 maps = texture(i_flowmap, atlas);
	vec2 flow = i_valid_flowmap ? (maps.rg * 2.0 - 1.0) : vec2(0.0, 0.64);
	float phase = fract(TIME * flow_speed + maps.a);
	float second_phase = fract(TIME * flow_speed + maps.a + 0.5);
	float blend = abs(phase * 2.0 - 1.0);
	vec2 water_uv = vec2(UV.x * 2.0, UV.y * 3.0);
	vec3 first = texture(normal_bump_texture, water_uv - flow * phase).rgb;
	vec3 second = texture(normal_bump_texture, water_uv - flow * second_phase).rgb;
	vec3 waves = mix(first, second, blend);
	float shore = abs(UV.x * 2.0 - 1.0);
	float mask = i_valid_flowmap ? maps.b : smoothstep(0.65, 1.0, shore);
	float foam = mask * smoothstep(0.35, 0.85, waves.b) * 0.48;
	float depth = max(0.0, VERTEX.z - view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX).z);
	vec3 tint = mix(albedo_shallow.rgb, albedo_deep.rgb, smoothstep(0.02, 0.35, depth) * (1.0 - shore * 0.5));
	ALBEDO = mix(tint, foam_color.rgb, foam);
	ROUGHNESS = roughness + foam * 0.4;
	SPECULAR = 0.3;
	NORMAL_MAP = vec3(waves.rg, 1.0);
	NORMAL_MAP_DEPTH = normal_scale * (1.0 - foam);
	// Only refract behind the water; projection reconstruction also supports orthographic cameras.
	vec2 refracted_uv = clamp(SCREEN_UV + (waves.rg - 0.5) * 0.0015, vec2(0.001), vec2(0.999));
	float behind = step(view_position(refracted_uv, texture(depth_texture, refracted_uv).r, INV_PROJECTION_MATRIX).z, VERTEX.z);
	EMISSION = texture(screen_texture, mix(SCREEN_UV, refracted_uv, behind)).rgb * 0.025 * (1.0 - foam);
	// The mesh is dressed onto a coarse terrain proxy; bank fading is artist controlled.
	ALPHA = (1.0 - smoothstep(0.88, 1.0, shore)) * 0.98;
}
