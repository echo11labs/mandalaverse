shader_type spatial;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap;
uniform vec4 roof_color : source_color = vec4(0.55,0.28,0.14,1.0);
void fragment() {
	vec3 source = texture(source_atlas, UV).rgb;
	float roof = step(source.r * 1.15 + 0.02, source.b) * step(source.g * 1.03, source.b);
	float tone = dot(source,vec3(0.2126,0.7152,0.0722));
	vec3 warm = source * vec3(0.94,0.90,0.81);
	ALBEDO = mix(warm,roof_color.rgb*(0.55+tone*0.7),roof);
	ROUGHNESS = 0.95;
}
