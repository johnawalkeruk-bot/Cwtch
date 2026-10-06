extends RefCounted
## Local goal-driven AI: needs + species routines + reachable resources.
## No network calls, random directions, or changes to the player's planted crops.
var state:="observe"
var reason:="Taking in the garden"
var hunger:=0.65
var thirst:=0.2
var energy:=1.0
var activity_left:=0.0
var retry_left:=0.0
var visited: Dictionary={}
var age:=0.0
var goal:=Vector2i(-1,-1)
const HUMAN=["arthur","meera"]
func role(actor: Node) -> String:
 return str(actor.get_meta("animal_id",actor.name)).to_lower()
func priority(kind: String, hour: float, rain: float, water: bool) -> String:
 if rain>=0.5:return "shelter"
 var nocturnal: bool=kind in ["hedgehog","badger"]
 var sleeping: bool=(hour>=7 and hour<19) if nocturnal else (hour>=21 or hour<6)
 if sleeping or energy<0.2:return "rest"
 if kind=="arthur":return "welcome" if hour<9 else "inspect"
 if kind=="meera":return "plants"
 if thirst>=0.6 and water:return "drink"
 if kind=="robin":return "riverbank"
 if hunger>=0.5:return "forage"
 if kind=="dragon":return "bask"
 if kind=="peacock":return "display"
 return "forage"
func tick(actor: Node3D, delta: float) -> bool:
 age+=delta
 hunger=minf(1.0,hunger+delta/900.0);thirst=minf(1.0,thirst+delta/1100.0)
 energy=maxf(0.0,energy-delta/1800.0)
 retry_left=maxf(0.0,retry_left-delta)
 if actor.manual_order:return false
 var world: Node3D=actor.garden
 var kind:=role(actor)
 var hour:=fposmod(6.0+world.valley_cycle.elapsed/100.0,24.0)
 var water: bool=not world.wildlife.water_cells().is_empty() if is_instance_valid(world.wildlife) else false
 var desired:=priority(kind,hour,world.valley_cycle.rain_strength,water)
 if desired!=state:
  state=desired;activity_left=0;retry_left=0
  actor.directed_path.clear();actor.commanded_goal=Vector2i(-1,-1)
  actor.destination=actor.position;actor.next_cell=world.local_to_cell(actor.position)
 if activity_left>0:
  activity_left=maxf(0.0,activity_left-delta)
  if activity_left==0:
   if state in ["forage","riverbank"]:hunger=maxf(0.0,hunger-0.4)
   if state in ["drink","riverbank"]:thirst=maxf(0.0,thirst-0.5)
  if state in ["rest","shelter","bask"]:energy=minf(1.0,energy+delta*0.025)
  describe(actor)
  return true
 if world.contains_cell(actor.commanded_goal):return false
 if retry_left>0:return true
 choose(actor)
 describe(actor)
 return not world.contains_cell(actor.commanded_goal)
func describe(actor: Node3D) -> void:
 var labels={"shelter":"Sheltering from the rain","rest":"Resting in a quiet spot","welcome":"Watching the northern entrance","inspect":"Checking the garden plots","plants":"Inspecting plants and flowers","drink":"Seeking a dry drinking bank","riverbank":"Foraging by the water","forage":"Looking for food","bask":"Basking on warm open ground","display":"Displaying in an open clearing"}
 reason=labels.get(state,"Observing the garden")
 actor.set_meta("ai_state",state)
 actor.set_meta("inspection_text",role(actor).capitalize()+": "+reason.to_lower()+".")
func choose(actor: Node3D) -> void:
 var world: Node3D=actor.garden
 var kind:=role(actor)
 var cover: Array[Vector2i]=[]
 var plants: Array[Vector2i]=[]
 for node in world.get_children():
  if not node is Node3D or not node.has_meta("purchase_record"):continue
  var record: Dictionary=node.get_meta("purchase_record")
  var at: Vector2i=world.local_to_cell(node.position)
  if str(record.id) in ["ash","birch","cottage"]:cover.append(at)
  if str(record.id) in ["ash","birch","planter"]:plants.append(at)
 for at in world.crops:plants.append(at)
 var water: Array[Vector2i]=world.wildlife.water_cells() if is_instance_valid(world.wildlife) else []
 var start: Vector2i=world.local_to_cell(actor.position)
 var frontier: Array[Vector2i]=[start]
 var parents: Dictionary={start:start}
 var distances: Dictionary={start:0}
 var index:=0
 var best:= -INF
 var selected:=start
 while index<frontier.size():
  var cell: Vector2i=frontier[index];index+=1
  var distance: int=distances[cell]
  if actor._can_reserve(cell):
   var ground: int=world.get_terrain(cell)
   var edge: int=mini(mini(cell.x,cell.y),mini(world.grid_size.x-1-cell.x,world.grid_size.y-1-cell.y))
   var value: float=-float(distance)*0.55
   if state in ["rest","shelter"]:
    value+=18.0/(1.0+nearest(cell,cover)) if not cover.is_empty() else 12.0/(1.0+edge)
    if ground==3:value+=3.0
   elif state=="welcome":value-=Vector2(cell).distance_to(Vector2(world.grid_size.x/2,1))*1.5
   elif state in ["inspect","plants"]:
    value+=25.0/(1.0+nearest(cell,plants)) if not plants.is_empty() else 7.0/(1.0+edge)
    if ground==6:value+=3.0
   elif state in ["drink","riverbank"]:
    value+=25.0/(1.0+nearest(cell,water)) if not water.is_empty() else 0.0
   elif state=="bask":
    value+=12.0 if ground==7 else (5.0 if ground==1 else 0.0)
    value+=minf(float(edge),5.0)
   elif state=="display":
    value+=8.0 if ground==2 else 0.0;value+=minf(float(edge),5.0)
   else:
    value+=12.0 if ground in [2,3] else (5.0 if ground==0 else 0.0)
    if kind in ["hedgehog","badger"]:value+=5.0/(1.0+edge)
    if kind=="chicken" and ground==0:value+=7.0
   if state not in ["rest","shelter","welcome"] and visited.has(cell):value-=maxf(0.0,18.0-(age-float(visited[cell]))*0.06)
   if value>best:best=value;selected=cell
  for direction in actor.DIRECTIONS:
   var next: Vector2i=cell+direction
   if parents.has(next) or not actor._walkable(next):continue
   if absf(world.cell_center(next).y-world.cell_center(cell).y)>0.4:continue
   # Reserved cells are temporary obstacles, not destinations to walk through.
   if not actor._can_reserve(next):continue
   parents[next]=cell;distances[next]=distance+1;frontier.append(next)
 if best==-INF:
  retry_left=2.0;reason="Waiting for a clear route";return
 goal=selected
 if selected==start and actor.position.distance_to(world.cell_center(start))<0.05:
  arrived();return
 var path: Array[Vector2i]=[]
 var at:=selected
 while at!=start:path.push_front(at);at=parents[at]
 if path.is_empty():path.append(start)
 actor.directed_path=path;actor.commanded_goal=selected
 actor.cell=start;actor.next_cell=start;actor.destination=world.cell_center(start)
 actor.arrival_rest=0.0
func arrived() -> void:
 visited[goal]=age
 activity_left=20.0 if state=="rest" else (12.0 if state=="shelter" else 5.0)
 if visited.size()>100:
  for key in visited.keys():
   if age-float(visited[key])>300:visited.erase(key)
static func nearest(at: Vector2i, cells: Array[Vector2i]) -> float:
 var result:=1000.0
 for cell in cells:result=minf(result,Vector2(at).distance_to(Vector2(cell)))
 return result
