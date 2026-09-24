extends Node3D
## A transient visitor: reserve a clear footprint, materialise, then dematerialise.
const ASSET := "res://assets/easter_egg/Tardis/"
const SPIN := "Tardis_lp|Tardis_lpAction"
var garden: Node3D
var state := "away"
var visual: Node3D
var animation: AnimationPlayer
var material: ShaderMaterial
var audio: AudioStreamPlayer3D
var lamp: OmniLight3D
var body: StaticBody3D
var reserved: Array[Vector2i]=[]
var elapsed := 0.0
var duration := 1.0
var automatic := false
var stay := 0.0
var last_cell := Vector2i(-1,-1)

func setup(world: Node3D) -> void:
 garden=world
 name="TardisEvent"
 audio=AudioStreamPlayer3D.new()
 audio.volume_db=-12.0
 audio.unit_size=12.0
 audio.max_distance=60.0
 add_child(audio)

func _load_model() -> void:
 if is_instance_valid(visual):return
 visual=load(ASSET+"source/For sketchfab.fbx").instantiate()
 add_child(visual)
 # The source is 3.114 m high, with its origin 5 cm below its feet.
 visual.scale=Vector3.ONE*(2.7/3.11391)
 visual.position.y=0.05*visual.scale.x
 material=ShaderMaterial.new()
 material.shader=preload("res://tardis_material.gdshader")
 var prefix: String=ASSET+"textures/Tardis_lp_RandomColor_1_"
 for pair in [["color_map","Diffuse"],["normal_map","Normal"],["glow_map","Emissive"],["gloss_map","Glossiness"]]:
  material.set_shader_parameter(pair[0],load(prefix+pair[1]+".png"))
 for child in visual.find_children("*","",true,false):
  if child is MeshInstance3D:child.material_override=material
  if child is AnimationPlayer:
   animation=child
   animation.stop()
 assert(animation!=null and animation.has_animation(SPIN))
 # This is the supplied upright rotation clip; the other long clip rolls sideways.
 var clip: Animation=animation.get_animation(SPIN).duplicate()
 clip.loop_mode=Animation.LOOP_NONE
 var library:=AnimationLibrary.new()
 library.add_animation("flight",clip)
 animation.add_animation_library("event",library)
 lamp=OmniLight3D.new()
 lamp.position.y=2.6
 lamp.light_color=Color("b7eaff")
 lamp.omni_range=5.0
 add_child(lamp)
 body=StaticBody3D.new()
 body.collision_layer=4
 body.collision_mask=0
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(1.4,2.7,1.4)
 shape.shape=box
 shape.position.y=1.35
 body.add_child(shape)
 add_child(body)
 body.collision_layer=0
 hide()

func _clear_at(cell: Vector2i) -> bool:
 var point: Vector3=garden.cell_center(cell)
 if point.distance_to(garden.player.position)<3.0:return false
 var low:=INF
 var high:=-INF
 for z in range(-2,3):
  for x in range(-2,3):
   var at:=cell+Vector2i(x,z)
   if not garden.contains_cell(at) or garden.blocked_cells.has(at) or garden.crops.has(at):return false
   if garden.get_terrain(at) in [garden.Terrain.WATER,garden.Terrain.DEEP_WATER]:return false
   var y: float=garden.cell_center(at).y
   low=minf(low,y)
   high=maxf(high,y)
 if high-low>0.35:return false
 for npc in get_tree().get_nodes_in_group("garden_npcs"):
  if npc.garden!=garden:continue
  var next: Vector3=garden.cell_center(npc.next_cell)
  if Vector2(npc.position.x-point.x,npc.position.z-point.z).length()<2.8:return false
  if Vector2(next.x-point.x,next.z-point.z).length()<2.8:return false
 return true

func land(auto_leave: bool=false) -> String:
 if state!="away":return "The TARDIS is already "+state+"."
 var candidates: Array[Vector2i]=[]
 for z in range(3,garden.grid_size.y-3):
  for x in range(3,garden.grid_size.x-3):candidates.append(Vector2i(x,z))
 candidates.shuffle()
 var chosen:=Vector2i(-1,-1)
 for cell in candidates:
  if cell!=last_cell and _clear_at(cell):
   chosen=cell
   break
 if chosen.x<0:return "No clear landing space. Make room away from people, crops and buildings."
 _load_model()
 last_cell=chosen
 position=garden.cell_center(chosen)
 rotation.y=float(randi_range(0,3))*PI/2.0
 for z in range(-2,3):
  for x in range(-2,3):
   var cell:=chosen+Vector2i(x,z)
   garden.blocked_cells[cell]=true
   reserved.append(cell)
 # Settle the box above the highest corner of its base on gently uneven soil.
 for x in [-0.7,0.7]:
  for z in [-0.7,0.7]:position.y=maxf(position.y,garden.heightfield.height_at(Vector2(position.x+x,position.z+z)))
 automatic=auto_leave
 state="landing"
 body.collision_layer=4
 show()
 _start_sound("Landing")
 animation.play("event/flight",0.0,animation.get_animation("event/flight").length/duration)
 animation.advance(0.0)
 material.set_shader_parameter("presence",0.0)
 garden.message="A strange blue box is arriving in the garden."
 garden._refresh_ui()
 return "Landing at garden position %.1f, %.1f."%[position.x,position.z]

func _start_sound(filename: String) -> void:
 elapsed=0.0
 audio.stream=load(ASSET+filename+".mp3")
 duration=audio.stream.get_length()
 audio.play()

func takeoff() -> String:
 if state!="landed":return "Takeoff requires a landed TARDIS (currently "+state+")."
 state="taking off"
 _start_sound("Takeoff")
 animation.play("event/flight",0.0,-animation.get_animation("event/flight").length/duration,true)
 animation.advance(0.0)
 return "The TARDIS is taking off."

func _process(delta: float) -> void:
 if state=="away":return
 var paused: bool=garden.guide.visible
 audio.stream_paused=paused
 animation.active=not paused
 if paused:return
 if state=="landed":
  lamp.light_energy=0.25
  material.set_shader_parameter("lamp_energy",0.35)
  if automatic:
   stay-=delta
   if stay<=0.0:takeoff()
  return
 elapsed=minf(elapsed+delta,duration)
 var progress:=elapsed/duration
 var arriving: bool=state=="landing"
 var amount:=progress if arriving else 1.0-progress
 var pulse:=0.5+0.5*sin(progress*TAU*7.0)
 var presence:=clampf(amount+sin(progress*PI)*0.23*(pulse-0.5),0.0,1.0)
 material.set_shader_parameter("presence",presence)
 material.set_shader_parameter("lamp_energy",0.5+pulse*2.0)
 lamp.light_energy=presence*(0.6+pulse*1.5)
 if elapsed>=duration:
  animation.pause()
  if arriving:
   state="landed"
   stay=20.0
   material.set_shader_parameter("presence",1.0)
  else:
   state="away"
   hide()
   body.collision_layer=0
   audio.stop()
   for cell in reserved:garden.blocked_cells.erase(cell)
   reserved.clear()
