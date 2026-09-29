shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 region_min=vec2(0.0);
uniform vec2 region_max=vec2(1.0);
void fragment(){
 vec3 blurred=vec3(0.0);
 for(int x=-1;x<=1;x++){
  for(int y=-1;y<=1;y++){
   vec2 sample_uv=clamp(SCREEN_UV+vec2(float(x),float(y))*SCREEN_PIXEL_SIZE*3.0,region_min+SCREEN_PIXEL_SIZE*4.0,region_max-SCREEN_PIXEL_SIZE*4.0);
   blurred+=texture(screen_texture,sample_uv).rgb/9.0;
  }
 }
 COLOR=vec4(mix(blurred,vec3(0.025,0.09,0.075),0.64),1.0);
}
