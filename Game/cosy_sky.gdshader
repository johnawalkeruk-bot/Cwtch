shader_type sky;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.25);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.15;
uniform float cycle_time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = direction.y;
	vec3 horizon = vec3(0.77, 0.73, 0.65);
	vec3 zenith = vec3(0.38, 0.49, 0.55);
	float twilight = (1.0-smoothstep(0.02,0.38,abs(sun_direction.y)))*smoothstep(-0.22,0.02,sun_direction.y);
	horizon=mix(horizon,vec3(0.95,0.61,0.44),twilight*0.75);
	zenith=mix(zenith,vec3(0.47,0.40,0.57),twilight*0.7);
	vec3 sky_color = mix(horizon, zenith, smoothstep(0.0, 0.9, height));
	// Direction-space noise keeps the panorama seamless, including its poles.
	vec2 cloud_uv = direction.xz * 3.0 / (0.6 + abs(height)) + vec2(cycle_time * 0.0008, 0.0);
	float cloud = noise(cloud_uv) * 0.65 + noise(cloud_uv * 2.7) * 0.35;
	sky_color = mix(sky_color, vec3(0.86, 0.82, 0.73), smoothstep(0.38, 0.8, cloud) * 0.42);
	// Mountain silhouettes now come from actual distant geometry.
	sky_color = mix(vec3(0.015, 0.022, 0.045) + sky_color * 0.055, sky_color, daylight);
	sky_color = mix(sky_color, mix(vec3(0.025,0.035,0.06),vec3(0.39,0.44,0.46),daylight), cloud_cover * 0.65);
	float sun = smoothstep(0.9993, 0.9998, dot(direction, normalize(sun_direction)));
	float halo = pow(max(dot(direction, normalize(sun_direction)),0.0), 90.0);
	float moon = smoothstep(0.9994, 0.9998, dot(direction, -normalize(sun_direction)));
	float stars = step(0.997, hash(floor(direction.xz / (abs(height)+0.2)*360.0))) * smoothstep(0.1,0.35,height);
	sky_color += vec3(1.0,0.72,0.36) * (sun * 1.6 + halo * 0.18) * (1.0-cloud_cover*0.8);
	sky_color += (vec3(0.6,0.72,0.9)*moon + vec3(stars*0.45*pow(1.0-daylight,3.0)))*(1.0-daylight)*(1.0-cloud_cover);
	COLOR = sky_color;
}
