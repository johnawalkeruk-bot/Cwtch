shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 haze_color : source_color = vec3(0.53,0.62,0.66);
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
uniform float scenery_time = 0.0;
varying vec3 point;
varying vec3 slope_normal;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;slope_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 vec3 blend=pow(abs(slope_normal),vec3(4.0));blend/=max(dot(blend,vec3(1.0)),0.0001);
 vec3 grass=texture(color_maps,vec3(point.xz,1.0)).rgb;
 vec3 soil=texture(color_maps,vec3(point.xz*0.8,0.0)).rgb;
 vec3 rock=texture(color_maps,vec3(point.yz*0.45,2.0)).rgb*blend.x+texture(color_maps,vec3(point.xz*0.45,2.0)).rgb*blend.y+texture(color_maps,vec3(point.xy*0.45,2.0)).rgb*blend.z;
 float steep=smoothstep(0.12,0.58,1.0-abs(slope_normal.y));
 float altitude=smoothstep(12.0,40.0,point.y);
 vec3 ground=mix(grass,soil,steep*0.35);
 ground=mix(ground,rock,max(steep,altitude));
 ground*=mix(vec3(1.0),vec3(0.72,0.82,0.96),altitude);
 float snow=smoothstep(43.0,67.0,point.y+sin(point.x*0.17)*3.0)*smoothstep(0.2,0.75,abs(slope_normal.y));
 ground=mix(ground,vec3(0.79,0.83,0.83),snow);
 float distance_haze=(1.0-exp(-max(distance(CAMERA_POSITION_WORLD,point)-45.0,0.0)*0.003));
 ALBEDO=mix(ground*(1.0-rain_strength*0.16),haze_color,distance_haze*0.24);
 ROUGHNESS=0.96;
 SPECULAR=0.1;
 if(!FRONT_FACING){NORMAL=-NORMAL;}
}
