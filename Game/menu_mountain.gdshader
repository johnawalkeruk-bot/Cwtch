shader_type spatial;
uniform float rain_strength = 0.0;
void fragment() {
 ALBEDO = COLOR.rgb * (1.0-rain_strength*0.14);
 ROUGHNESS = mix(0.93,0.65,rain_strength);
}
