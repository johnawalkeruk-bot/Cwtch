extends Node3D
const Stock=preload("res://village_stock.gd")
const SHOPS=["THE ANIMAL KEEPER","THE PLANT NURSERY","THE DECORATOR","THE BUILDER"]
const SUBTITLES=["New companions for your garden","A little more green","Small comforts, made with care","A home in the valley"]
const CHUNK_SIZE=2.0
var chunk_count:=Vector2i(12,12)
var valley_cycle: Node3D
var background_meadow: Node3D
var moon: DirectionalLight3D
var lightning: DirectionalLight3D
var rain: CPUParticles3D
var clock_label: Label
var sun: DirectionalLight3D
var outdoor_environment: Environment
var indoor_environment: Environment
var host: Node3D
var exterior: Node3D
var interior: Node3D
var camera: Camera3D
var spirit: CharacterBody3D
var ring: Node3D
var yaw:=0.0
var pitch:=PI/4.0
var selected_shop:=-1
var current_shop:=-1
var paused:=false
var trigger_held:=false
var hud: Label
var prompt: Label
var shop_panel: PanelContainer
var shop_title: Label
var shop_note: Label
var balance: Label
var stock_list: VBoxContainer
var receipt: Label
var pause_panel: PanelContainer
var showcase: Node3D
var ambience: Node
var purchase_buttons: Array[Button]=[]

func _ready() -> void:
 position=Vector3(1000,0,0)
 exterior=Node3D.new()
 add_child(exterior)
 interior=Node3D.new()
 interior.position=Vector3(0,0,-100)
 add_child(interior)
 interior.hide()
 camera=Camera3D.new()
 camera.near=.05
 camera.far=500
 camera.fov=68
 add_child(camera)
 var world:=WorldEnvironment.new()
 sun=DirectionalLight3D.new()
 add_child(sun)
 preload("res://welsh_sky.gd").apply(world,sun)
 outdoor_environment=world.environment
 outdoor_environment.sky.sky_material.set_shader_parameter("sun_direction",Vector3(.4,.75,.2))
 outdoor_environment.sky.sky_material.set_shader_parameter("cloud_cover",.35)
 sun.light_energy=.65
 camera.environment=outdoor_environment
 indoor_environment=Environment.new()
 indoor_environment.background_mode=Environment.BG_COLOR
 indoor_environment.background_color=Color("30251c")
 indoor_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 indoor_environment.ambient_light_color=Color("f0d9b5")
 indoor_environment.ambient_light_energy=.55
 world.free()
 _build_street()
 _build_room()
 _build_ui()
 var compass_layer:=CanvasLayer.new()
 add_child(compass_layer)
 var compass:=preload("res://garden_compass.gd").new()
 compass_layer.add_child(compass)
 compass.setup(camera)
 ambience=preload("res://valley_ambience.gd").new()
 add_child(ambience)
 ControllerInput.mode_changed.connect(_input_mode)
 ControllerInput.disconnected.connect(func(): if current_shop<0: _pause(true))

func activate(owner_menu: Node3D) -> void:
 host=owner_menu
 valley_cycle=host.garden.valley_cycle
 outdoor_environment=valley_cycle.environment
 camera.environment=outdoor_environment
 background_meadow=preload("res://village_outdoors.gd").new()
 exterior.add_child(background_meadow)
 background_meadow.build(self)
 moon=DirectionalLight3D.new()
 add_child(moon)
 lightning=DirectionalLight3D.new()
 add_child(lightning)
 rain=valley_cycle.rain.duplicate() as CPUParticles3D
 rain.mesh=rain.mesh.duplicate()
 rain.mesh.material=rain.mesh.material.duplicate()
 rain.position=Vector3(0,3.2,0)
 exterior.add_child(rain)
 var weather=preload("res://model_weather.gd").new()
 add_child(weather)
 weather.setup(self)
 valley_cycle.active_ambience=ambience
 _sync_weather(0.0)
 camera.make_current()
 _leave_shop()
 preload("res://diorama_camera.gd").follow(camera,spirit.position,yaw,pitch)

func _solid(parent: Node3D, dimensions: Vector3, at: Vector3, shop: int=-1) -> void:
 var body:=StaticBody3D.new()
 body.collision_layer=1
 parent.add_child(body)
 body.position=at
 if shop>=0: body.set_meta("shop",shop)
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=dimensions
 collision.shape=shape
 body.add_child(collision)

func _build_street() -> void:
 for i in range(4):
  var side: float=-1.0 if i%2==0 else 1.0
  var at:=Vector3(side*7,0,-10 if i<2 else 4)
  var cottage:=preload("res://assets/cottage.glb").instantiate()
  cottage.scale=Vector3.ONE*(5.8/.982788)
  cottage.position=at
  cottage.rotation.y=PI/2 if side<0 else -PI/2
  exterior.add_child(cottage)
  _solid(exterior,Vector3(5.6,4.3,5.8),at+Vector3(0,2.15,0),i)
  var sign:=Label3D.new()
  sign.text=SHOPS[i]
  sign.position=Vector3(side*3.75,2.25,at.z)
  sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  sign.font_size=40
  sign.pixel_size=.008
  sign.modulate=Color("ffe1a2")
  sign.outline_size=9
  exterior.add_child(sign)
  Stock.box(exterior,Vector3(.14,2.2,.14),Color("58422c"),Vector3(side*3.75,1.1,at.z))
  # Broad selectable frontage: the sign and cottage both open the same shop.
  var area:=Area3D.new()
  area.collision_layer=16
  area.set_meta("shop",i)
  area.position=at+Vector3(0,2.2,0)
  var shape:=CollisionShape3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(5.9,4.5,6.1)
  shape.shape=box
  exterior.add_child(area)
  area.add_child(shape)
 var placements: Array[Transform3D]=[]
 for side in [-1,1]:
  for z in range(-27,25,8): placements.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.75),Vector3(side*16,0,z)))
 preload("res://imported_trees.gd").plant(exterior,placements,"birch")
 spirit=CharacterBody3D.new()
 spirit.collision_layer=2
 spirit.collision_mask=1
 exterior.add_child(spirit)
 spirit.position=Vector3(0,0,16)
 var collision:=CollisionShape3D.new()
 var sphere:=SphereShape3D.new()
 sphere.radius=.28
 collision.shape=sphere
 collision.position.y=.4
 spirit.add_child(collision)
 ring=preload("res://gliding_cursor.gd").new()
 exterior.add_child(ring)
 ring.surface_height=func(_point: Vector2) -> float: return 0.0
 ring.follow_feet(spirit.position,Vector2.ONE*0.7,0.0)

func _build_room() -> void:
 Stock.box(interior,Vector3(12,.18,10),Color("584332"),Vector3(0,4,0))
 Stock.box(interior,Vector3(.2,4,10),Color("c7b68e"),Vector3(5.9,2,0))
 Stock.box(interior,Vector3(12,.15,10),Color("79543a"),Vector3(0,-.1,0))
 for x in range(-6,7): Stock.box(interior,Vector3(.018,.015,10),Color("443126"),Vector3(x,0,0))
 Stock.box(interior,Vector3(12,4,.2),Color("e0ceaa"),Vector3(0,2,-4.5))
 Stock.box(interior,Vector3(.2,4,10),Color("c7b68e"),Vector3(-5.9,2,0))
 for x in [-5,-2,2,5]: Stock.box(interior,Vector3(.2,4,.26),Color("493626"),Vector3(x,2,-4.3))
 Stock.box(interior,Vector3(12,.24,.3),Color("493626"),Vector3(0,3.65,-4.3))
 Stock.box(interior,Vector3(5,1.0,1.1),Color("705036"),Vector3(-1.3,.5,-1.4))
 Stock.box(interior,Vector3(5.2,.12,1.3),Color("b88b58"),Vector3(-1.3,1.06,-1.4))
 for y in [1.2,2.2]: Stock.box(interior,Vector3(4,.1,.6),Color("674831"),Vector3(-1.8,y,-4.0))
 for i in range(7):
  var pot:=Stock.model("planter")
  pot.scale=Vector3.ONE*.7
  pot.position=Vector3(-3.4+i*.52,1.25,-4)
  interior.add_child(pot)
 var light:=OmniLight3D.new()
 light.position=Vector3(-1,3,0)
 light.light_color=Color("ffd396")
 light.light_energy=1.2
 light.omni_range=12
 interior.add_child(light)
 showcase=Node3D.new()
 showcase.position=Vector3(-1.6,1.14,-1.4)
 interior.add_child(showcase)

func _label(parent: Node, text: String, size: int=18) -> Label:
 var label:=Label.new()
 label.text=text
 label.add_theme_font_size_override("font_size",size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> Button:
 var button:=Button.new()
 button.text=text
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func _build_ui() -> void:
 var layer:=CanvasLayer.new()
 add_child(layer)
 var root:=Control.new()
 root.theme=preload("res://cwtch_theme.gd").make()
 layer.add_child(root)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var panel:=PanelContainer.new()
 root.add_child(panel)
 panel.position=Vector2(24,24)
 var stack:=VBoxContainer.new()
 panel.add_child(stack)
 _label(stack,"C W T C H  /  THE VILLAGE",21)
 hud=_label(stack,"",15)
 clock_label=_label(stack,"",16)
 prompt=_label(root,"",21)
 prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 prompt.offset_left=-270; prompt.offset_right=270
 prompt.offset_top=-30; prompt.offset_bottom=65
 prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
 prompt.add_theme_constant_override("shadow_offset_y",2)
 prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
 shop_panel=PanelContainer.new()
 root.add_child(shop_panel)
 shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
 shop_panel.offset_left=-440; shop_panel.offset_right=-28
 shop_panel.offset_top=-280; shop_panel.offset_bottom=280
 var shop_stack:=VBoxContainer.new()
 shop_stack.add_theme_constant_override("separation",10)
 shop_panel.add_child(shop_stack)
 shop_title=_label(shop_stack,"",22)
 shop_note=_label(shop_stack,"",15)
 balance=_label(shop_stack,"",19)
 stock_list=VBoxContainer.new()
 stock_list.add_theme_constant_override("separation",8)
 shop_stack.add_child(stock_list)
 receipt=_label(shop_stack,"Purchases are delivered to clear ground\nin your garden.",16)
 receipt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 receipt.custom_minimum_size=Vector2(350,70)
 _button(shop_stack,"Back to the street",_leave_shop)
 shop_panel.hide()
 pause_panel=PanelContainer.new()
 root.add_child(pause_panel)
 pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 pause_panel.offset_left=-210; pause_panel.offset_right=210
 pause_panel.offset_top=-160; pause_panel.offset_bottom=160
 var pause_stack:=VBoxContainer.new()
 pause_stack.add_theme_constant_override("separation",12)
 pause_panel.add_child(pause_stack)
 _label(pause_stack,"A MOMENT IN THE VILLAGE",22)
 _button(pause_stack,"Continue exploring",func(): _pause(false))
 _button(pause_stack,"Return to the garden",func(): host.return_from_village())
 _button(pause_stack,"Save & Quit",func(): host.save_and_quit())
 pause_panel.hide()

func _input_mode() -> void:
 if current_shop>=0: ControllerInput.focus_first.call_deferred(shop_panel)
 elif paused: ControllerInput.focus_first.call_deferred(pause_panel)

func _pause(value: bool) -> void:
 paused=value
 pause_panel.visible=value
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
 if value: ControllerInput.focus_first.call_deferred(pause_panel)
 else:
  var focus:=get_viewport().gui_get_focus_owner()
  if focus: focus.release_focus()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(host): return
 ambience.muted=host.garden.ambience_muted
 _sync_weather(delta)
 hud.text="%d coins  ·  %s"%[host.coins,"Left stick move · Right stick look · Menu pause" if ControllerInput.using_pad else "WASD move · Mouse look · Esc travel menu"]
 if current_shop>=0:
  showcase.rotation.y+=delta*.2
  return
 if paused: return
 var look:=ControllerInput.look()
 yaw-=look.x*delta*1.8
 pitch=clampf(pitch+look.y*delta*1.5,-.55,1.1)
 var move:=(Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))+ControllerInput.movement()).limit_length()
 spirit.velocity=Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)*3.0
 spirit.move_and_slide()
 spirit.position.x=clampf(spirit.position.x,-12,12)
 spirit.position.z=clampf(spirit.position.z,-24,19)
 preload("res://diorama_camera.gd").follow(camera,spirit.position,yaw,pitch)
 var origin:=camera.global_position
 var ray:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*24,1|16)
 ray.collide_with_areas=true
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 selected_shop=int(hit.collider.get_meta("shop",-1)) if not hit.is_empty() else -1
 if selected_shop>=0:
  var side: float=-1.0 if selected_shop%2==0 else 1.0
  ring.follow_object(Vector3(side*7,0,-10 if selected_shop<2 else 4),Vector2(6.4,6.4),delta)
 else: ring.follow_object(spirit.position,Vector2.ONE*0.7,delta)
 prompt.text=(SHOPS[selected_shop]+"\n"+("A / Cross · enter" if ControllerInput.using_pad else "Click / E · enter")) if selected_shop>=0 else "·"

func _unhandled_input(event: InputEvent) -> void:
 if not is_instance_valid(host): return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide"):
  if current_shop>=0: _leave_shop()
  else: _pause(not paused)
  get_viewport().set_input_as_handled()
  return
 if paused or current_shop>=0: return
 if event is InputEventMouseMotion:
  yaw-=event.relative.x*.004
  pitch=clampf(pitch+event.relative.y*.004,-.55,1.1)
 var enter: bool=event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT or event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E
 if event.is_action("pad_use"):
  enter=event.is_action_pressed("pad_use") and not trigger_held
  trigger_held=event.is_action_pressed("pad_use")
 if enter and selected_shop>=0:
  enter_shop(selected_shop)
  get_viewport().set_input_as_handled()

func enter_shop(index: int) -> void:
 if index<0 or index>=SHOPS.size(): return
 current_shop=index
 camera.environment=indoor_environment
 sun.hide()
 moon.hide()
 lightning.hide()
 exterior.hide()
 interior.show()
 shop_panel.show()
 prompt.hide()
 paused=false
 pause_panel.hide()
 camera.position=Vector3(1.3,2.4,-93.5)
 camera.look_at(to_global(Vector3(0,1.2,-102)))
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 shop_title.text=SHOPS[index]
 shop_note.text=SUBTITLES[index]
 receipt.text="Delivered to clear ground in your garden.\nYou begin with 500 village coins."
 for child in stock_list.get_children(): child.free()
 purchase_buttons.clear()
 for item in Stock.STOCK:
  if item.shop!=index: continue
  var button:=_button(stock_list,"%s  ·  %d coins"%[item.name,item.price],func(): _buy(item.id))
  button.mouse_entered.connect(func(): _display(item.id))
  button.focus_entered.connect(func(): _display(item.id))
  purchase_buttons.append(button)
  button.set_meta("item",item.id)
  var note:=_label(stock_list,item.note,14)
  note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _refresh_balance()
 _display(str(purchase_buttons[0].get_meta("item")))
 ControllerInput.focus_first.call_deferred(shop_panel)

func _display(id: String) -> void:
 for child in showcase.get_children(): child.free()
 var model: Node3D
 if id=="hedgehog": model=host.garden.hedgehog.visual.duplicate(0)
 else: model=Stock.model(id)
 var bounds: AABB=preload("res://floating_tool.gd").bounds(model)
 var factor:=1.6/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
 model.scale*=factor
 model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
 showcase.add_child(model)

func _refresh_balance() -> void:
 balance.text="Your purse: %d coins"%host.coins
 for button in purchase_buttons:
  var entry: Dictionary=Stock.item(button.get_meta("item"))
  button.disabled=host.coins<int(entry.price)

func _buy(id: String) -> void:
 receipt.text=host.purchase_village_item(id)
 _refresh_balance()

func _leave_shop() -> void:
 current_shop=-1
 camera.environment=outdoor_environment
 sun.show()
 if is_instance_valid(moon): moon.show()
 if is_instance_valid(lightning): lightning.show()
 interior.hide()
 exterior.show()
 shop_panel.hide()
 prompt.show()
 for child in showcase.get_children(): child.free()
 _pause(false)
 selected_shop=-1

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause_panel) and current_shop<0: _pause(true)

func _sync_weather(delta: float) -> void:
 if not is_instance_valid(valley_cycle):return
 # Advance the garden's single clock while its scene is inactive.
 if not paused:valley_cycle.advance(delta)
 for pair in [[sun,valley_cycle.sun],[moon,valley_cycle.moon],[lightning,valley_cycle.lightning]]:
  var target: DirectionalLight3D=pair[0]
  var source: DirectionalLight3D=pair[1]
  target.global_rotation=source.global_rotation
  target.light_color=source.light_color
  target.light_energy=source.light_energy
  target.sky_mode=source.sky_mode
  target.visible=current_shop<0
 rain.position=spirit.position+Vector3.UP*3.2
 rain.emitting=valley_cycle.rain_strength>0.03 and current_shop<0
 rain.speed_scale=0.0 if paused else 1.0
 rain.amount=valley_cycle.rain.amount
 rain.direction=valley_cycle.rain.direction
 rain.mesh.material.albedo_color=valley_cycle.rain.mesh.material.albedo_color
 background_meadow.material.set_shader_parameter("wetness",valley_cycle.wetness)
 clock_label.text=valley_cycle.clock_label.text
 var daylight: float=valley_cycle.sky_material.get_shader_parameter("daylight")
 ambience.update_mix(delta,valley_cycle.rain_strength,daylight,paused)
