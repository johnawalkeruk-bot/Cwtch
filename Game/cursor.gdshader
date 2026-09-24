shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 highlight : source_color = vec4(1.0, 0.85, 0.45, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ring = smoothstep(0.83, 0.89, radius) * (1.0 - smoothstep(0.96, 1.0, radius));
	float swirl = pow(0.5 + 0.5 * sin(angle * 3.0 - TIME * 2.0 + radius * 7.0), 3.0);
	ALBEDO = mix(vec3(0.21,0.62,0.92), highlight.rgb, swirl);
	ALPHA = ring * (0.35 + 0.65 * swirl) * highlight.a;
}
