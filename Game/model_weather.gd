extends Node
## Per-scene material copies preserve imported meshes and animation resources.
var scene: Node
var materials: Dictionary = {}
var seen: Dictionary = {}
var scan_time := 0.0
var wetness := 0.0

func setup(root: Node) -> void:
 scene=root
 _scan(scene)

func _channel(index: int) -> Vector4:
 return [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(0.333,0.333,0.333,0)][clampi(index,0,4)]

func _convert(source: Material) -> Material:
 if not source is StandardMaterial3D: return source
 if source.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED: return source
 if source.emission_enabled or source.uv1_triplanar or source.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED: return source
 if source.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]: return source
 var key := source.get_instance_id()
 if materials.has(key): return materials[key]
 var result := ShaderMaterial.new()
 result.shader=preload("res://model_weather.gdshader")
 result.set_shader_parameter("base_color",source.albedo_color)
 result.set_shader_parameter("vertex_tint",source.vertex_color_use_as_albedo)
 result.set_shader_parameter("double_sided",source.cull_mode==BaseMaterial3D.CULL_DISABLED)
 result.set_shader_parameter("cutoff",source.alpha_scissor_threshold if source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.001)
 result.set_shader_parameter("roughness_value",source.roughness)
 result.set_shader_parameter("metal_value",source.metallic)
 result.set_shader_parameter("rough_channel",_channel(source.roughness_texture_channel))
 result.set_shader_parameter("metal_channel",_channel(source.metallic_texture_channel))
 result.set_shader_parameter("normal_strength",source.normal_scale)
 result.set_shader_parameter("has_ao",source.ao_enabled and source.ao_texture!=null)
 if source.ao_texture!=null:result.set_shader_parameter("ao_map",source.ao_texture)
 result.set_shader_parameter("ao_channel",_channel(source.ao_texture_channel))
 result.set_shader_parameter("uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y))
 result.set_shader_parameter("uv_offset",Vector2(source.uv1_offset.x,source.uv1_offset.y))
 for pair in [["albedo",source.albedo_texture],["normal",source.normal_texture if source.normal_enabled else null],["rough",source.roughness_texture],["metal",source.metallic_texture]]:
  result.set_shader_parameter("has_"+pair[0],pair[1]!=null)
  if pair[1]!=null:result.set_shader_parameter(pair[0]+"_map",pair[1])
 materials[key]=result
 return result

func _scan(node: Node) -> void:
 if not seen.has(node.get_instance_id()):
  if node is MeshInstance3D and node.mesh:
   if node.material_override:
    node.material_override=_convert(node.material_override)
   else:
    for i in range(node.mesh.get_surface_count()):
     node.set_surface_override_material(i,_convert(node.get_active_material(i)))
  elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
   if node.material_override:node.material_override=_convert(node.material_override)
   else:
    var mesh: Mesh = node.multimesh.mesh.duplicate()
    for i in range(mesh.get_surface_count()):mesh.surface_set_material(i,_convert(mesh.surface_get_material(i)))
    node.multimesh.mesh=mesh
  seen[node.get_instance_id()]=true
 for child in node.get_children(): _scan(child)

func _process(delta: float) -> void:
 if not is_instance_valid(scene):return
 scan_time+=delta
 if scan_time>=2.0:
  scan_time=0.0
  _scan(scene)
 var rain: float = scene.valley_cycle.rain_strength if scene.get("valley_cycle")!=null else scene.rain_strength
 wetness=move_toward(wetness,rain,delta/(25.0 if rain>wetness else 80.0))
 for material: ShaderMaterial in materials.values():material.set_shader_parameter("wetness",wetness)
