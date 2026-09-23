shader_type spatial;
uniform sampler2D watered_tiles : filter_linear, repeat_disable;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray detail_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_size = vec2(9.0);
uniform vec2 grid_min = vec2(-3.0);
uniform float micro_size = 0.666666667;
uniform mat4 world_to_grid;
uniform float repeats_per_metre = 1.0;
uniform float relief_metres = 0.012;
uniform bool pom_enabled = true;
uniform bool orthographic_view = false;
uniform float wetness = 0.0;
uniform sampler2D riverbed_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool background_surface = false;
uniform sampler2D brush_weights : filter_linear, repeat_disable;
uniform float background_width = 160.0;
varying vec2 ground_position;
varying vec3 eye_position;
varying vec3 orthographic_direction;
void vertex() {
 ground_position = (world_to_grid * MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
 eye_position = (world_to_grid * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
 orthographic_direction = (world_to_grid * INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
}
int terrain_at(vec2 cell) {
 cell = clamp(cell, vec2(0.0), grid_size - 1.0);
 return int(floor(texture(terrain_ids, (cell + 0.5) / grid_size).r * 255.0 + 0.5));
}
float layer(int kind) {
 if (kind == 2) { return 1.0; }
 if (kind == 3) { return 4.0; }
 if (kind == 7) { return 2.0; }
 if (kind == 6) { return 3.0; }
 return 0.0;
}
vec4 weights(vec2 blend) {
 return vec4((1.0-blend.x)*(1.0-blend.y), blend.x*(1.0-blend.y), (1.0-blend.x)*blend.y, blend.x*blend.y);
}
vec3 details(vec2 uv, vec4 layers, vec4 w, vec2 dx, vec2 dy) {
 vec3 result = vec3(0.0);
 for (int i=0; i<4; i++) {
  if(w[i] > 0.001) { result += textureGrad(detail_maps, vec3(uv,layers[i]),dx,dy).rgb*w[i]; }
 }
 return result;
}
void fragment() {
 vec2 grid = (ground_position-grid_min)/micro_size-0.5;
 vec2 cell = floor(grid);
 vec4 w = weights(smoothstep(vec2(0.30),vec2(0.70),fract(grid)));
 ivec4 kinds = ivec4(terrain_at(cell),terrain_at(cell+vec2(1,0)),terrain_at(cell+vec2(0,1)),terrain_at(cell+vec2(1)));
 vec4 layers = vec4(layer(kinds.x),layer(kinds.y),layer(kinds.z),layer(kinds.w));
 if(background_surface) {
  w=texture(brush_weights,ground_position/background_width+0.5);
  w/=max(dot(w,vec4(1.0)),0.0001);
  layers=vec4(1.0,4.0,0.0,2.0);
  kinds=ivec4(2,3,0,7);
 }
 vec2 uv = ground_position*repeats_per_metre;
 vec2 dx = dFdx(uv);
 vec2 dy = dFdy(uv);
 vec3 view = normalize(eye_position-vec3(ground_position.x,0,ground_position.y));
 if(orthographic_view) { view=normalize(orthographic_direction); }
 if(pom_enabled) {
  float count = floor(mix(28.0,10.0,abs(view.y)));
  float step_depth = 1.0/count;
  vec2 step_uv = -view.xz/max(abs(view.y),0.15)*relief_metres*repeats_per_metre/count;
  step_uv *= smoothstep(0.02,0.15,abs(view.y));
  float depth = 0.0;
  float surface_depth = 1.0-details(uv,layers,w,dx,dy).r;
  float previous_surface = surface_depth;
  vec2 previous_uv = uv;
  for(int i=0;i<28;i++) {
   if(depth>=surface_depth || float(i)>=count) { break; }
   previous_uv=uv;
   previous_surface=surface_depth;
   uv+=step_uv;
   depth+=step_depth;
   surface_depth=1.0-details(uv,layers,w,dx,dy).r;
  }
  float after=depth-surface_depth;
  float before=depth-step_depth-previous_surface;
  uv=mix(uv,previous_uv,clamp(after/max(after-before,0.00001),0.0,1.0));
 }
 vec3 color=vec3(0);
 vec3 mapped_normal=vec3(0);
 for(int i=0;i<4;i++) {
  if(w[i]>0.001) {
   vec3 tint = kinds[i]==1 ? vec3(0.84,0.80,0.73) : vec3(1.0);
   vec3 sampled_color=textureGrad(color_maps,vec3(uv,layers[i]),dx,dy).rgb;
   if(kinds[i]==4 || kinds[i]==5) { sampled_color=textureGrad(riverbed_color,uv,dx,dy).rgb; }
   color+=sampled_color*w[i]*tint;
   mapped_normal+=(textureGrad(normal_maps,vec3(uv,layers[i]),dx,dy).xyz*2.0-1.0)*w[i];
  }
 }
 vec3 data=details(uv,layers,w,dx,dy);
 float moisture=max(wetness,background_surface ? 0.0 : texture(watered_tiles,(ground_position-grid_min)/(grid_size*micro_size)).r);
 ALBEDO=color * (1.0 - moisture * 0.28);
 ROUGHNESS=mix(clamp(data.g,0.25,1.0),0.32,moisture*0.65);
 AO=mix(1.0,data.b,0.65);
 // UVs increase in world +X/+Z: OpenGL map green points toward -Z.
 vec3 normal=normalize(vec3(mapped_normal.x*0.65,mapped_normal.z,-mapped_normal.y*0.65));
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX*MODEL_MATRIX)*vec3(normal.x,0.0,normal.z));
}
