extends RefCounted
## Shop stock and deterministic delivery shared by the village and save loader.
const STOCK := [
 {"id":"chicken","shop":0,"name":"Chicken","price":25,"note":"A busy new companion for your garden."},
 {"id":"hedgehog","shop":0,"name":"Hedgehog","price":40,"note":"A small visitor with a curious nose."},
 {"id":"birch","shop":1,"name":"Young birch","price":35,"note":"A pale-trunked tree for an open patch."},
 {"id":"ash","shop":1,"name":"Young ash","price":35,"note":"A leafy addition to the garden."},
 {"id":"planter","shop":2,"name":"Flower planter","price":15,"note":"A terracotta pot of valley flowers."},
 {"id":"bench","shop":2,"name":"Wooden bench","price":30,"note":"A quiet place to watch the valley."},
 {"id":"cottage","shop":3,"name":"Garden cottage","price":180,"note":"Commission a small cottage on clear ground."}
]
static func item(id: String) -> Dictionary:
 for entry in STOCK:
  if entry.id==id: return entry
 return {}

static func footprint(id: String) -> Vector2:
 if id=="cottage": return Vector2(4.2,4.2)
 if id=="bench": return Vector2(1.6,0.9)
 if id in ["birch","ash"]: return Vector2(1.2,1.2)
 return Vector2(0.7,0.7)

static func find_space(garden: Node3D, id: String) -> Vector2i:
 var half: Vector2=footprint(id)*0.5+Vector2.ONE*garden.MICRO_SIZE*0.5
 for z in range(2,garden.grid_size.y-2):
  for x in range(2,garden.grid_size.x-2):
   var cell:=Vector2i(x,z)
   var point: Vector3=garden.cell_center(cell)
   if absf(point.x)+half.x> -garden.grid_min.x or absf(point.z)+half.y> -garden.grid_min.y: continue
   var clear:=true
   for blocked in garden.blocked_cells:
    var at: Vector3=garden.cell_center(blocked)
    if absf(at.x-point.x)<half.x and absf(at.z-point.z)<half.y: clear=false; break
   if not clear: continue
   for crop in garden.crops:
    var at: Vector3=garden.cell_center(crop)
    if absf(at.x-point.x)<half.x and absf(at.z-point.z)<half.y: clear=false; break
   if not clear: continue
   if absf(garden.player.position.x-point.x)<half.x+0.6 and absf(garden.player.position.z-point.z)<half.y+0.6: continue
   for npc in garden.get_tree().get_nodes_in_group("garden_npcs"):
    var reserved: Vector3=garden.cell_center(npc.next_cell)
    if (absf(npc.position.x-point.x)<half.x+0.6 and absf(npc.position.z-point.z)<half.y+0.6) or (absf(reserved.x-point.x)<half.x+0.6 and absf(reserved.z-point.z)<half.y+0.6): clear=false; break
   if clear: return cell
 return Vector2i(-1,-1)

static func deliver(garden: Node3D, record: Dictionary) -> Node3D:
 var id: String=record.id
 var cell:=Vector2i(int(record.x),int(record.z))
 if id in ["chicken","hedgehog"]:
  var actor: Node3D=load("res://chicken_npc.gd" if id=="chicken" else "res://hedgehog_npc.gd").new()
  garden.add_child(actor)
  actor.setup(garden)
  actor.cell=cell
  actor.next_cell=cell
  actor.position=garden.cell_center(cell)
  actor.destination=actor.position
  preload("res://selection_target.gd").attach(actor,item(id).name,Vector3(0.5,0.5,0.5))
  garden.additional_visitors.append(actor)
  return actor
 var node:=model(id)
 garden.add_child(node)
 node.position=garden.cell_center(cell)
 var size:=footprint(id)
 preload("res://selection_target.gd").attach(node,item(id).name,Vector3(size.x,2.5 if id=="cottage" else 1.0,size.y))
 var body:=StaticBody3D.new()
 body.collision_layer=4
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(size.x,2.5 if id=="cottage" else 1.0,size.y)
 shape.shape=box
 shape.position.y=box.size.y*0.5
 node.add_child(body)
 body.add_child(shape)
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   var at: Vector3=garden.cell_center(Vector2i(x,z))
   if absf(at.x-node.position.x)<size.x*0.5+garden.MICRO_SIZE*0.5 and absf(at.z-node.position.z)<size.y*0.5+garden.MICRO_SIZE*0.5:
    garden.blocked_cells[Vector2i(x,z)]=true
 return node

static func part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.mesh=mesh
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 material.roughness=0.85
 node.material_override=material
 node.position=at
 parent.add_child(node)
 return node

static func box(parent: Node3D, size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
 var mesh:=BoxMesh.new()
 mesh.size=size
 return part(parent,mesh,color,at)

static func model(id: String) -> Node3D:
 var root:=Node3D.new()
 var path: String=""
 var width:=1.0
 if id=="cottage": path="res://assets/cottage.glb"; width=3.8
 elif id in ["ash","birch"]: path="res://assets/trees/%s_forest.glb"%id; width=2.2
 elif id=="chicken": path="res://assets/chicken_rig.glb"; width=0.5
 if path!="":
  var imported: Node3D=load(path).instantiate()
  var bounds: AABB=preload("res://floating_tool.gd").bounds(imported)
  var factor:=width/(bounds.size.y if id in ["ash","birch"] else maxf(bounds.size.x,bounds.size.z))
  imported.scale*=factor
  imported.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
  root.add_child(imported)
 elif id=="bench":
  box(root,Vector3(1.4,.12,.5),Color("795036"),Vector3(0,.48,0))
  box(root,Vector3(1.4,.42,.1),Color("926541"),Vector3(0,.8,-.22))
  for x in [-.52,.52]: box(root,Vector3(.12,.48,.4),Color("443123"),Vector3(x,.24,0))
 elif id=="planter":
  var pot:=CylinderMesh.new()
  pot.top_radius=.3; pot.bottom_radius=.2; pot.height=.4
  part(root,pot,Color("a66549"),Vector3(0,.2,0))
  for i in range(7):
   var at:=Vector3(sin(i*2.4)*.18,.57,cos(i*2.4)*.18)
   box(root,Vector3(.025,.35,.025),Color("52623b"),at-Vector3(0,.15,0))
   var flower:=SphereMesh.new()
   flower.radius=.09; flower.height=.1
   part(root,flower,Color("c994ba") if i%2==0 else Color("e7bf64"),at)
 return root
