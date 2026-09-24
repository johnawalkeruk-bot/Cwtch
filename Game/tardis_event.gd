extends Node3D
## A stationary materialisation just beyond the north boundary, doors facing south.
const ASSET := "res://assets/easter_egg/Tardis/"
const NORTH_OFFSET := 2.4
var garden: Node3D
var state := "away"
var visual: Node3D
var animation: AnimationPlayer
var material: ShaderMaterial
var audio: AudioStreamPlayer3D
var lamp: OmniLight3D
var body: StaticBody3D
var elapsed := 0.0
var duration := 1.0
var automatic := false
var stay := 0.0

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
   animation.active=false
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

func landing_point() -> Vector3:
 var point:=Vector3(0,0,garden.grid_min.y-NORTH_OFFSET)
 for x in [-0.7,0.0,0.7]:
  for z in [-0.7,0.0,0.7]:
   point.y=maxf(point.y,garden.background_meadow.height_at(Vector2(point.x+x,point.z+z)))
 return point

func land(auto_leave: bool=false) -> String:
 if state!="away":return "The TARDIS is already "+state+"."
 _load_model()
 position=landing_point()
 # The source's door and telephone notice face +Z (south) in its rest pose.
 rotation=Vector3.ZERO
 automatic=auto_leave
 state="landing"
 body.collision_layer=4
 show()
 _start_sound("Landing")
 material.set_shader_parameter("presence",0.0)
 garden.message="A strange blue box is arriving beyond the north edge."
 garden._refresh_ui()
 return "Landing just north of the garden, facing south."

func _start_sound(filename: String) -> void:
 elapsed=0.0
 audio.stream=load(ASSET+filename+".mp3")
 duration=audio.stream.get_length()
 audio.play()

func takeoff() -> String:
 if state!="landed":return "Takeoff requires a landed TARDIS (currently "+state+")."
 state="taking off"
 _start_sound("Takeoff")
 return "The TARDIS is taking off."

func _process(delta: float) -> void:
 if state=="away":return
 var paused: bool=garden.guide.visible
 audio.stream_paused=paused
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
  if arriving:
   state="landed"
   stay=20.0
   material.set_shader_parameter("presence",1.0)
  else:
   state="away"
   hide()
   body.collision_layer=0
   audio.stop()
