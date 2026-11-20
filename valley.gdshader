shader_type spatial;
render_mode diffuse_burley;

uniform bool floating_rock = false;
varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), t.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), t.x), t.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 up = mat3(INV_VIEW_MATRIX) * NORMAL;
	float broad = grain(world.xz * 0.069) * 0.68 + grain(world.xz * 0.22) * 0.32;
	float fine = grain(world.xz * 2.8 + world.y * 1.6);
	float seam = grain(vec2(world.x + world.z * 0.6, world.y * 4.4) * 0.31);
	float slope = smoothstep(0.54, 0.87, up.y + (broad - 0.5) * 0.22);
	vec3 moss = mix(vec3(0.041, 0.115, 0.038), vec3(0.29, 0.43, 0.102), broad);
	vec3 rock = mix(vec3(0.13, 0.139, 0.131), vec3(0.39, 0.35, 0.265), seam);
	float river = abs(world.x - (30.0 + 15.0 * sin(world.z * 0.021) + 6.0 * sin(world.z * 0.052)));
	float bank = (1.0 - smoothstep(6.0, 11.0, river)) * (1.0 - smoothstep(3.0, 7.0, world.y));
	vec3 color = mix(rock, moss, slope);
	if (!floating_rock) {
		color = mix(color, vec3(0.31, 0.26, 0.145), bank * 0.8);
	}
	ALBEDO = color * mix(0.75, 1.22, fine);
	ROUGHNESS = 0.87 + fine * 0.1;
}
