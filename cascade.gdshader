shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

void fragment() {
	float height = UV.y;
	float streak = sin(UV.x * 91.0 + sin(height * 21.0 - TIME * 2.0) * 1.6);
	float rush = sin(height * 85.0 - TIME * 19.0 + UV.x * 9.0) * 0.12;
	float center = sin(height * 8.0 - TIME * 1.3) * height * 0.08;
	float curtain = 1.0 - smoothstep(0.14, 0.49, abs(UV.x - 0.5 + center));
	float mist = 1.0 - smoothstep(0.61, 1.0, height);
	ALBEDO = mix(vec3(0.37, 0.69, 0.70), vec3(0.74, 0.88, 0.82), (streak + 1.0) * 0.35 + rush);
	ALPHA = curtain * mist * (0.74 + streak * 0.14 + rush);
}
