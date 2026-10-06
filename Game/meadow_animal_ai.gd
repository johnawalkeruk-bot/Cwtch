extends Node
## The approach animals keep a small home range instead of freezing after arrival.
## Their cinematic crossing remains authored; these routines run afterwards.
var arrival: Node3D
var agents: Array[Dictionary]=[]
func setup(owner_arrival: Node3D) -> void:
 arrival=owner_arrival
 var actors: Array[Node3D]=[arrival.crossing]
 actors.append_array(arrival.animals)
 for i in actors.size():
  var actor:=actors[i]
  agents.append({"actor":actor,"home":actor.position,"target":actor.position,"state":"","wait":0.0,"patch":i,"phase":float(i),"rabbit":i==0,"base_scale":actor.scale})
func decide(rabbit: bool, hour: float, rain: float) -> String:
 if rain>=0.5:return "shelter"
 if hour<6 or hour>=21:return "rest"
 if rabbit and hour>=10 and hour<17:return "rest"
 return "graze"
func _physics_process(delta: float) -> void:
 if arrival.active or not is_instance_valid(arrival.garden.valley_cycle):return
 if arrival.garden.guide.visible:return
 var cycle: Node=arrival.garden.valley_cycle
 var hour:=fposmod(6.0+cycle.elapsed/100.0,24.0)
 for data in agents:
  var actor: Node3D=data.actor
  var desired:=decide(data.rabbit,hour,cycle.rain_strength)
  data.phase+=delta
  if data.state!=desired or data.wait<=0.0 and actor.position.distance_to(data.target)<0.04:
   data.state=desired
   data.wait=18.0 if desired=="graze" else 30.0
   # Grazing patches stay by each animal's original meadow; shelter lies at its wooded edge.
   var offset:=Vector3(-1.5,0,-1.5)
   if desired=="graze":
    data.patch=(int(data.patch)+1)%4
    offset=[Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)][data.patch]
   data.target=data.home+offset
   data.target.y=arrival.ground(data.target.x,data.target.z)
   actor.set_meta("ai_state",desired)
  var offset: Vector3=data.target-actor.position;offset.y=0
  var moving:=offset.length()>0.035
  if moving:
   var heading:=atan2(offset.x,offset.z)+(PI/2.0 if data.rabbit else 0.0)
   actor.rotation.y=lerp_angle(actor.rotation.y,heading,1.0-exp(-2.5*delta))
   var step:=offset.normalized()*minf(offset.length(),delta*(0.32 if data.rabbit else 0.22))
   var next:=actor.position+step
   var clear:=true
   for other in agents:
    if other.actor==actor:continue
    if Vector2(next.x-other.actor.position.x,next.z-other.actor.position.z).length()<1.4:clear=false
   if clear:actor.position=next
   data.wait=18.0 if desired=="graze" else 30.0
  else:data.wait=maxf(0.0,data.wait-delta)
  actor.position.y=arrival.ground(actor.position.x,actor.position.z)
  if data.rabbit and moving:actor.position.y+=absf(sin(data.phase*8.0))*.06
  actor.rotation.z=sin(data.phase*7)*.02 if moving else 0.0
  actor.scale=data.base_scale*Vector3(1,1+sin(data.phase*1.5)*.004,1)
