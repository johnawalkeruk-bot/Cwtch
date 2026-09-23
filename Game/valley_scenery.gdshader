shader_type spatial;
render_mode cull_disabled;
uniform vec3 haze_color : source_color = vec3(0.53,0.62,0.66);
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
uniform float scenery_time = 0.0;
uniform bool vegetation = false;
varying vec3 world_point;
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if(vegetation) {
  VERTEX.x += sin(scenery_time*0.7+world_point.x*0.4+world_point.z*0.3)*min(VERTEX.y,5.0)*0.012;
 }
}
void fragment() {
 float distance_to_eye=distance(CAMERA_POSITION_WORLD,world_point);
 float ground_mist=exp(-max(world_point.y,0.0)*0.075);
 float haze=(1.0-exp(-max(distance_to_eye-18.0,0.0)*(0.003+rain_strength*0.006)))*mix(0.35,0.85,ground_mist);
 ALBEDO=mix(COLOR.rgb,haze_color,haze*0.65);
 EMISSION=haze_color*haze*(0.14+daylight*0.12);
 ROUGHNESS=0.95;
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
}
