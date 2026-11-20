shader_type spatial;
render_mode diffuse_burley;

uniform bool floating_rock = false;
uniform float wetness = 0.0;
uniform sampler2D gravel_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
	vec2 drift = vec2(grain(world.xz * 0.043), grain(world.zx * 0.051 + 37.0)) - 0.5;
	vec2 field = world.xz + drift * 18.0;
	float broad = grain(field * 0.066) * 0.66 + grain(field * 0.227) * 0.34;
	float scree = grain(field * 0.70 + world.y * 0.09);
	float fine = grain(world.xz * 3.6 + world.y * 4.2);
	float stratum = world.y * 0.57 + world.x * 0.062 + world.z * 0.071 + drift.x * 1.8;
	float shelf = smoothstep(0.75, 0.97, abs(sin(stratum * 2.6 + scree * 1.1)));
	float seam = grain(vec2(world.x + world.z * 0.35, stratum * 3.7) * 0.31);
	float slope = smoothstep(0.49, 0.82, up.y + (broad - 0.46) * 0.28);
	vec3 moss = mix(vec3(0.044, 0.070, 0.044), vec3(0.138, 0.172, 0.092), broad);
	moss = mix(moss, vec3(0.21, 0.205, 0.074), smoothstep(0.72, 0.99, scree) * 0.44);
	vec3 rock = mix(vec3(0.075, 0.091, 0.099), vec3(0.29, 0.268, 0.219), seam);
	rock *= 1.0 - shelf * (0.13 + scree * 0.24);
	rock = mix(rock, vec3(0.176, 0.224, 0.106), smoothstep(0.54, 0.84, broad) * smoothstep(-0.1, 0.62, up.y) * 0.62);
	float river = abs(world.x - (30.0 + 15.0 * sin(world.z * 0.021) + 6.0 * sin(world.z * 0.052)));
	float bank = (1.0 - smoothstep(6.0, 11.0, river)) * (1.0 - smoothstep(3.0, 7.0, world.y));
	vec3 color = mix(rock, moss, slope);
	float crust = 0.79 + fine * 0.29 + scree * 0.12;
	float gauge_track = 0.0;
	float pooled = 0.0;
	if (!floating_rock) {
		color = mix(color, mix(vec3(0.13, 0.115, 0.065), vec3(0.30, 0.28, 0.18), scree), bank * 0.72);
		vec2 offset = world.xz - vec2(-32.0, -38.0);
		vec2 route = vec2(-21.0, -27.0);
		float progress = clamp(dot(offset, route) / dot(route, route), 0.0, 1.0);
		float track = 1.0 - smoothstep(0.51, 1.47, length(offset - route * progress) + (scree - 0.5) * 0.53);
		color = mix(color, vec3(0.202, 0.151, 0.093) * (0.58 + scree * 0.61), track * 0.64);
		vec2 lane = world.xz - vec2(-4.0, -43.5);
		vec2 bearing = vec2(-2.8, -15.4);
		float along = clamp(dot(lane, bearing) / dot(bearing, bearing), 0.0, 1.0);
		vec2 crossfall = lane - bearing * along;
		gauge_track = 1.0 - smoothstep(1.0, 2.35, length(crossfall) + (scree - 0.5) * 0.93);
		float shale = smoothstep(0.62, 0.83, fine);
		vec3 ballast = mix(vec3(0.115, 0.091, 0.065), vec3(0.245, 0.221, 0.188), shale * 0.87);
		color = mix(color, ballast * (0.69 + scree * 0.54), gauge_track * 0.94);
		float rut = 1.0 - smoothstep(0.10, 0.49, abs(length(crossfall) - 0.59));
		pooled = gauge_track * rut * smoothstep(0.38, 0.70, scree) * wetness;
		color *= 1.0 - pooled * 0.37;
	} else {
		color *= mix(0.64, 1.0, smoothstep(-0.78, 0.5, up.y));
	}
	float shadow = smoothstep(0.45, 0.66, grain(world.xz * 0.017 + vec2(TIME * 0.011, -TIME * 0.009)));
	vec3 normal_weights = pow(abs(up), vec3(4.0));
	normal_weights /= max(dot(normal_weights, vec3(1.0)), 0.001);
	vec3 pebbles = texture(gravel_map, world.zy * 0.58).rgb * normal_weights.x
		+ texture(gravel_map, world.xz * 0.72).rgb * normal_weights.y
		+ texture(gravel_map, world.xy * 0.58).rgb * normal_weights.z;
	float grit = clamp(dot(pebbles, vec3(0.213, 0.715, 0.072)) * 3.65, 0.34, 1.42);
	ALBEDO = color * crust * mix(0.66 + grit * 0.38, grit, gauge_track * 0.85)
		* (1.0 - shadow * 0.16) * (1.0 - wetness * 0.16);
	ROUGHNESS = 0.88 + fine * 0.09 - wetness * (0.22 + shelf * 0.15) - pooled * 0.29;
	SPECULAR = 0.28 + pooled * 0.21;
}
