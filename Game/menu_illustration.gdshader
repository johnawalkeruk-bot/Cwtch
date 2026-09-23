shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
void fragment() {
 vec3 tint = mix(vec3(0.22,0.35,0.52),vec3(1.0),daylight);
 ALBEDO = COLOR.rgb * tint * (1.0-rain_strength*0.16);
}
