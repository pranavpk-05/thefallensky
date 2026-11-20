shader_type spatial;
render_mode diffuse_burley;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float riffle = sin(p.x * 1.5 + p.y * 0.37 + TIME * 2.0) * sin(p.y * 2.6 - TIME * 1.4);
	float ripples = sin(p.x * 2.7 + p.y * 1.8 + riffle * 1.1 - TIME * 2.2);
	float flecks = pow(max(0.0, riffle * ripples), 7.0);
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.0);
	float edge = smoothstep(0.37, 0.5, abs(UV.x - 0.5)) * (0.28 + 0.72 * flecks);
	ALBEDO = mix(vec3(0.017, 0.18, 0.15), vec3(0.25, 0.48, 0.43), fresnel) + flecks * 0.16 + edge * 0.16;
	NORMAL = normalize(NORMAL + vec3(riffle * 0.072, ripples * 0.045, riffle * 0.034));
	ROUGHNESS = 0.19;
	SPECULAR = 0.66;
}
