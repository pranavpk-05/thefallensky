shader_type spatial;

uniform vec4 base_tint : source_color;
uniform vec4 wear_tint : source_color;
uniform bool metal_surface = false;
uniform float wetness = 0.0;
varying vec3 world;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.13);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float weather_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 t = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	float lower = mix(mix(hash(cell), hash(cell + vec3(1, 0, 0)), t.x),
		mix(hash(cell + vec3(0, 1, 0)), hash(cell + vec3(1, 1, 0)), t.x), t.y);
	float upper = mix(mix(hash(cell + vec3(0, 0, 1)), hash(cell + vec3(1, 0, 1)), t.x),
		mix(hash(cell + vec3(0, 1, 1)), hash(cell + vec3(1, 1, 1)), t.x), t.y);
	return mix(lower, upper, t.z);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float mottling = weather_noise(world * 4.8);
	float streaks = weather_noise(world * vec3(29.0, 2.2, 27.0));
	float scratches = weather_noise(world * vec3(93.0, 7.0, 91.0));
	float stains = smoothstep(0.42, 0.81, mottling * 0.65 + streaks * 0.31 + scratches * 0.11);
	ALBEDO = mix(base_tint.rgb, wear_tint.rgb, stains) * (0.74 + 0.38 * streaks + 0.13 * scratches) * (1.0 - wetness * 0.14);
	ROUGHNESS = (metal_surface ? mix(0.44, 0.91, stains) : mix(0.68, 0.94, mottling)) - wetness * 0.20;
	METALLIC = metal_surface ? (1.0 - stains) * 0.51 : 0.0;
}
