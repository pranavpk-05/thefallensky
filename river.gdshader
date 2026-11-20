shader_type spatial;
render_mode diffuse_burley;

varying vec3 world;
uniform float storm = 0.0;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float current = TIME * (1.7 + storm * 0.25);
	float riffle = sin(p.x * 1.5 + p.y * 0.37 + current) * sin(p.y * 2.6 - current * 0.82);
	float ripples = sin(p.x * 2.7 + p.y * 1.8 + riffle * 1.1 - current * 1.3);
	float flow = sin(p.y * 0.86 + p.x * 1.4 - current) * sin(p.y * 0.44 - p.x * 1.5);
	float flecks = pow(max(0.0, riffle * ripples), 7.0);
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.0);
	float river = abs(p.x - (30.0 + 15.0 * sin(p.y * 0.021) + 6.0 * sin(p.y * 0.052)));
	float bank = smoothstep(5.0, 7.1, river + flow * 0.21);
	float foam = smoothstep(0.24, 0.75, flow * 0.70 + riffle * 0.3) * bank;
	vec3 stream = mix(vec3(0.016, 0.092, 0.082), vec3(0.055, 0.24, 0.207), bank);
	ALBEDO = mix(stream, vec3(0.17, 0.30, 0.34), fresnel) + flecks * 0.105 + foam * 0.33;
	NORMAL = normalize(NORMAL + vec3(riffle * 0.068, ripples * 0.052, flow * 0.032) * (1.0 + storm * 1.55));
	ROUGHNESS = 0.15 + storm * 0.12;
	SPECULAR = 0.61;
}
