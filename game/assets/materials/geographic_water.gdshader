shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float wave = sin(UV.y * 12.0 - TIME * 1.5);
	float streak = pow(max(0.0,sin(UV.y*23.0+UV.x*6.0-TIME*2.0)),15.0);
	float edge = pow(abs(UV.x*2.0-1.0),8.0);
	ALBEDO = mix(vec3(0.045,0.20,0.21),vec3(0.11,0.32,0.29),0.5+wave*0.12);
	ALBEDO += vec3(0.08,0.10,0.08)*(streak*0.25+edge*0.25);
	ROUGHNESS = 0.7;
	SPECULAR = 0.18;
}
