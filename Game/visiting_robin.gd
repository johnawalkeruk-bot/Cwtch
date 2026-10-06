extends "res://wandering_npc.gd"
## A wild robin waits outside until the garden has at least 1% water.
var visit_state:="outside"
var patrol_corner:=0
var entry_cell:=Vector2i.ZERO
var entry_retry:=0.0
var gait:=0.0
var rest_time:=0.0
var body: Node3D
var flight_time:=0.0
var flight_wait:=12.0
const FLIGHT_SECONDS:=4.0

func _create_visual() -> void:
 collision_radius=0.10
 collision_height=0.22
 move_speed=0.42
 visual=Node3D.new()
 add_child(visual)
 body=load("res://assets/animals/Robin/robin_animated.glb").instantiate()
 visual.add_child(body)
 animation_player=body.find_child("AnimationPlayer",true,false) as AnimationPlayer
 assert(animation_player!=null,"The Blender robin export must contain its animation player")
 for clip in ["Idle","Hopping","Flying"]:
  assert(animation_player.has_animation(clip),"Missing robin animation: "+clip)
  animation_player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
 animation_player.play("Idle")
 flight_wait=12.0
 set_meta("animal_id","robin")
 set_meta("inspection_text","A robin is exploring the water's edge.")

func setup(world: Node3D) -> void:
 super.setup(world)
 remove_from_group("garden_npcs")
 position=Vector3(0,0,garden.grid_min.y-1.25)
 position.y=garden.background_meadow.height_at(Vector2(position.x,position.z))

func _entry() -> bool:
 var nearest:=INF
 var found:=false
 for z in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   if x!=0 and z!=0 and x!=garden.grid_size.x-1 and z!=garden.grid_size.y-1:continue
   var candidate:=Vector2i(x,z)
   if not _can_reserve(candidate):continue
   var distance: float=position.distance_squared_to(garden.cell_center(candidate))
   if distance<nearest:
    nearest=distance
    entry_cell=candidate
    found=true
 return found

func advance(delta: float) -> void:
 if garden.guide.visible or garden.tool_wheel.visible:
  animation_player.speed_scale=0.0
  return
 gait+=delta
 if rest_time>0.0:
  rest_time=maxf(0.0,rest_time-delta)
  motion_ratio=0.0
 elif visit_state=="inside":
  super.advance(delta)
 else:
  _advance_outside(delta)
 _animate_robin(delta)

func _animate_robin(delta: float) -> void:
 flight_wait=maxf(0.0,flight_wait-delta)
 if flight_time<=0.0 and flight_wait<=0.0 and motion_ratio>0.3 and rest_time<=0.0 and garden.valley_cycle.rain_strength<0.5 and (visit_state!="inside" or brain.state not in ["rest","shelter"]):
  flight_time=FLIGHT_SECONDS
  flight_wait=18.0
 if flight_time>0.0:
  flight_time=maxf(0.0,flight_time-delta)
  # Short low flights follow the existing safe patrol route. No visit is awarded
  # until the same 1% water requirement and garden entry checks have passed.
  var up:=smoothstep(0.0,0.7,FLIGHT_SECONDS-flight_time)
  var down:=smoothstep(0.0,0.7,flight_time)
  body.get_parent().position.y=0.55*up*down
 else:body.get_parent().position.y=0.0
 var clip: String="Flying" if flight_time>0.0 else ("Hopping" if motion_ratio>0.05 and rest_time<=0.0 else "Idle")
 if animation_player.current_animation!=clip:animation_player.play(clip,0.18)
 animation_player.speed_scale=1.0 if clip!="Hopping" else clampf(motion_ratio,0.65,1.0)

func _advance_outside(delta: float) -> void:
 entry_retry=maxf(0.0,entry_retry-delta)
 if visit_state=="outside" and garden.wildlife.water_ratio()>=0.01 and entry_retry<=0.0:
  entry_retry=1.0
  if _entry():visit_state="entering"
 if visit_state=="entering" and not garden.wildlife.records.has("robin") and garden.wildlife.water_ratio()<0.01:
  _resume_patrol()
 if visit_state=="entering" and not _can_reserve(entry_cell):
  if not _entry():_resume_patrol()
 var half: Vector2=-garden.grid_min+Vector2.ONE*1.25
 var corners: Array[Vector3]=[Vector3(half.x,0,-half.y),Vector3(half.x,0,half.y),Vector3(-half.x,0,half.y),Vector3(-half.x,0,-half.y)]
 var target: Vector3=corners[patrol_corner] if visit_state=="outside" else garden.cell_center(entry_cell)
 var offset:=Vector3(target.x-position.x,0,target.z-position.z)
 var before:=position
 if offset.length()>0.01:
  visual.rotation.y=lerp_angle(visual.rotation.y,atan2(offset.x,offset.z),1.0-exp(-4.0*delta))
  var hit:=move_and_collide(offset.normalized()*minf(offset.length(),delta*move_speed))
  if hit and visit_state=="entering":_entry()
 motion_ratio=clampf(position.distance_to(before)/maxf(delta*move_speed,0.0001),0,1)
 var inside: bool=garden.contains_cell(garden.local_to_cell(position))
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z)) if inside else garden.background_meadow.height_at(Vector2(position.x,position.z))
 if inside and visit_state=="entering":garden.wildlife.record_visit("robin")
 if Vector2(target.x-position.x,target.z-position.z).length()<0.025:
  if visit_state=="outside":patrol_corner=(patrol_corner+1)%4
  else:
   cell=entry_cell
   next_cell=cell
   destination=garden.cell_center(cell)
   add_to_group("garden_npcs")
   visit_state="inside"

func _resume_patrol() -> void:
 visit_state="outside"
 # Return along the current outside edge, never cut diagonally across the plot.
 if position.z<garden.grid_min.y:patrol_corner=0
 elif position.x>-garden.grid_min.x:patrol_corner=1
 elif position.z>-garden.grid_min.y:patrol_corner=2
 else:patrol_corner=3

func restore_visit(data: Dictionary) -> void:
 patrol_corner=clampi(int(data.get("robin_patrol_corner",0)),0,3)
 if not garden.wildlife.records.has("robin"):return
 var saved=data.get("robin_position",[])
 var candidate:=Vector2i(garden.grid_size.x/2,0)
 if saved is Array and saved.size()==2 and is_finite(float(saved[0])) and is_finite(float(saved[1])):
  candidate=garden.local_to_cell(Vector3(float(saved[0]),0,float(saved[1])))
 if not _can_reserve(candidate):
  var found:=false
  for z in range(garden.grid_size.y):
   for x in range(garden.grid_size.x):
    if _can_reserve(Vector2i(x,z)):
     candidate=Vector2i(x,z)
     found=true
     break
   if found:break
  if not found:return # No dry space: wait outside; retain the recorded visit.
 cell=candidate
 next_cell=cell
 position=garden.cell_center(cell)
 destination=position
 visit_state="inside"
 add_to_group("garden_npcs")
