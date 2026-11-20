shader_type sky;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	vec3 ray = EYEDIR;
	float altitude = max(ray.y, 0.0);
	vec3 sun_direction = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-0.4, 0.32, -0.8));
	float sun = max(dot(sun_direction, ray), 0.0);
	vec3 horizon = mix(vec3(0.34, 0.59, 0.70), vec3(0.95, 0.72, 0.42), pow(sun, 9.0));
	vec3 color = mix(horizon, vec3(0.052, 0.24, 0.42), pow(altitude, 0.48));
	vec2 plane = ray.xz / (altitude + 0.17) * vec2(1.55, 2.1) + vec2(2.1, 15.7);
	float mass = cloud_noise(plane) * 0.54 + cloud_noise(plane * 2.04) * 0.25
		+ cloud_noise(plane * 4.1) * 0.13 + cloud_noise(plane * 8.4) * 0.08;
	float cloud = smoothstep(0.43, 0.63, mass) * smoothstep(0.006, 0.14, altitude);
	vec3 ivory = mix(vec3(0.65, 0.72, 0.75), vec3(1.0, 0.81, 0.57), pow(sun, 2.0));
	color = mix(color, ivory * mix(0.82, 1.26, smoothstep(0.55, 0.76, mass)), cloud * 0.91);
	color += vec3(1.0, 0.59, 0.24) * (pow(sun, 35.0) * 0.42 + pow(sun, 390.0) * 0.48);
	color += vec3(10.0, 6.8, 3.5) * smoothstep(0.99945, 0.99964, sun);
	COLOR = mix(vec3(0.44, 0.51, 0.49), color, smoothstep(-0.24, 0.035, ray.y));
}
