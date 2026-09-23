shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stone_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_ao : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float grain = sin(world_point.x * 61.0 + sin(world_point.z * 37.0))
		* sin(world_point.y * 53.0 + world_point.z * 29.0);
	float patch = sin(world_point.x * 4.1 + world_point.z * 3.5) * sin(world_point.z * 7.0 + world_point.y * 4.0);
	vec3 stone = texture(stone_color, UV).rgb * mix(0.85, 1.08, COLOR.r);
	float moss = smoothstep(0.05, 0.65, patch + max(world_normal.y, 0.0) * 0.3);
	ALBEDO = mix(stone, stone * vec3(0.72, 0.88, 0.48), moss * 0.5) * (0.95 + grain * 0.05);
	ROUGHNESS = texture(stone_roughness, UV).r;
	AO = mix(1.0, texture(stone_ao, UV).r, 0.65);
	NORMAL_MAP = texture(stone_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.65;
}
