shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

uniform vec4 foliage : source_color = vec4(1.0);
uniform vec2 near_fade = vec2(1.06, 3.15);
varying vec3 branch;

void vertex() {
	branch = VERTEX;
	vec3 position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.95 + position.x * 0.42 + position.z * 0.35);
	VERTEX.x += sway * length(VERTEX.xz) * 0.029;
}

void fragment() {
	float clearance = smoothstep(near_fade.x, near_fade.y, length(VERTEX));
	float screen_dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (screen_dither > clearance) {
		discard;
	}
	float needle = sin(branch.x * 133.0 + sin(branch.z * 63.0) * 2.7);
	ALBEDO = foliage.rgb * COLOR.rgb * (0.84 + 0.16 * needle + 0.14 * clamp(branch.y + 0.42, 0.0, 1.0));
	ROUGHNESS = 0.91;
	BACKLIGHT = ALBEDO * 0.15;
}
