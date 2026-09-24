extends Node3D
var material: ShaderMaterial
var noise:=FastNoiseLite.new()
func height_at(p: Vector2) -> float:
 var outside: float=(p.abs()-Vector2(14,28)).max(Vector2.ZERO).length()
 return maxf(0.0,0.35+noise.get_noise_2dv(p)*0.7)*smoothstep(0.0,10.0,outside)
func build(village: Node3D) -> void:
 noise.seed=1891
 noise.frequency=0.10
 var plane:=PlaneMesh.new()
 plane.size=Vector2(440,440)
 plane.subdivide_width=219
 plane.subdivide_depth=219
 var arrays:=plane.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in vertices.size():vertices[i].y=height_at(Vector2(vertices[i].x,vertices[i].z))
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var builder:=SurfaceTool.new()
 builder.create_from(mesh,0)
 builder.generate_normals()
 var ground:=MeshInstance3D.new()
 ground.name='VillageMeadow'
 ground.mesh=builder.commit()
 material=ShaderMaterial.new()
 material.shader=preload('res://village_ground.gdshader')
 material.set_shader_parameter('color_maps',load('res://assets/textures/terrain_colors.res'))
 material.set_shader_parameter('normal_maps',load('res://assets/textures/terrain_normals.res'))
 ground.material_override=material
 add_child(ground)
 # Grass strips frame the street without growing through shop floors or the road.
 for side in [-1,1]:
  for band in [Vector2(19,10),Vector2(3.7,0.5)]:
   var patch:=PlaneMesh.new()
   patch.size=Vector2(band.y,54)
   patch.subdivide_width=maxi(1,ceili(band.y)-1)
   patch.subdivide_depth=26
   var data:=patch.surface_get_arrays(0)
   var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
   for i in points.size():points[i]+=Vector3(side*band.x,0,0)
   data[Mesh.ARRAY_VERTEX]=points
   var strip:=ArrayMesh.new()
   strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
   preload('res://scenery_grass.gd').plant(self,strip,'VillageVerge',3.0,2.0)
 var landscape:=preload('res://valley_landscape.gd').new()
 add_child(landscape)
 landscape.scale=Vector3.ONE*1.5
 landscape.build(village)
