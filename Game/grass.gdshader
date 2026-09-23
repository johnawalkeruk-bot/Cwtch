shader_type spatial;
render_mode cull_disabled;
uniform float wind_time = 0.0;
uniform float rain_strength = 0.0;
uniform float wetness = 0.0;
uniform vec3 spirit_position;
uniform vec3 visitor_position;
uniform vec3 chicken_position;
varying float variation;

vec2 push_away(vec3 point, vec3 actor, float radius) {
	vec2 offset = point.xz - actor.xz;
	float distance_to_actor = length(offset);
	return offset / max(distance_to_actor, 0.01) * (1.0 - smoothstep(0.0, radius, distance_to_actor));
}
void vertex() {
	vec3 world_root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tip = UV.y * UV.y;
	float sway = sin(wind_time * 1.4 + world_root.x * 2.1 + world_root.z * 1.7 + INSTANCE_CUSTOM.x * 6.28);
	vec2 movement = vec2(sway, sway * 0.38) * (0.045 + rain_strength * 0.025);
	movement += push_away(world_root, spirit_position, 0.48) * 0.22;
	movement += push_away(world_root, visitor_position, 0.35) * 0.18;
	movement += push_away(world_root, chicken_position, 0.23) * 0.10;
	// Apply the bend in world space, preserving pinned roots and instance scale.
	VERTEX += (inverse(MODEL_MATRIX) * vec4(movement.x, -length(movement) * 0.35, movement.y, 0.0)).xyz * tip;
	variation = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec3 root_color = vec3(0.09, 0.18, 0.035);
	vec3 tip_color = mix(vec3(0.26, 0.39, 0.09), vec3(0.39, 0.44, 0.16), variation);
	ALBEDO = mix(root_color, tip_color, smoothstep(0.0, 1.0, UV.y)) * (1.0 - wetness * 0.16);
	ROUGHNESS = mix(0.92, 0.60, wetness);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
