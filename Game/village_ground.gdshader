shader_type spatial;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness = 0.0;
varying vec2 point;
void vertex(){ point=VERTEX.xz; }
void fragment(){
 float edge=abs(point.x)+sin(point.y*1.7)*0.10+sin(point.y*4.1)*0.035;
 float road=(1.0-smoothstep(2.6,3.4,edge))*(1.0-smoothstep(23.0,31.0,abs(point.y+4.0)));
 vec3 grass=texture(color_maps,vec3(point,1.0)).rgb;
 vec3 gravel=texture(color_maps,vec3(point,3.0)).rgb;
 ALBEDO=mix(grass,gravel,road)*(1.0-wetness*0.28);
 vec3 n=mix(texture(normal_maps,vec3(point,1.0)).xyz,texture(normal_maps,vec3(point,3.0)).xyz,road)*2.0-1.0;
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX*MODEL_MATRIX)*vec3(n.x,0.0,-n.y)*0.45);
 ROUGHNESS=mix(0.98,0.84,wetness);
 SPECULAR=0.1;
}
