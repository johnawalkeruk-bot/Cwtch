shader_type spatial;
render_mode cull_disabled;
varying vec3 point;
void vertex() { point = VERTEX; }
void fragment() {
 float ripple = sin(point.z*3.0 + TIME*1.3 + sin(point.x*6.0)) * sin(point.x*10.0-TIME*0.8);
 ALBEDO = mix(vec3(0.10,0.22,0.23), vec3(0.32,0.42,0.40), ripple*0.5+0.5);
 NORMAL = normalize(NORMAL + vec3(ripple*0.08,0.0,cos(point.z*4.0+TIME)*0.12));
 ROUGHNESS = 0.26;
 SPECULAR = 0.7;
}
