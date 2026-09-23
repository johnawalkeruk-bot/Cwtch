shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_rough = false;
uniform bool has_metal = false;
uniform bool has_ao = false;
uniform sampler2D ao_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ao_channel = vec4(1,0,0,0);
uniform bool vertex_tint = false;
uniform bool double_sided = false;
uniform float cutoff = 0.001;
uniform float normal_strength = 1.0;
uniform float roughness_value = 1.0;
uniform float metal_value = 0.0;
uniform float wetness = 0.0;
uniform vec4 rough_channel = vec4(0,1,0,0);
uniform vec4 metal_channel = vec4(0,0,1,0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
void fragment(){
 if(!double_sided && !FRONT_FACING){discard;}
 vec2 uv=UV*uv_scale+uv_offset;
 vec4 paint=base_color;
 if(has_albedo){paint*=texture(albedo_map,uv);}
 if(vertex_tint){paint*=COLOR;}
 float metal=metal_value*(has_metal ? dot(texture(metal_map,uv),metal_channel) : 1.0);
 float dry=roughness_value*(has_rough ? dot(texture(rough_map,uv),rough_channel) : 1.0);
 ALBEDO=paint.rgb*(1.0-wetness*0.17*(1.0-metal));
 ALPHA=paint.a;
 ALPHA_SCISSOR_THRESHOLD=cutoff;
 METALLIC=metal;
 ROUGHNESS=mix(max(dry,mix(0.72,0.27,metal)),mix(0.48,0.22,metal),wetness*0.65);
 SPECULAR=mix(0.22,0.36,wetness);
 if(has_ao){AO=dot(texture(ao_map,uv),ao_channel);}
 if(!FRONT_FACING){NORMAL=-NORMAL;}
 if(has_normal){NORMAL_MAP=texture(normal_map,uv).rgb;NORMAL_MAP_DEPTH=normal_strength;}
}
