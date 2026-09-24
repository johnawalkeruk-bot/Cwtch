shader_type spatial;
uniform sampler2D watered_tiles : filter_linear, repeat_disable;
render_mode cull_disabled;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2D water_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_opacity : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bottom_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bottom_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_min;
uniform vec2 grid_size;
uniform float micro_size;
uniform float wetness = 0.0;
uniform float rain_strength = 0.0;
uniform float water_time = 0.0;
uniform sampler2D bed_heights : filter_linear, repeat_disable;
uniform vec2 height_samples;
varying vec2 ground_position;
void vertex() {
 ground_position = VERTEX.xz;
 vec2 uv=((VERTEX.xz-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
 VERTEX.y += max(0.0,texture(bed_heights,uv).r);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float water_at(vec2 cell) {
 cell=clamp(cell,vec2(0),grid_size-1.0);
 int kind=int(floor(texture(terrain_ids,(cell+0.5)/grid_size).r*255.0+0.5));
 return kind==5 ? 0.65 : (kind==4 ? 0.28 : 0.0);
}
void fragment() {
 vec2 grid=(ground_position-grid_min)/micro_size-0.5;
 vec2 cell=floor(grid);
 vec2 f=smoothstep(vec2(0.30),vec2(0.70),fract(grid));
 float flood=mix(mix(water_at(cell),water_at(cell+vec2(1,0)),f.x),mix(water_at(cell+vec2(0,1)),water_at(cell+vec2(1)),f.x),f.y);
 vec2 height_uv=((ground_position-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
 float bed=texture(bed_heights,height_uv).r;
 float depth=max(0.0,-bed);
 bool pond=depth>0.003 && flood>0.01;
 // Fixed low spots expand as rain accumulates, then shrink as the ground dries.
 float low_spot=noise(ground_position*3.8)*0.75+noise(ground_position*9.0)*0.25;
 float moisture=max(wetness,texture(watered_tiles,(ground_position-grid_min)/(grid_size*micro_size)).r);
 float puddle=smoothstep(0.86-moisture*0.12,0.90-moisture*0.12,low_spot)*smoothstep(0.08,0.35,moisture);
 if(!pond && puddle<0.5) { discard; }
 vec2 uv=ground_position*0.7;
 vec2 flow=vec2(water_time*0.008,water_time*0.004);
 vec3 n1=texture(water_normal,uv+flow).xyz*2.0-1.0;
 vec3 n2=texture(water_normal,uv-flow*0.6).xyz*2.0-1.0;
 vec3 surface_color=texture(water_color,uv+flow).rgb;
 vec3 riverbed=texture(bottom_color,ground_position).rgb*mix(0.7,1.0,texture(bottom_ao,ground_position).r);
 float opacity=clamp(texture(water_opacity,uv+flow).r,0.25,0.85);
 vec3 tint=mix(vec3(0.13,0.30,0.28),vec3(0.035,0.13,0.19),smoothstep(0.1,0.65,depth));
 ALBEDO=pond ? tint*0.8+surface_color*0.2 : mix(riverbed,tint,0.72);
 ALPHA=pond ? clamp((1.0-exp(-depth*2.6))*0.7+opacity*0.18,0.34,0.88) : 0.65;
 ROUGHNESS=clamp(texture(water_roughness,uv+flow).r,0.23,0.44);
 SPECULAR=0.4;
 vec2 ripple_uv=fract(ground_position*5.0)-0.5;
 float ripple=sin(length(ripple_uv)*65.0-water_time*12.0)*exp(-length(ripple_uv)*5.0)*rain_strength;
 vec2 slope=(n1.xy+n2.xy)*(pond ? 0.10 : 0.035)+normalize(ripple_uv+vec2(0.0001))*ripple*0.07;
 NORMAL=normalize(mat3(VIEW_MATRIX*MODEL_MATRIX)*normalize(vec3(slope.x,1.0,slope.y)));
}
