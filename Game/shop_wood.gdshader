shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 wood_tint : source_color = vec4(0.46,0.32,0.19,1.0);
varying vec3 wood_position;
float hash21(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float grain_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex(){wood_position=VERTEX;}
void fragment(){
 float grain=grain_noise(vec2(wood_position.x*45.0,wood_position.z*2.0+wood_position.y*1.5));
 float bands=sin(wood_position.x*110.0+grain*3.0)*0.008;
 ALBEDO=wood_tint.rgb*(0.96+grain*0.05+bands);
 ROUGHNESS=0.9;SPECULAR=0.18;
}
