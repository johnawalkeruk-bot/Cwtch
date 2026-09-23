shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.8,0.83,0.83);
uniform float opacity = 0.2;
uniform float drift_time = 0.0;
uniform float softness = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void fragment() {
 vec2 q=UV*2.0-1.0;
 float edge=pow(1.0-smoothstep(0.05,1.0,dot(q,q)),max(2.0,softness));
 float cloud=noise(UV*vec2(6,3)+vec2(drift_time*0.004,0))*0.6+noise(UV*vec2(13,5)-vec2(drift_time*0.002,0))*0.4;
 ALBEDO=tint;
 ALPHA=edge*smoothstep(0.26,0.72,cloud)*opacity;
}
