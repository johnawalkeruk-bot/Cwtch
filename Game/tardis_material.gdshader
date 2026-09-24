shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D glow_map : source_color, filter_linear_mipmap;
uniform sampler2D gloss_map : filter_linear_mipmap;
uniform float presence : hint_range(0.0,1.0) = 1.0;
uniform float lamp_energy = 0.3;
void fragment() {
 float noise = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
 if (presence < 0.001 || noise > presence) { discard; }
 ALBEDO = texture(color_map,UV).rgb;
 NORMAL_MAP = texture(normal_map,UV).rgb;
 ROUGHNESS = clamp(1.0-texture(gloss_map,UV).r,0.45,0.95);
 METALLIC = 0.0;
 SPECULAR = 0.25;
 EMISSION = texture(glow_map,UV).rgb*lamp_energy;
}
