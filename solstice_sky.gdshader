shader_type sky;
render_mode use_half_res_pass;

uniform float night = 0.0;
uniform float storm = 0.0;
uniform vec2 cloud_offset = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	vec3 ray = EYEDIR;
	float altitude = max(ray.y, 0.0);
	vec3 sun_direction = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-0.4, 0.32, -0.8));
	float sun = max(dot(sun_direction, ray), 0.0);
	vec3 horizon = mix(vec3(0.28, 0.43, 0.51), vec3(0.96, 0.51, 0.23), pow(sun, 7.0) * (1.0 - storm * 0.6));
	horizon = mix(horizon, vec3(0.035, 0.067, 0.116), night);
	vec3 zenith = mix(vec3(0.028, 0.121, 0.24), vec3(0.005, 0.012, 0.040), night);
	vec3 color = mix(horizon, zenith, pow(altitude, 0.45));
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(horizon, color, smoothstep(-0.25, 0.04, ray.y));
		ALPHA = 1.0;
	} else if (AT_HALF_RES_PASS) {
		vec2 plane = ray.xz / (altitude + 0.23) * vec2(1.42, 2.76) + vec2(9.7, 2.4) + cloud_offset;
		vec2 warp = vec2(cloud_noise(plane * 0.78), cloud_noise(plane.yx * 0.67 + 21.0)) - 0.5;
		plane += warp * vec2(1.7, 1.3);
		mat2 turn = mat2(vec2(0.81, 0.59), vec2(-0.59, 0.81));
		vec2 octave = turn * plane * 2.13 + 3.7;
		float mass = cloud_noise(plane) * 0.46 + cloud_noise(octave) * 0.28;
		octave = turn * octave * 2.08 - 2.9;
		mass += cloud_noise(octave) * 0.15;
		octave = turn * octave * 2.12 + 5.3;
		mass += cloud_noise(octave) * 0.08 + cloud_noise(turn * octave * 2.03) * 0.03;
		float edge = mix(0.51, 0.27, storm);
		float cloud = smoothstep(edge - 0.075, edge + 0.14, mass) * smoothstep(0.0, 0.14, altitude);
		float rim = (1.0 - smoothstep(edge + 0.015, edge + 0.14, mass)) * pow(sun, 3.0);
		vec3 underside = mix(vec3(0.32, 0.40, 0.51), vec3(0.12, 0.15, 0.23), storm);
		vec3 peach = vec3(0.71, 0.44, 0.26) * rim;
		COLOR = mix(underside + peach, vec3(0.038, 0.059, 0.096) + rim * 0.04, night);
		ALPHA = cloud * 0.92;
	} else {
		color += mix(vec3(0.91, 0.40, 0.16), vec3(0.16, 0.28, 0.62), night)
			* (pow(sun, 27.0) * 0.36 + pow(sun, 220.0) * 0.52) * (1.0 - storm * 0.6);
		float disk = smoothstep(0.99935, 0.99958, sun) * (1.0 - storm * 0.57);
		color += mix(vec3(8.2, 5.0, 2.4), vec3(1.75, 2.12, 3.0), night) * disk;
		vec2 star_cell = floor(SKY_COORDS * 950.0);
		vec2 star_offset = fract(SKY_COORDS * 950.0) - 0.5;
		float star = step(0.9986, hash(star_cell)) * (1.0 - smoothstep(0.03, 0.43, length(star_offset)));
		color += vec3(0.36, 0.46, 0.66) * star * night * altitude;
		color = mix(color, HALF_RES_COLOR.rgb, HALF_RES_COLOR.a);
		COLOR = mix(horizon * 0.68, color, smoothstep(-0.22, 0.035, ray.y));
	}
}
