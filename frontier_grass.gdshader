shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float gusts = 0.0;
varying float blade_height;
varying float tint;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	blade_height = VERTEX.y;
	tint = fract(sin(dot(root.xz, vec2(15.31, 39.71))) * 2572.7);
	float wave = sin(TIME * (1.6 + gusts) - root.x * 0.27 + root.z * 0.32);
	float riffle = sin(TIME * 4.8 + root.x * 0.61 + root.z * 0.44);
	float bend = blade_height * blade_height * ((0.22 + gusts * 0.50) * wave + 0.11 * riffle);
	VERTEX.x += bend;
	VERTEX.z += bend * 0.55;
}

void fragment() {
	float clearance = smoothstep(0.42, 1.60, length(VERTEX));
	float screen_dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (screen_dither > clearance) {
		discard;
	}
	vec3 root_color = mix(vec3(0.026, 0.063, 0.020), vec3(0.078, 0.128, 0.024), tint);
	vec3 tips = mix(vec3(0.124, 0.223, 0.047), vec3(0.27, 0.36, 0.078), tint);
	ALBEDO = mix(root_color, tips, smoothstep(0.0, 0.58, blade_height));
	ROUGHNESS = 0.83;
	BACKLIGHT = ALBEDO * 0.18;
}
