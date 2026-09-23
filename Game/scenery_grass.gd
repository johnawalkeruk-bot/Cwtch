extends RefCounted
## Scatter on actual mesh triangles, never on an approximate hillside height.
static func plant(parent: Node3D, terrain: Mesh, label: String, density: float, max_height: float) -> void:
 var random:=RandomNumberGenerator.new()
 random.seed=1896
 var groups: Dictionary={}
 var arrays:=terrain.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 var count:=indices.size() if not indices.is_empty() else vertices.size()
 for i in range(0,count,3):
  var a:=vertices[indices[i] if not indices.is_empty() else i]
  var b:=vertices[indices[i+1] if not indices.is_empty() else i+1]
  var c:=vertices[indices[i+2] if not indices.is_empty() else i+2]
  var cross: Vector3=(b-a).cross(c-a)
  var area:=cross.length()*0.5
  if area<0.001:continue
  var normal:=cross.normalized()
  if normal.y<0:normal=-normal
  if normal.y<0.78 or (a.y+b.y+c.y)/3.0>max_height:continue
  var expected:=area*density
  var amount:=mini(100,floori(expected)+(1 if random.randf()<fposmod(expected,1.0) else 0))
  for j in range(amount):
   var u:=sqrt(random.randf())
   var v:=random.randf()
   var point: Vector3=(1.0-u)*a+u*(1.0-v)*b+u*v*c+Vector3.UP*0.01
   var key:=Vector2i(floori(point.x/16),floori(point.z/16))
   if not groups.has(key):groups[key]=[]
   var scale_factor:=random.randf_range(1.3,2.7)
   groups[key].append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*scale_factor),point))
 var generator:=preload("res://meadow_grass.gd").new()
 var tuft:=generator._tuft()
 generator.free()
 var material:=ShaderMaterial.new()
 material.shader=preload("res://meadow_grass.gdshader")
 material.set_shader_parameter("scenery_only",true)
 material.set_shader_parameter("grid_size",Vector2(36,36))
 for key: Vector2i in groups:
  var batch:=MultiMesh.new()
  batch.transform_format=MultiMesh.TRANSFORM_3D
  batch.mesh=tuft
  batch.instance_count=groups[key].size()
  for i in range(batch.instance_count):batch.set_instance_transform(i,groups[key][i])
  var node:=MultiMeshInstance3D.new()
  node.name=label+"_%d_%d"%[key.x,key.y]
  node.multimesh=batch
  node.material_override=material
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.extra_cull_margin=0.8
  node.visibility_range_end=220.0
  parent.add_child(node)

