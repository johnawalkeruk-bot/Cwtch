extends Node3D
signal effect_applied(cell: Vector2i, tool: int, mode: int)
const KEYS := ["hoe","seeds","water","shovel"]
const MODES := ["Dig","Pick","Pour","Thump"]
const SOUNDS := ["Hoe","Grass Seeds","Watering Can"]
const SHOVEL_SOUNDS := ["Shovel_Dig","Shovel_Pick","Shovel_Fill","Shovel_Thump"]
var garden: Node3D
var pivot: Node3D
var models: Array[Node3D]=[]
var particles: CPUParticles3D
var audio: AudioStreamPlayer3D
var selected := 0
var shovel_mode := 0
var stroke_mode := 0
var stroke_duration := 1.0
var busy := false
var elapsed := 0.0
var idle_time := 0.0
var applied := false
var tracks_spirit := true
var target_cell := Vector2i.ZERO
var target_point := Vector3.ZERO
var outlet := Vector3.ZERO

static func bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
 transform *= node.transform
 var result := AABB()
 if node is MeshInstance3D and node.mesh: result = transform*node.mesh.get_aabb()
 for child in node.get_children():
  if child is Node3D:
   var child_bounds := bounds(child,transform)
   if child_bounds.size.length()>0: result = child_bounds if result.size.length()==0 else result.merge(child_bounds)
 return result

static func make_model(index: int) -> Node3D:
 var wrapper:=Node3D.new()
 var path: String="res://assets/tools/shovel/Shovel.fbx" if index==3 else "res://assets/tools/%s.glb"%KEYS[index]
 var model: Node3D=load(path).instantiate()
 var box:=bounds(model)
 var size: float=[0.82,0.43,0.58,0.95][index]
 var factor:=size/maxf(box.size.x,maxf(box.size.y,box.size.z))
 model.scale*=factor
 model.position-=box.get_center()*factor
 wrapper.add_child(model)
 for animation in model.find_children("*","AnimationPlayer",true,false):animation.stop();animation.active=false
 if index==2:wrapper.rotation.y=PI/4.0
 return wrapper

func setup(world: Node3D) -> void:
 garden=world
 pivot=Node3D.new()
 add_child(pivot)
 for i in 4:
  var model:=make_model(i)
  pivot.add_child(model)
  models.append(model)
 particles=CPUParticles3D.new()
 particles.top_level=true
 particles.local_coords=false
 particles.amount=55
 particles.lifetime=0.55
 particles.gravity=Vector3(0,-3,0)
 particles.scale_amount_min=0.6
 particles.scale_amount_max=1.0
 var drop:=SphereMesh.new()
 drop.radius=0.016
 drop.height=0.032
 drop.radial_segments=6
 drop.rings=3
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo=true
 drop.material=material
 particles.mesh=drop
 particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 particles.emitting=false
 add_child(particles)
 audio=AudioStreamPlayer3D.new()
 audio.volume_db=-10.0
 audio.unit_size=3.0
 audio.max_distance=20.0
 add_child(audio)
 equip(0)

func cancel_use() -> void:
 busy=false
 applied=false
 particles.emitting=false
 audio.stop()
 pivot.rotation=Vector3.ZERO
 pivot.position=Vector3.ZERO

func equip(index: int) -> void:
 cancel_use()
 selected=clampi(index,0,4)
 for i in models.size():models[i].visible=i==selected

func use_at(cell: Vector2i) -> bool:
 if busy or selected==4:return false
 target_cell=cell
 tracks_spirit=cell==garden.player.cell
 target_point=garden.player.position if tracks_spirit else garden.cell_center(cell)
 stroke_mode=shovel_mode
 var sound: String=SHOVEL_SOUNDS[stroke_mode] if selected==3 else SOUNDS[selected]
 audio.stream=load("res://assets/sounds/tools/"+sound+".mp3")
 stroke_duration=audio.stream.get_length()
 audio.play()
 particles.color=Color("97724c") if selected==3 else (Color("84e45a") if selected==1 else Color("58bbed"))
 var digging: bool=selected==3 and stroke_mode in [0,1]
 particles.direction=Vector3.UP if digging else Vector3.DOWN
 particles.spread=38.0 if digging else 13.0
 particles.initial_velocity_min=0.8 if digging else 0.3
 particles.initial_velocity_max=1.8 if digging else 0.7
 busy=true
 elapsed=0.0
 applied=false
 return true

func _process(delta: float) -> void:
 if not is_instance_valid(garden):return
 var paused: bool=garden.guide.visible or garden.tool_wheel.visible or (is_instance_valid(garden.dev_console) and garden.dev_console.opened)
 particles.speed_scale=0.0 if paused else 1.0
 audio.stream_paused=paused
 visible=not paused
 if paused:return
 idle_time+=delta
 if busy and tracks_spirit:
  target_cell=garden.player.cell
  target_point=garden.player.position
 var anchor: Vector3=target_point+Vector3.UP*0.1 if busy else garden.cursor.position
 position=anchor+Vector3.UP*(0.55+sin(idle_time*2)*0.022)
 rotation.y=garden.camera_yaw
 pivot.position=Vector3.ZERO
 pivot.rotation=Vector3.ZERO
 if not busy:return
 elapsed+=delta
 var t:=clampf(elapsed/stroke_duration,0,1)
 var tilt:=smoothstep(0,0.25,t)*(1.0-smoothstep(0.78,1.0,t))
 var impact:=0.44
 var emitting:=false
 if selected==0:
  pivot.position.y=-0.36*pow(sin(t*PI),4)
  pivot.rotation.z=-0.18+sin(t*TAU)*0.14
 elif selected==1:
  pivot.rotation.z=PI*tilt
  pivot.position.y=absf(sin(t*TAU*3))*0.055*tilt
  outlet=Vector3(0,0.20,0)
  emitting=t>0.28 and t<0.8
 elif selected==2:
  pivot.rotation.z=-1.9*tilt
  outlet=Basis(Vector3.UP,PI/4.0)*Vector3(0.2553,0.0726,0.2359)
  emitting=t>0.28 and t<0.8
 else:
  outlet=Vector3(0,-0.40,0)
  match stroke_mode:
   0:
    pivot.position.y=-0.32*pow(sin(t*PI),2)+0.1*sin(t*TAU)
    pivot.rotation.x=lerpf(-0.4,0.65,smoothstep(0.3,0.7,t))*tilt
    emitting=t>0.44 and t<0.73
   1:
    pivot.position.y=-0.18*pow(sin(t*PI),8)
    pivot.rotation.z=0.12*sin(t*TAU)*tilt
    emitting=t>0.44 and t<0.56
   2:
    pivot.rotation.z=2.4*tilt
    pivot.position.y=0.10*tilt
    emitting=t>0.3 and t<0.75
   3:
    pivot.rotation.x=-PI/2.0*tilt
    pivot.position.y=-0.42*pow(sin(t*PI),6)
 particles.global_position=pivot.to_global(outlet)
 particles.emitting=emitting
 if not applied and t>=impact:
  applied=true
  effect_applied.emit(target_cell,selected,stroke_mode)
 if t>=1.0:
  busy=false
  particles.emitting=false
  pivot.rotation=Vector3.ZERO
