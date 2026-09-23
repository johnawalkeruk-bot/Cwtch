extends Node
## First-visit and residency dates use the garden clock and survive save/load.
var garden: Node3D
var records: Dictionary={}
var hedgehog: Node3D
var wild_hedgehog_enabled := true
var grass_dirty := true
var cached_ratio := 0.0

func setup(world: Node3D) -> void:
 garden=world
 garden.terrain_changed.connect(func(_cell,_kind):grass_dirty=true)
 hedgehog=preload("res://visiting_hedgehog.gd").new()
 hedgehog.name="Hedgehog"
 garden.add_child(hedgehog)
 hedgehog.setup(garden)
 preload("res://selection_target.gd").attach(hedgehog,"Hedgehog",Vector3(0.35,0.30,0.4))

func grass_ratio() -> float:
 if not grass_dirty:return cached_ratio
 var total: int = garden.grid_size.x*garden.grid_size.y
 var grass:=0
 for y in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   if garden.get_terrain(Vector2i(x,y)) in [garden.Terrain.GRASS,garden.Terrain.LONG_GRASS]:grass+=1
 cached_ratio=float(grass)/float(total)
 grass_dirty=false
 return cached_ratio

func day() -> int:
 return floori(garden.valley_cycle.elapsed/garden.valley_cycle.FULL_CYCLE)+1

func record_visit(id: String) -> void:
 if records.has(id):return
 records[id]={"visit_day":day(),"resident_day":0}
 garden.message=id.capitalize()+" first visited on Day %d. The Field Guide has a new entry."%day()

func record_resident(id: String) -> void:
 record_visit(id)
 if int(records[id].resident_day)>0:return
 records[id].resident_day=day()
 garden.message=id.capitalize()+" became a resident on Day %d."%day()

func purchased(id: String) -> void:
 # Record arrival on delivery; hedgehogs still need their habitat threshold.
 if id=="hedgehog":
  record_visit(id)
  if grass_ratio()>=0.05:record_resident(id)
 else:record_resident(id)
 if id=="hedgehog":
  wild_hedgehog_enabled=false
  hedgehog.hide()
  hedgehog.process_mode=Node.PROCESS_MODE_DISABLED
  hedgehog.remove_from_group("garden_npcs")
  for shape in hedgehog.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",true)

func actor_for(id: String) -> Node3D:
 for node in garden.get_children():
  if node is Node3D and node.visible and str(node.get_meta("animal_id",""))==id:return node
 return null

func save_data() -> Dictionary:
 return {"wild_hedgehog_enabled":wild_hedgehog_enabled,"records":records.duplicate(true),"hedgehog_position":[hedgehog.position.x,hedgehog.position.z],"patrol_corner":hedgehog.patrol_corner}

func restore(data: Dictionary) -> void:
 records.clear()
 var saved=data.get("records",{})
 if saved is Dictionary:
  for id in ["hedgehog","chicken","badger","dragon","peacock"]:
   var entry=saved.get(id,{})
   if entry is Dictionary and int(entry.get("visit_day",0))>0:
    records[id]={"visit_day":maxi(1,int(entry.visit_day)),"resident_day":maxi(0,int(entry.get("resident_day",0)))}
 hedgehog.patrol_corner=clampi(int(data.get("patrol_corner",1)),0,3)
 wild_hedgehog_enabled=bool(data.get("wild_hedgehog_enabled",true))
 if not wild_hedgehog_enabled:
  hedgehog.hide()
  hedgehog.process_mode=Node.PROCESS_MODE_DISABLED
  return
 if records.has("hedgehog"):
  hedgehog.visit_state="inside"
  hedgehog.add_to_group("garden_npcs")
  var point=data.get("hedgehog_position",[])
  var cell:=Vector2i(0,garden.grid_size.y/2)
  if point is Array and point.size()==2:
   var candidate: Vector2i=garden.local_to_cell(Vector3(float(point[0]),0,float(point[1])))
   if hedgehog._can_reserve(candidate):cell=candidate
  if not hedgehog._can_reserve(cell):
   for y in range(garden.grid_size.y):
    for x in range(garden.grid_size.x):
     if hedgehog._can_reserve(Vector2i(x,y)):cell=Vector2i(x,y);break
  hedgehog.cell=cell
  hedgehog.next_cell=cell
  hedgehog.position=garden.cell_center(cell)
  hedgehog.destination=hedgehog.position

func _process(_delta: float) -> void:
 if not is_instance_valid(garden) or garden.guide.visible:return
 if records.has("hedgehog") and int(records.hedgehog.resident_day)==0 and grass_ratio()>=0.05:record_resident("hedgehog")

