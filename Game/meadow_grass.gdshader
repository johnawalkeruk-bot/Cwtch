shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bed_heights : filter_linear, repeat_disable;
uniform sampler2D original_heights : filter_linear, repeat_disable;
uniform vec2 height_samples;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2D exclusions : filter_nearest, repeat_disable;
uniform vec2 grid_min;
uniform vec2 grid_size;
uniform bool scenery_only = false;
uniform float micro_size = 0.6666667;
varying float present;
varying float tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = (root.xz - grid_min) / micro_size;
	bool inside = !scenery_only && all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, grid_size));
	vec2 map_uv = (floor(cell) + 0.5) / grid_size;
	float kind = floor(texture(terrain_ids, map_uv).r * 255.0 + 0.5);
	present = inside ? ((kind == 2.0 || kind == 3.0) ? 1.0 : 0.0) : 1.0;
	if (inside && texture(exclusions, map_uv).r > 0.5) { present = 0.0; }
	float height_scale = inside ? (kind == 3.0 ? 1.9 : 0.75) : 1.45;
	float tip_weight = UV.y * UV.y;
	VERTEX.y *= height_scale;
	VERTEX.x += sin(TIME * 1.4 + root.x * 0.7 + root.z * 0.4) * 0.035 * tip_weight;
	VERTEX.z += sin(TIME * 1.0 + root.z * 0.8) * 0.022 * tip_weight;
	if (inside) {
	 vec2 height_uv=((root.xz-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
	 float shift=texture(bed_heights,height_uv).r-texture(original_heights,height_uv).r;
	 VERTEX.y+=shift/max(length(MODEL_MATRIX[1].xyz),0.001);
	}
	VERTEX *= present;
	tint = sin(root.x * 12.3 + root.z * 7.1) * 0.5 + 0.5;
}

void fragment() {
	if (present < 0.5) { discard; }
	vec3 base = mix(vec3(0.15, 0.22, 0.075), vec3(0.28, 0.34, 0.12), tint);
	ALBEDO = mix(base * 0.7, base * 1.3, clamp(UV.y, 0.0, 1.0)) * COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}
