extends Node
## One placement interaction per spirit. Purchases are only charged on confirmation.
const Stock=preload("res://village_stock.gd")
var garden: Node3D
var driver: Node
var slot:=0
var purchase_id:=""
var animal: Node3D
var preview: Node3D
var marker: Node3D
var yaw:=0.0
var target:=Vector2i(-1,-1)
var problem:=""
var animation_speed:=1.0
var route_timer:=0.0
var route_target:=Vector2i(-99,-99)
var preview_materials: Array[StandardMaterial3D]=[]
func setup(world: Node3D, owner_node: Node, player_slot: int) -> void:
 garden=world;driver=owner_node;slot=player_slot
func active() -> bool:return not purchase_id.is_empty() or is_instance_valid(animal)
func say(text: String) -> void:
 driver.message=text
 if slot==0:driver._refresh_ui()
 else:driver.message_time=4.0
func begin_purchase(id: String) -> void:
 cancel(false)
 UISounds.play("drag-start")
 purchase_id=id;yaw=0.0
 driver._clear_use() if slot==0 else driver.clear_use()
 preview=Stock.model(id);garden.add_child(preview)
 for mesh in preview.find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in mesh.mesh.get_surface_count():
   var source: Material=mesh.get_active_material(surface)
   var material:=source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
   material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   material.emission_enabled=true
   material.emission=Color("c1d8cf")
   material.emission_energy_multiplier=0.3
   material.albedo_color.a=0.48
   material.set_meta("preview_color",material.albedo_color)
   mesh.set_surface_override_material(surface,material)
   preview_materials.append(material)
  mesh.material_override=null
 say("Aim to place %s · A / click confirms · LB/RB or Q/E rotates · B / Esc cancels"%Stock.item(id).name)
func begin_animal(subject: Node3D) -> bool:
 if not is_instance_valid(subject) or not subject.has_meta("animal_id") or not subject.has_method("command_move"):return false
 var id:=str(subject.get_meta("animal_id"))
 if int(garden.wildlife.records.get(id,{}).get("resident_day",0))<=0:
  say("This visitor has not become a resident yet.");return true
 if subject.has_meta("relocation_owner"):
  say("The other spirit is already guiding this animal.");return true
 if not garden.contains_cell(garden.local_to_cell(subject.position)):return false
 UISounds.play("select")
 cancel(false);animal=subject
 route_timer=0;route_target=Vector2i(-99,-99)
 animal.set_meta("relocation_owner",slot)
 animation_speed=animal.animation_player.speed_scale
 animal.animation_player.speed_scale=0
 driver._clear_use() if slot==0 else driver.clear_use()
 marker=preload("res://gliding_cursor.gd").new()
 marker.top_color=driver.cursor.top_color;marker.side_color=marker.top_color;marker.bottom_color=marker.top_color
 garden.add_child(marker);marker.surface_height=driver.cursor.surface_height
 driver.cursor.single_color(driver.cursor.side_color)
 say("Choose a dry destination · A / click to send your resident · B / Esc cancels")
 return true
func handle(event: InputEvent) -> bool:
 if not active():return false
 if event is InputEventMouseMotion:return false
 if event is InputEventKey and not event.pressed:return false
 if event is InputEventJoypadMotion:return false
 var pressed: bool=event.is_pressed()
 if pressed and ((event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B) or (event is InputEventKey and event.keycode==KEY_ESCAPE)):
  cancel();return true
 if pressed and ((event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode==KEY_ENTER)):
  confirm();return true
 if not purchase_id.is_empty() and pressed:
  if (event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]) or (event is InputEventKey and event.keycode in [KEY_Q,KEY_E]):
   var left: bool=event.button_index==JOY_BUTTON_LEFT_SHOULDER if event is InputEventJoypadButton else event.keycode==KEY_Q
   yaw=wrapf(yaw+(-PI/4 if left else PI/4),-PI,PI);return true
 if event is InputEventJoypadButton:return event.button_index!=JOY_BUTTON_START
 if event is InputEventMouseButton:return true
 return event is InputEventKey and event.keycode not in [KEY_W,KEY_A,KEY_S,KEY_D]
func update(delta: float) -> void:
 if not active():return
 var camera: Camera3D=driver.camera
 var origin:=camera.global_position
 var query:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*100,1)
 var hit:=garden.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():
  problem="Aim at the garden ground.";driver.cursor.clear()
  if is_instance_valid(preview):preview.hide()
  return
 if is_instance_valid(preview):preview.show()
 var point: Vector3=garden.to_local(hit.position)
 if not purchase_id.is_empty() and Vector2(point.x-driver.player.position.x,point.z-driver.player.position.z).length()<0.75:
  var forward: Vector3=-camera.global_basis.z;forward.y=0
  point=driver.player.position+forward.normalized()*(Stock.footprint(purchase_id).length()*0.5+0.65)
 target=garden.local_to_cell(point)
 if not garden.contains_cell(target):
  problem="Choose a spot inside the garden.";driver.cursor.clear()
  if is_instance_valid(preview):preview.hide()
  return
 var at: Vector3=garden.cell_center(target)
 if not purchase_id.is_empty():
  preview.position=at;preview.rotation.y=yaw
  problem=Stock.placement_error(garden,purchase_id,target,yaw)
  for material in preview_materials:material.albedo_color=material.get_meta("preview_color") if problem.is_empty() else Color(1,0.24,0.18,0.48)
  driver.cursor.follow_object(at,Stock.rotated_size(purchase_id,yaw),delta)
 else:
  marker.follow_feet(animal.position,Vector2.ONE*maxf(0.7,animal.collision_radius*3),delta)
  route_timer-=delta
  if target!=route_target or route_timer<=0 or delta==0:
   route_target=target;route_timer=0.25
   problem="That destination cannot be reached on dry, clear ground." if animal.route_to(target).is_empty() else ""
  driver.cursor.follow_object(at,Vector2.ONE*garden.MICRO_SIZE,delta)
func confirm() -> void:
 update(0.0)
 if not problem.is_empty():UISounds.play("invalid-drop");say(problem);return
 if not purchase_id.is_empty():
  var host: Node=garden.get_parent()
  var result: String=host.confirm_garden_purchase(purchase_id,target,yaw)
  if not result.is_empty():UISounds.play("error");say(result);return
  cancel(false);UISounds.play("purchase");say("Placed in your garden.")
 elif is_instance_valid(animal):
  if not animal.command_move(target):say("There is no clear route to that spot.");return
  cancel(false);UISounds.play("send");say("Your resident is on the way.")
func cancel(notify:=true) -> void:
 var had:=active()
 var buying:=not purchase_id.is_empty()
 if is_instance_valid(animal):
  animal.remove_meta("relocation_owner")
  animal.animation_player.speed_scale=animation_speed
 animal=null
 if is_instance_valid(preview):preview.queue_free()
 if is_instance_valid(marker):marker.queue_free()
 preview=null;marker=null;purchase_id="";preview_materials.clear()
 if is_instance_valid(driver):
  driver.cursor.restore_colors()
  if had:driver._clear_use() if slot==0 else driver.clear_use()
 if had and notify:UISounds.play("cancel");say("Placement cancelled. No coins spent." if buying else "Your resident is free to wander again.")
func _exit_tree() -> void:
 if is_instance_valid(animal):
  animal.remove_meta("relocation_owner");animal.animation_player.speed_scale=animation_speed
