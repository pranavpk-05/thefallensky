shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_tint : source_color;
uniform vec4 wear_tint : source_color;
uniform float metalness = 0.0;
uniform float grain = 1.0;
uniform float wetness = 0.0;
varying vec3 p;

float hash(vec2 v) {
	return fract(52.9829189 * fract(dot(v, vec2(0.06711056, 0.00583715))));
}

float texture_noise(vec2 v) {
	vec2 cell = floor(v);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(v));
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal = abs(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec2 plane = normal.z > normal.x ? p.xy : p.zy;
	plane = normal.y > 0.65 ? p.xz : plane;
	float knots = texture_noise(plane * vec2(9.0 * grain, 2.6));
	float fibre = texture_noise(plane * vec2(71.0 * grain, 14.0));
	float oxidation = texture_noise(plane * 2.8 + vec2(knots));
	float streak = smoothstep(0.35, 0.80, oxidation * 0.62 + knots * 0.43);
	float groove = pow(abs(cos((plane.x * 4.4 + knots * 0.014) * 6.283185)), 40.0);
	float joined = grain > 3.0 ? groove * 0.38 : 0.0;
	ALBEDO = mix(base_tint.rgb, wear_tint.rgb, streak) * (0.75 + 0.30 * knots + 0.16 * fibre)
		* (1.0 - joined) * (1.0 - wetness * 0.13);
	METALLIC = metalness * (0.30 + 0.70 * (1.0 - streak));
	ROUGHNESS = 0.81 - metalness * 0.24 + fibre * 0.15 - wetness * 0.26;
	SPECULAR = 0.38;
}
