extends "res://hedgehog_npc.gd"
var visit_state := "outside"
var patrol_corner := 1
var entry_cell := Vector2i.ZERO

func setup(world: Node3D) -> void:
 super.setup(world)
 set_meta("animal_id","hedgehog")
 remove_from_group("garden_npcs")
 position=Vector3(-garden.grid_min.x+1.25,0,0)
 position.y=garden.background_meadow.height_at(Vector2(position.x,position.z))

func _entry() -> bool:
 var nearest:=INF
 var found:=false
 for y in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   if x!=0 and y!=0 and x!=garden.grid_size.x-1 and y!=garden.grid_size.y-1:continue
   var candidate:=Vector2i(x,y)
   if not _can_reserve(candidate):continue
   var distance: float=position.distance_squared_to(garden.cell_center(candidate))
   if distance<nearest:
    nearest=distance
    entry_cell=candidate
    found=true
 return found

func advance(delta: float) -> void:
 if garden.guide.visible or garden.tool_wheel.visible:return
 if visit_state=="inside":
  super.advance(delta)
  return
 if visit_state=="outside" and garden.wildlife.grass_ratio()>=0.01 and _entry():visit_state="entering"
 var half: Vector2=-garden.grid_min+Vector2.ONE*1.25
 var corners: Array[Vector3]=[Vector3(half.x,0,-half.y),Vector3(half.x,0,half.y),Vector3(-half.x,0,half.y),Vector3(-half.x,0,-half.y)]
 var target: Vector3=corners[patrol_corner] if visit_state=="outside" else garden.cell_center(entry_cell)
 if visit_state=="entering" and not garden.wildlife.records.has("hedgehog") and garden.wildlife.grass_ratio()<0.01:
  visit_state="outside"
  return
 var offset:=Vector3(target.x-position.x,0,target.z-position.z)
 walking=offset.length()>0.02
 if walking:
  visual.rotation.y=lerp_angle(visual.rotation.y,atan2(offset.x,offset.z),1.0-exp(-3.0*delta))
  var hit:=move_and_collide(offset.normalized()*minf(offset.length(),delta*0.32))
  if hit and visit_state=="entering":_entry()
 var inside: bool=garden.contains_cell(garden.local_to_cell(position))
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z)) if inside else garden.background_meadow.height_at(Vector2(position.x,position.z))
 gait+=delta
 body.rotation.z=sin(gait*10.0)*0.045
 body.position.y=absf(sin(gait*8.0))*0.006
 if inside and visit_state=="entering":garden.wildlife.record_visit("hedgehog")
 if offset.length()<0.04:
  if visit_state=="outside":patrol_corner=(patrol_corner+1)%4
  else:
   cell=entry_cell
   next_cell=cell
   destination=garden.cell_center(cell)
   add_to_group("garden_npcs")
   visit_state="inside"
