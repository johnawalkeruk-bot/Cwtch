extends Node3D
const Stock=preload("res://village_stock.gd")
var keeper: Node3D
var showcase: Node3D
var window_material: StandardMaterial3D
var village: Node3D
var kind:=0
var wood_materials: Dictionary={}
func box(size: Vector3, at: Vector3, color: String) -> MeshInstance3D:
 var node:=Stock.box(self,size,Color(color),at)
 var tint:=Color(color)
 if tint.r>tint.g*1.1 and tint.b<tint.g*.85:
  if not wood_materials.has(color):
   var material:=ShaderMaterial.new();material.shader=preload("res://shop_wood.gdshader")
   material.set_shader_parameter("wood_tint",tint);wood_materials[color]=material
  node.material_override=wood_materials[color]
 return node
func prop(id: String, at: Vector3, scale_value: float=1.0) -> Node3D:
 var node:=Stock.model(id);add_child(node);node.position=at;node.scale*=scale_value;return node
func sign_text(text: String, at: Vector3, size: int=36) -> void:
 var label:=Label3D.new();label.text=text;label.font_size=size;label.pixel_size=0.007
 label.modulate=Color("f6e6be");label.outline_size=5;label.position=at;add_child(label)
func build(world: Node3D, index: int) -> void:
 village=world;kind=index;name=["AnimalShop","PlantNursery","Decorators","McDoogalConstruction"][index]
 var wall: String=["8a9c96","9aab89","bca48d","aaa494"][index]
 box(Vector3(12,.2,10),Vector3(0,-.1,0),"795c40")
 for x in range(-6,7):box(Vector3(.024,.01,10),Vector3(x,0.012,0),"483826")
 box(Vector3(12,4,.2),Vector3(0,2,-4.5),wall)
 for x in [-5.9,5.9]:box(Vector3(.2,4,10),Vector3(x,2,0),wall)
 box(Vector3(12,.2,10),Vector3(0,4,0),"4b3b2c")
 for x in [-5.6,-3,0,3,5.6]:box(Vector3(.15,4,.3),Vector3(x,2,-4.32),"4d3e2a")
 for z in [-4,-1,2]:box(Vector3(12,.25,.18),Vector3(0,3.65,z),"513d29")
 # Framed window, sill and curtain panels; responds to the shared valley clock.
 var window:=box(Vector3(1.8,1.6,.06),Vector3(-4,2.15,-4.35),"c1d5d1")
 window_material=window.material_override;window_material.emission_enabled=true
 for x in [-4.95,-3.05,-4.0]:box(Vector3(.10,1.85,.14),Vector3(x,2.15,-4.25),"69513a")
 for y in [1.25,2.15,3.05]:box(Vector3(2.0,.1,.16),Vector3(-4,y,-4.24),"69513a")
 box(Vector3(2.3,.16,.42),Vector3(-4,1.2,-4.1),"a88a60")
 box(Vector3(4.4,.6,.1),Vector3(-.8,3.0,-4.08),"344a40")
 sign_text(world.SHOPS[index],Vector3(-.8,3.0,-3.99),32)
 # Lower counter leaves the keeper's face and hands visible beside the catalogue.
 box(Vector3(4.4,.8,1.0),Vector3(-.6,.4,-1.4),"604932")
 box(Vector3(4.6,.10,1.15),Vector3(-.6,.86,-1.4),"ab8859")
 for x in [-2.4,-1.2,0,1.2]:box(Vector3(.07,.74,.05),Vector3(x,.4,-.87),"c2a071")
 box(Vector3(1.65,.68,1.1),Vector3(-4.15,.34,.1),"594833")
 box(Vector3(1.8,.08,1.25),Vector3(-4.15,.72,.1),"ba9766")
 showcase=Node3D.new();showcase.position=Vector3(-4.15,.77,.1);add_child(showcase)
 if index==0:
  for i in range(3):
   var at:=Vector3(2.6+i*.72,.3,-3.9)
   box(Vector3(.63,.60,.55),at,"ae8e5f")
   for slat in range(4):box(Vector3(.04,.48,.06),at+Vector3(-.25+slat*.16,0,.3),"58452d")
  for x in [-2.3,-1.5]:
   var bowl:=CylinderMesh.new();bowl.top_radius=.22;bowl.bottom_radius=.17;bowl.height=.10
   Stock.part(self,bowl,Color("9c6747"),Vector3(x,.95,-1.4))
  sign_text("FEED · NESTS · GOOD COMPANY",Vector3(2.65,2,-4.25),21)
 elif index==1:
  for y in [.65,1.55]:
   box(Vector3(3.8,.12,.65),Vector3(2.4,y,-3.95),"62734c")
   for i in range(5):prop("planter",Vector3(.9+i*.7,y+.06,-3.95),.65)
  prop("planter",Vector3(-2,.92,-1.4),.7)
  prop("planter",Vector3(4.8,0,-1),1.1)
 elif index==2:
  prop("bench",Vector3(2.4,0,-3.1),1.3)
  prop("planter",Vector3(.9,.48,-3.1),.7)
  box(Vector3(3.2,.015,2),Vector3(-1,.025,1.0),"6c7471")
  for x in [1,2.5,4]:
   box(Vector3(1.05,1.3,.12),Vector3(x,2.35,-4.26),"765536")
   box(Vector3(.88,1.13,.14),Vector3(x,2.35,-4.17),"c6b892")
 else:
  # Timber rack, slate samples, measured plans and a small cottage maquette.
  for y in [.3,.65,1.0]:
   for x in [1.4,1.75,2.1]:box(Vector3(.26,.22,2.1),Vector3(x,y,-3.1),"916d45")
  for x in [3.1,3.75,4.4]:box(Vector3(.52,.36,.70),Vector3(x,.18,-3.0),"6c7779")
  box(Vector3(1.2,.018,.72),Vector3(-1.6,.92,-1.4),"486b79")
  for x in [-1.98,-1.6,-1.22]:box(Vector3(.012,.022,.60),Vector3(x,.93,-1.4),"e5ded0")
  for z in [-1.65,-1.15]:box(Vector3(1.04,.022,.012),Vector3(-1.6,.93,z),"e5ded0")
  prop("cottage",Vector3(.7,.92,-1.5),.22)
  sign_text("ANGUS MCDOOGAL · BUILDER",Vector3(.2,2.45,-4.03),23)
 keeper=preload("res://shop_keeper.gd").new();add_child(keeper);keeper.position=Vector3(-1.1,0,-2.55)
 keeper.setup(world,index==3)
 keeper.set_meta("keeper_name","Angus McDoogal" if index==3 else ["Animal keeper","Nursery keeper","Decorator"][index])
 var key:=OmniLight3D.new();key.position=Vector3(-2.2,2.9,1.3);key.light_color=Color("ffdfa5")
 key.light_energy=1.1;key.omni_range=10;key.shadow_enabled=true;add_child(key)
 var fill:=OmniLight3D.new();fill.position=Vector3(-4,2.4,-3.5);fill.light_color=Color("bdcfdf")
 fill.light_energy=.55;fill.omni_range=6;add_child(fill)
func _process(_delta: float) -> void:
 if not is_visible_in_tree() or not is_instance_valid(village.valley_cycle):return
 var hour: float=fposmod(6.0+village.valley_cycle.elapsed/100.0,24.0)
 var daylight: float=smoothstep(5.0,8.0,hour)*(1.0-smoothstep(17.0,21.0,hour))
 window_material.albedo_color=Color("263752").lerp(Color("bdcfc7"),daylight)
 window_material.emission=window_material.albedo_color*.3
