extends Node3D
## Permanent approach geometry and a one-shot new-garden arrival.
const WALK_SECONDS := 38.0
const RETURN_SECONDS := 2.0
var garden: Node3D
var active := false
var elapsed := 0.0
var camera: Camera3D
var triangle_bands: Dictionary = {}
var layers: Array = []
var suspended: Array = []
var hidden: Array = []
var return_transform := Transform3D.IDENTITY
var crossing: Node3D
var bird: Node3D
var wings: Array[Node3D] = []
var animals: Array[Node3D] = []
var tree_focus := Vector3.ZERO
var finish_from := Transform3D.IDENTITY

static func center_x(z: float) -> float:
 return sin((z+12.0)*0.075)*3.0*smoothstep(0.0,12.0,-z-12.0)

static func in_path(point: Vector3, margin: float=3.0) -> bool:
 return point.z < -12.0 and point.z > -132.0 and absf(point.x-center_x(point.z)) < margin

func setup(world: Node3D) -> void:
 garden=world
 name="NorthernArrival"
 process_priority=200
 # Sample the rendered triangles rather than an approximate hill formula.
 for group in [garden.background_meadow,garden.valley_landscape]:
  for mesh in group.get_children():
   if not mesh is MeshInstance3D or mesh.mesh==null:continue
   if group==garden.valley_landscape and mesh.name not in ["WoodedRidges","SnowdoniaPeaks"]:continue
   var faces: PackedVector3Array=mesh.mesh.get_faces()
   for i in range(0,faces.size(),3):
    var a: Vector3=mesh.transform*faces[i]
    var b: Vector3=mesh.transform*faces[i+1]
    var c: Vector3=mesh.transform*faces[i+2]
    if minf(a.z,minf(b.z,c.z)) > -10 or maxf(a.z,maxf(b.z,c.z)) < -133:continue
    if minf(a.x,minf(b.x,c.x)) > 20 or maxf(a.x,maxf(b.x,c.x)) < -20:continue
    for band in range(floori(minf(a.z,minf(b.z,c.z))/4.0),floori(maxf(a.z,maxf(b.z,c.z))/4.0)+1):
     if not triangle_bands.has(band):triangle_bands[band]=[]
     triangle_bands[band].append([a,b,c])
 _build_road()
 _build_vignettes()
 camera=Camera3D.new()
 camera.name="ArrivalCamera"
 camera.near=0.04
 camera.far=300
 camera.fov=68
 add_child(camera)
 set_process(false)
 set_process_input(false)

func ground(x: float,z: float) -> float:
 var result := -1000.0
 for tri in triangle_bands.get(floori(z/4.0),[]):
  var a: Vector3=tri[0]
  var b: Vector3=tri[1]
  var c: Vector3=tri[2]
  if x < minf(a.x,minf(b.x,c.x)) or x > maxf(a.x,maxf(b.x,c.x)) or z < minf(a.z,minf(b.z,c.z)) or z > maxf(a.z,maxf(b.z,c.z)):continue
  var den: float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
  if absf(den)<0.000001:continue
  var u: float=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/den
  var v: float=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/den
  if u>=-0.001 and v>=-0.001 and u+v<=1.001:result=maxf(result,u*a.y+v*b.y+(1-u-v)*c.y)
 return maxf(0.0,result)

func point(z: float,offset: float=0.0) -> Vector3:
 var x:=center_x(z)+offset
 return Vector3(x,ground(x,z),z)

func _build_road() -> void:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(300):
  var z0:=lerpf(-132.0,-12.0,float(row)/300)
  var z1:=lerpf(-132.0,-12.0,float(row+1)/300)
  for col in range(6):
   var x0:=lerpf(-1.3,1.3,float(col)/6)
   var x1:=lerpf(-1.3,1.3,float(col+1)/6)
   var corners: Array[Vector3]=[point(z0,x0),point(z0,x1),point(z1,x0),point(z1,x1)]
   for index in [0,2,1,1,2,3]:
    var p:=corners[index]+Vector3.UP*0.055
    st.set_uv(Vector2(p.x,p.z)*0.8)
    st.add_vertex(p)
 st.generate_normals()
 var mesh:=MeshInstance3D.new()
 mesh.name="NorthernGravelPath"
 mesh.mesh=st.commit()
 var mat:=StandardMaterial3D.new()
 mat.albedo_texture=load("res://assets/textures/gravel/Gravel040_1K-JPG_Color.jpg")
 mat.normal_enabled=true
 mat.normal_texture=load("res://assets/textures/gravel/Gravel040_1K-JPG_NormalGL.jpg")
 mat.roughness_texture=load("res://assets/textures/gravel/Gravel040_1K-JPG_Roughness.jpg")
 mat.roughness=0.95
 mat.albedo_color=Color("aaa69a")
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.material_override=mat
 add_child(mesh)

func _ball(parent: Node3D,at: Vector3,scale: Vector3,color: Color) -> MeshInstance3D:
 var part:=MeshInstance3D.new()
 var shape:=SphereMesh.new()
 shape.radius=0.5
 shape.height=1.0
 shape.radial_segments=10
 shape.rings=5
 part.mesh=shape
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=color
 mat.roughness=0.95
 part.material_override=mat
 part.position=at
 part.scale=scale
 parent.add_child(part)
 return part

func _animal(label: String,at: Vector3,color: Color) -> Node3D:
 var animal:=Node3D.new()
 animal.name=label
 add_child(animal)
 animal.position=at
 _ball(animal,Vector3(0,0.45,0),Vector3(1.0,0.65,0.5),color)
 _ball(animal,Vector3(0.5,0.65,0),Vector3(0.4,0.42,0.35),color)
 for x in [-0.3,0.3]:
  for z in [-0.17,0.17]:_ball(animal,Vector3(x,0.18,z),Vector3(0.13,0.42,0.13),Color("574b3c"))
 for z in [-0.12,0.12]:_ball(animal,Vector3(0.49,0.91,z),Vector3(0.12,0.28,0.10),color)
 return animal

func _build_vignettes() -> void:
 crossing=_animal("CrossingCreaturePlaceholder",point(-40,-4),Color("9a7953"))
 bird=Node3D.new()
 bird.name="FlyingBirdPlaceholder"
 add_child(bird)
 _ball(bird,Vector3.ZERO,Vector3(0.35,0.22,0.65),Color("594f42"))
 for side in [-1,1]:
  var wing:=Node3D.new()
  bird.add_child(wing)
  wing.position.x=side*0.1
  _ball(wing,Vector3(side*0.36,0,0),Vector3(0.85,0.045,0.28),Color("786958"))
  wings.append(wing)
 bird.position=point(-28,-8)+Vector3.UP*5
 var tree:=Node3D.new()
 tree.name="ArrivalLookTree"
 add_child(tree)
 tree.position=point(-24,5)
 var placements: Array[Transform3D]=[Transform3D.IDENTITY]
 preload("res://imported_trees.gd").plant(tree,placements,"birch")
 tree_focus=tree.position+Vector3.UP*2.4
 for i in 2:
  var animal:=_animal("DistantAnimalPlaceholder%d"%i,point(-15,-9-i*2),Color("c3b69a"))
  animal.scale=Vector3.ONE*1.3
  animals.append(animal)

func start() -> void:
 if active:return
 garden._set_guide(false)
 garden._clear_use()
 garden.local_coop.second.clear_use()
 garden.player.restore_position(Vector3(0,0,-10.4))
 garden.local_coop.second.player.restore_position(Vector3(0.9,0,-10.4))
 garden.local_coop.second.camera_yaw=PI
 garden.local_coop.second.camera_pitch=PI/4.0
 garden.camera_yaw=PI
 garden.camera_pitch=PI/4.0
 preload("res://diorama_camera.gd").follow(garden.camera,garden.player.position,garden.camera_yaw,garden.camera_pitch)
 return_transform=garden.camera.global_transform
 garden.local_coop.suspend_render()
 suspended.clear()
 for node in [garden,garden.local_coop,garden.local_coop.second,garden.hedgehog_intro,garden.dev_console]:
  suspended.append({"node":node,"process":node.is_processing(),"physics":node.is_physics_processing(),"input":node.is_processing_input(),"unhandled":node.is_processing_unhandled_input()})
  node.set_process(false)
  node.set_physics_process(false)
  node.set_process_input(false)
  node.set_process_unhandled_input(false)
 layers.clear()
 for layer in garden.find_children("*","CanvasLayer",true,false):
  layers.append({"node":layer,"visible":layer.visible})
  layer.hide()
 hidden.clear()
 for node in [garden.cursor,garden.floating_tool,garden.local_coop.second]:
  hidden.append({"node":node,"visible":node.visible})
  node.hide()
 active=true
 elapsed=0.0
 camera.environment=garden.camera.environment
 camera.position=point(-46)+Vector3.UP*1.55
 camera.look_at(point(-42)+Vector3.UP*1.3)
 camera.make_current()
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 set_process(true)
 set_process_input(true)

func _process(delta: float) -> void:
 if not active:return
 elapsed+=delta
 var t:=clampf(elapsed/WALK_SECONDS,0.0,1.0)
 var z:=lerpf(-46.0,-12.0,t)
 var crossing_x:=lerpf(-4.0,4.0,smoothstep(3.0,11.0,elapsed))
 crossing.position=point(-40,crossing_x)
 crossing.position.y+=absf(sin(elapsed*6))*0.025
 for i in range(2,6):
  crossing.get_child(i).rotation.z=sin(elapsed*6+float(i%2)*PI)*0.3 if elapsed>3 and elapsed<11 else 0.0
 bird.position=point(-28,lerpf(-9.0,10.0,smoothstep(10,18,elapsed)))+Vector3.UP*4.5
 for i in 2:wings[i].rotation.z=sin(elapsed*9)*(0.55 if i==0 else -0.55)
 for i in animals.size():animals[i].rotation.z=sin(elapsed*1.3+i)*0.035
 if elapsed<=WALK_SECONDS:
  var at:=point(z)+Vector3.UP*1.55
  var bounce:=sin(elapsed*TAU*1.65)*0.027
  at.y+=bounce*smoothstep(0,2,elapsed)*(1-smoothstep(35,38,elapsed))
  camera.position=at
  var focus:=point(z+5)+Vector3.UP*1.3
  var targets: Array[Vector3]=[crossing.position+Vector3.UP*0.6,bird.position,tree_focus,animals[0].position+Vector3.UP*0.65]
  var beats: Array[Vector2]=[Vector2(3,10),Vector2(11,17),Vector2(20,26),Vector2(29,35)]
  for i in beats.size():
   var strength:=smoothstep(beats[i].x,beats[i].x+1.8,elapsed)*(1-smoothstep(beats[i].y-1.8,beats[i].y,elapsed))
   focus=focus.lerp(targets[i],strength*0.92)
  var target:=Basis.looking_at(focus-at,Vector3.UP)
  camera.basis=camera.basis.slerp(target,1-exp(-3.2*delta)).orthonormalized()
  finish_from=camera.global_transform
 else:
  camera.global_transform=finish_from.interpolate_with(return_transform,smoothstep(0,RETURN_SECONDS,elapsed-WALK_SECONDS))
  if elapsed>=WALK_SECONDS+RETURN_SECONDS:finish()

func _input(event: InputEvent) -> void:
 if not active:return
 if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]):finish()
 get_viewport().set_input_as_handled()

func finish() -> void:
 if not active:return
 active=false
 set_process(false)
 set_process_input(false)
 for entry in suspended:
  if not is_instance_valid(entry.node):continue
  entry.node.set_process(entry.process)
  entry.node.set_physics_process(entry.physics)
  entry.node.set_process_input(entry.input)
  entry.node.set_process_unhandled_input(entry.unhandled)
 for entry in layers:
  if is_instance_valid(entry.node):entry.node.visible=entry.visible
 for entry in hidden:
  if is_instance_valid(entry.node):entry.node.visible=entry.visible
 garden.camera.global_transform=return_transform
 garden.camera.make_current()
 garden._clear_use()
 garden.hedgehog_intro.request_welcome()
 var host:=garden.get_parent()
 if host.has_method("_save_garden"):host.call_deferred("_save_garden")
