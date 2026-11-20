shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform bool sail = false;

void vertex() {
	if (!sail) {
		float hem = UV.y * UV.y;
		VERTEX.z += hem * (sin(UV.x * 13.0 + TIME * 5.1) * 0.035 + sin(TIME * 2.1) * 0.051);
		VERTEX.x += sin(TIME * 3.9 + UV.y * 2.0) * hem * 0.028;
	}
}

void fragment() {
	vec2 texture_scale = sail ? vec2(510.0, 390.0) : vec2(190.0, 180.0);
	float weave = sin(UV.x * texture_scale.x) * sin(UV.y * texture_scale.y);
	float chevron = abs(UV.x - 0.5);
	if (sail) {
		vec3 linen = mix(vec3(0.30, 0.17, 0.068), vec3(0.55, 0.33, 0.135), smoothstep(0.0, 0.96, UV.y));
		float seam = 1.0 - smoothstep(0.006, 0.014, abs(fract(chevron * 12.0) - 0.5));
		float band = 1.0 - smoothstep(0.042, 0.053, abs(UV.y - 0.48 + chevron * 1.51));
		float band_edge = 1.0 - smoothstep(0.056, 0.062, abs(UV.y - 0.48 + chevron * 1.51));
		vec3 trim = mix(vec3(0.56, 0.35, 0.137), vec3(0.102, 0.23, 0.21), band);
		ALBEDO = mix(linen, trim, band_edge) * (0.91 + weave * 0.052 - seam * 0.14);
	} else {
		vec3 red = mix(vec3(0.18, 0.059, 0.041), vec3(0.34, 0.108, 0.053), smoothstep(0.0, 0.88, UV.y));
		float stitching = smoothstep(0.43, 0.465, chevron) - smoothstep(0.47, 0.488, chevron);
		float hem = smoothstep(0.906, 0.922, UV.y) - smoothstep(0.931, 0.948, UV.y);
		float detail = max(hem, stitching) * (0.82 + 0.18 * weave);
		ALBEDO = mix(red, vec3(0.53, 0.32, 0.14), detail) * (0.94 + weave * 0.065);
	}
	ROUGHNESS = 0.82 + weave * 0.052;
	BACKLIGHT = ALBEDO * 0.14;
}
