shader_type spatial;
render_mode diffuse_burley;

varying vec3 world;

float scatter(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 41.19))) * 43758.5453);
}

float weathering(vec3 p) {
	vec3 cell = floor(p);
	vec3 a = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	float x0 = mix(scatter(cell), scatter(cell + vec3(1, 0, 0)), a.x);
	float x1 = mix(scatter(cell + vec3(0, 1, 0)), scatter(cell + vec3(1, 1, 0)), a.x);
	float x2 = mix(scatter(cell + vec3(0, 0, 1)), scatter(cell + vec3(1, 0, 1)), a.x);
	float x3 = mix(scatter(cell + vec3(0, 1, 1)), scatter(cell + vec3(1, 1, 1)), a.x);
	return mix(mix(x0, x1, a.y), mix(x2, x3, a.y), a.z);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float patch = weathering(world * vec3(0.75, 0.27, 0.75));
	float grain = weathering(world * 4.3);
	float block = smoothstep(0.007, 0.053, abs(fract(world.y * 0.73 + patch * 0.09) - 0.5));
	vec3 normal = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 sandstone = mix(vec3(0.10, 0.115, 0.115), vec3(0.35, 0.285, 0.203), patch);
	float lichen = smoothstep(0.54, 0.80, patch + normal.y * 0.16) * 0.6;
	ALBEDO = mix(sandstone, vec3(0.116, 0.164, 0.071), lichen)
		* (0.8 + grain * 0.32) * (0.71 + block * 0.29);
	ROUGHNESS = 0.91;
}
