extends "res://wandering_npc.gd"
## A wild robin waits outside until the garden has at least 1% water.
var visit_state:="outside"
var patrol_corner:=0
var entry_cell:=Vector2i.ZERO
var entry_retry:=0.0
var gait:=0.0
var rest_time:=0.0
var body: Node3D

func _create_visual() -> void:
 collision_radius=0.10
 collision_height=0.22
 move_speed=0.42
 visual=Node3D.new()
 add_child(visual)
 body=load("res://assets/animals/Robin/robin.glb").instantiate()
 var bounds: AABB=preload("res://floating_tool.gd").bounds(body)
 var factor:=0.22/maxf(bounds.size.y,0.001)
 body.scale*=factor
 body.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
 visual.add_child(body)
 animation_player=AnimationPlayer.new()
 add_child(animation_player)
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

func _choose_destination() -> void:
 if rng.randf()<0.28:
  rest_time=rng.randf_range(0.5,1.5)
  walking=false
  travel_speed=0.0
  return
 super._choose_destination()
 # Prefer dry neighbours closer to the water, without stepping into ponds.
 if not walking or rng.randf()>0.75:return
 var waters: Array[Vector2i]=garden.wildlife.water_cells()
 if waters.is_empty():return
 var best:=INF
 for direction in DIRECTIONS:
  var candidate: Vector2i=cell+direction
  if not _can_reserve(candidate):continue
  var distance:=INF
  for water in waters:distance=minf(distance,Vector2(candidate).distance_squared_to(Vector2(water)))
  if distance<best:
   best=distance
   next_cell=candidate
 destination=garden.cell_center(next_cell)

func advance(delta: float) -> void:
 if garden.guide.visible or garden.tool_wheel.visible:return
 gait+=delta
 if rest_time>0.0:
  rest_time=maxf(0.0,rest_time-delta)
  motion_ratio=0.0
 elif visit_state=="inside":
  super.advance(delta)
 else:
  _advance_outside(delta)
 # The source is unrigged: move its parent pivot, retaining the textured mesh.
 var pivot: Node3D=body.get_parent()
 pivot.position.y=absf(sin(gait*9.0))*0.045*motion_ratio
 pivot.rotation.x=sin(gait*5.0)*0.035 if rest_time<=0.0 else maxf(0.0,sin(gait*7.0))*0.20

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
