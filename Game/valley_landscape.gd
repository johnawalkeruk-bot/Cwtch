extends Node3D
## Real geometry at distinct distances creates parallax as the spirit moves.
var garden: Node3D
var rng := RandomNumberGenerator.new()
var terrain_material: ShaderMaterial
var plants_material: ShaderMaterial
var mist_material: ShaderMaterial
var cloud_material: ShaderMaterial
var wisps: Array[MeshInstance3D] = []
var clouds: Array[MeshInstance3D] = []
var pine_count := 0
var deciduous_count := 0
var wild_count := 0

func build(world: Node3D) -> void:
 garden = world
 name = "LayeredValley"
 rng.seed = 1891
 terrain_material = ShaderMaterial.new()
 terrain_material.shader = preload("res://valley_scenery.gdshader")
 plants_material = terrain_material.duplicate()
 plants_material.set_shader_parameter("vegetation", true)
 terrain_material.shader = preload("res://landscape_surface.gdshader")
 terrain_material.set_shader_parameter("color_maps",load("res://assets/textures/terrain_colors.res"))
 _ridge(false)
 _ridge(true)
 _forest()
 _wild_edge()
 mist_material = ShaderMaterial.new()
 mist_material.shader = preload("res://valley_wisp.gdshader")
 cloud_material = mist_material.duplicate()
 cloud_material.set_shader_parameter("softness", 0.6)
 for i in range(18):
  var angle := float(i) * TAU / 18.0
  var radius := rng.randf_range(35,85)
  var position := Vector3(cos(angle)*radius,rng.randf_range(2,6),sin(angle)*radius)
  wisps.append(_wisp(position,Vector2(rng.randf_range(22,40),rng.randf_range(5,9)),mist_material))
 for i in range(14):
  var angle := float(i) * TAU / 14.0
  var radius := rng.randf_range(75,135)
  var cloud := _wisp(Vector3(cos(angle)*radius,rng.randf_range(27,48),sin(angle)*radius),Vector2(rng.randf_range(30,60),rng.randf_range(8,16)),cloud_material)
  cloud.set_meta("origin",cloud.position)
  clouds.append(cloud)
 update_atmosphere()

func _ridge_height(radius: float, angle: float, far: bool) -> float:
 if far:
  var profile := maxf(0.0,1.0-absf(radius-137.0)/59.0)
  var peak := 37.0+16.0*sin(angle*5.0+0.7)+11.0*sin(angle*9.0-0.6)+7.0*cos(angle*13.0)
  return pow(profile,1.05)*peak
 var profile := maxf(0.0,1.0-absf(radius-46.0)/22.0)
 return pow(profile,1.6)*(7.0+3.0*sin(angle*3.0)+2.0*cos(angle*7.0))

func _ridge(far: bool) -> void:
 var segments := 112 if far else 96
 var rows := 12 if far else 9
 var start := 78.0 if far else 24.0
 var end := 196.0 if far else 68.0
 var points: Array[Vector3] = []
 for row in range(rows+1):
  var radius := lerpf(start,end,float(row)/rows)
  for col in range(segments):
   var angle := float(col)*TAU/segments
   var h := _ridge_height(radius,angle,far)
   if row>0 and row<rows:
    h += rng.randf_range(-1.4,1.4) if far else rng.randf_range(-0.25,0.25)
   points.append(Vector3(cos(angle)*radius,maxf(0,h),sin(angle)*radius))
 var builder := SurfaceTool.new()
 builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(rows):
  for col in range(segments):
   var a := row*segments+col
   var b := row*segments+(col+1)%segments
   var c := (row+1)*segments+col
   var d := (row+1)*segments+(col+1)%segments
   for tri in [[a,c,b],[b,c,d]]:
    var normal: Vector3 = (points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
    if normal.y < 0: normal = -normal
    var height: float = (points[tri[0]].y+points[tri[1]].y+points[tri[2]].y)/3.0
    var color := Color("5a7042").lerp(Color("8b8962"),clampf(height/12.0,0,1))
    if far:
     color=Color("526277").lerp(Color("898a9e"),clampf(height/60.0,0,1))
     if height>37.0 and normal.y>0.3:
      color=color.lerp(Color("d7dbd9"),smoothstep(37,60,height)*0.8)
    color *= rng.randf_range(0.88,1.12)
    for index in tri:
     builder.set_color(color.srgb_to_linear())
     builder.set_normal(normal)
     builder.add_vertex(points[index])
 var mesh := MeshInstance3D.new()
 mesh.name = "SnowdoniaPeaks" if far else "WoodedRidges"
 mesh.mesh = builder.commit()
 mesh.material_override = terrain_material
 add_child(mesh)
 preload("res://scenery_grass.gd").plant(self,mesh.mesh,"MountainGrass" if far else "RidgeGrass",0.025 if far else 1.2,26.0 if far else 11.0)

func _append(builder: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
 var data := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
 for i in range(indices.size() if not indices.is_empty() else vertices.size()):
  var index := indices[i] if not indices.is_empty() else i
  builder.set_color(color.srgb_to_linear())
  builder.set_normal((transform.basis.inverse().transposed()*normals[index]).normalized())
  builder.add_vertex(transform*vertices[index])

func _ball(radius: float, height: float) -> SphereMesh:
 var mesh := SphereMesh.new()
 mesh.radius=radius
 mesh.height=height
 mesh.radial_segments=7
 mesh.rings=3
 return mesh

func _prototype(kind: String) -> ArrayMesh:
 var builder := SurfaceTool.new()
 builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 if kind in ["pine","broadleaf"]:
  var trunk := CylinderMesh.new()
  trunk.top_radius=0.10
  trunk.bottom_radius=0.19
  trunk.height=2.4
  trunk.radial_segments=6
  _append(builder,trunk,Transform3D(Basis.IDENTITY,Vector3(0,1.2,0)),Color("64503b"))
  if kind=="pine":
   for i in range(3):
    var cone := CylinderMesh.new()
    cone.top_radius=0
    cone.bottom_radius=1.35-i*0.28
    cone.height=2.4-i*0.25
    cone.radial_segments=7
    _append(builder,cone,Transform3D(Basis.IDENTITY,Vector3(0,2.1+i*0.85,0)),Color("294b38").lightened(i*0.055))
  else:
   for i in range(4):
    var angle := i*TAU/4.0
    _append(builder,_ball(1.25,2.1),Transform3D(Basis.IDENTITY,Vector3(cos(angle)*0.65,2.8+0.3*(i%2),sin(angle)*0.65)),Color("52693b").lightened(i*0.035))
 elif kind=="fern":
  for i in range(7):
   var angle:=i*TAU/7.0
   var direction:=Vector3(cos(angle),0,sin(angle))
   var across:=Vector3(-sin(angle),0,cos(angle))
   for leaf in range(4):
    var t:=float(leaf+1)/5.0
    var center:=direction*t*0.7+Vector3.UP*sin(t*PI)*0.5
    for sign in [-1.0,1.0]:
     for p in [center-direction*0.12,center+across*sign*(1.0-t)*0.32+direction*0.13,center+direction*0.14]:
      builder.set_color(Color("456337").lightened(t*0.12).srgb_to_linear())
      builder.set_normal(Vector3.UP)
      builder.add_vertex(p)
 else:
  var gorse := kind=="gorse"
  for i in range(6):
   var angle:=i*TAU/6.0
   var point:=Vector3(cos(angle)*0.32,0.25+0.08*(i%3),sin(angle)*0.32)
   _append(builder,_ball(0.34,0.6),Transform3D(Basis.IDENTITY,point),Color("4f6031") if gorse else Color("596047"))
   _append(builder,_ball(0.15,0.24),Transform3D(Basis.IDENTITY,point+Vector3.UP*0.25),Color("cfad3a") if gorse else Color("96758f"))
 return builder.commit()

func _instances(mesh: Mesh, placements: Array[Transform3D], label: String) -> void:
 var multi:=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.mesh=mesh
 multi.instance_count=placements.size()
 for i in range(placements.size()): multi.set_instance_transform(i,placements[i])
 var node:=MultiMeshInstance3D.new()
 node.name=label
 node.multimesh=multi
 node.material_override=plants_material
 node.extra_cull_margin=1.0
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)

func _forest() -> void:
 for kind in ["ash","birch"]:
  var placements: Array[Transform3D]=[]
  for i in range(300 if kind=="ash" else 220):
   var angle:=rng.randf()*TAU
   # Angular modulation gathers the trees into irregular woodland clusters.
   var radius:=rng.randf_range(29,64)
   if sin(angle*11.0)+cos(radius*0.3)<-0.6: continue
   var height:=_ridge_height(radius,angle,false)-0.18
   var size:=rng.randf_range(0.65,1.35)
   placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(cos(angle)*radius,height,sin(angle)*radius)))
  preload("res://imported_trees.gd").plant(self,placements,kind)
  if kind=="ash": pine_count=placements.size()
  else: deciduous_count=placements.size()

func _wild_edge() -> void:
 var half: Vector2=Vector2(garden.chunk_count)*garden.CHUNK_SIZE*0.5
 for kind in ["fern","heather","gorse"]:
  var placements: Array[Transform3D]=[]
  for i in range(520):
   var point:=Vector2(rng.randf_range(-32,32),rng.randf_range(-32,32))
   var outside: float=maxf(absf(point.x)-half.x,absf(point.y)-half.y)
   if outside<1.2 or point.length()>33: continue
   if rng.randf()>lerpf(0.12,0.85,smoothstep(1.2,14.0,outside)): continue
   var height: float = _ridge_height(point.length(),atan2(point.y,point.x),false) if point.length()>24 else garden.background_meadow.height_at(point)
   var size:=rng.randf_range(0.6,1.25)
   placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(point.x,maxf(0,height-0.1),point.y)))
  wild_count+=placements.size()
  _instances(_prototype(kind),placements,kind.capitalize()+"Edge")

func _wisp(position: Vector3, size: Vector2, material: ShaderMaterial) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new()
 var quad:=QuadMesh.new()
 quad.size=size
 mesh.mesh=quad
 mesh.position=position
 mesh.material_override=material
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(mesh)
 return mesh

func _process(_delta: float) -> void:
 if is_instance_valid(garden): update_atmosphere()

func update_atmosphere() -> void:
 var cycle=garden.valley_cycle
 var light: float=cycle.sky_material.get_shader_parameter("daylight")
 var rain: float=cycle.rain_strength
 var haze:=Color("28384f").lerp(Color("9cabb6"),light)
 for mat in [terrain_material,plants_material]:
  mat.set_shader_parameter("haze_color",haze)
  mat.set_shader_parameter("daylight",light)
  mat.set_shader_parameter("rain_strength",rain)
  mat.set_shader_parameter("scenery_time",cycle.elapsed)
 mist_material.set_shader_parameter("tint",haze)
 mist_material.set_shader_parameter("opacity",0.16+rain*0.25)
 mist_material.set_shader_parameter("drift_time",cycle.elapsed)
 cloud_material.set_shader_parameter("tint",Color("343c58").lerp(Color("deddd4"),light))
 cloud_material.set_shader_parameter("opacity",0.45+cycle.cloud_cover*0.28)
 cloud_material.set_shader_parameter("drift_time",cycle.elapsed)
 for wisp in wisps:
  wisp.rotation.y=atan2(garden.camera.global_position.x-wisp.global_position.x,garden.camera.global_position.z-wisp.global_position.z)
 for cloud in clouds:
  var origin: Vector3=cloud.get_meta("origin")
  cloud.position=origin+Vector3(sin(cycle.elapsed*0.002+origin.z)*9.0,0,cos(cycle.elapsed*0.0015+origin.x)*5.0)
  cloud.rotation.y=atan2(garden.camera.global_position.x-cloud.global_position.x,garden.camera.global_position.z-cloud.global_position.z)

