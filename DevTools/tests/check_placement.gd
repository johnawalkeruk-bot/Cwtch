extends SceneTree
const Stock=preload("res://village_stock.gd")
var menu: Node
var garden: Node
func _initialize():run.call_deferred()
func button(index: int) -> InputEventJoypadButton:
 var e:=InputEventJoypadButton.new();e.button_index=index;e.pressed=true;e.device=-1;return e
func aim(cell: Vector2i):
 var at: Vector3=garden.cell_center(cell)
 garden.camera.position=at+Vector3(0,2,2)
 garden.camera.look_at(at)
func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/"+name+".png"))
func run():
 menu=load("res://main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 await menu._begin_garden(true)
 garden=menu.garden
 garden.northern_arrival.finish()
 if garden.hedgehog_intro.active:garden.hedgehog_intro._finish()
 garden.hedgehog_intro.welcome_pending=false
 garden._set_guide(false)
 garden.set_physics_process(false)
 garden.valley_cycle.set_process(false)
 garden.valley_cycle.elapsed=600
 garden.valley_cycle._update_visuals()
 for npc in get_nodes_in_group("garden_npcs"):npc.set_physics_process(false)
 await physics_frame
 garden.selected_target=null
 garden._unhandled_input(button(JOY_BUTTON_A));assert(not garden.tool_wheel.visible)
 garden._unhandled_input(button(JOY_BUTTON_X));assert(garden.tool_wheel.visible)
 garden._set_wheel(false)
 var starting_coins: int=menu.coins
 var count: int=menu.purchases.size()
 garden.placement.begin_purchase("bench")
 assert(garden.placement.active() and menu.coins==starting_coins)
 assert(not garden.placement.preview_materials.is_empty())
 for material in garden.placement.preview_materials:assert(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a<0.6)
 garden.placement.handle(button(JOY_BUTTON_RIGHT_SHOULDER))
 assert(is_equal_approx(garden.placement.yaw,PI/4))
 garden.placement.handle(button(JOY_BUTTON_B))
 assert(not garden.placement.active() and menu.coins==starting_coins and menu.purchases.size()==count)
 assert(not Stock.placement_error(garden,"cottage",Vector2i.ZERO,0).is_empty())
 var place:=Vector2i(20,26)
 assert(Stock.placement_error(garden,"bench",place,PI/2).is_empty(),Stock.placement_error(garden,"bench",place,PI/2))
 garden.blocked_cells[place]=true
 assert(not Stock.placement_error(garden,"bench",place,PI/2).is_empty())
 garden.blocked_cells.erase(place)
 var terrain: int=garden.get_terrain(place)
 garden.set_terrain(place,garden.Terrain.WATER)
 assert(not Stock.placement_error(garden,"bench",place,PI/2).is_empty())
 garden.set_terrain(place,terrain)
 garden.placement.begin_purchase("bench");garden.placement.yaw=PI/2
 aim(place);garden.placement.update(1)
 assert(garden.placement.target==place and garden.placement.problem.is_empty())
 await shot("purchase-preview")
 garden.placement.confirm()
 assert(not garden.placement.active() and menu.coins==starting_coins-30 and menu.purchases.size()==count+1)
 assert(is_equal_approx(menu.purchases.back().yaw,PI/2))
 assert(garden.blocked_cells.has(place))
 assert(menu.account_status.save_tail>=3.9)
 var data=JSON.parse_string(FileAccess.get_file_as_string(menu.SAVE_PATH))
 assert(preload("res://cloud_save_validator.gd").valid(data))
 assert(is_equal_approx(data.purchases.back().yaw,PI/2))
 var animal_cell:=Vector2i(10,14)
 var record={"id":"chicken","x":animal_cell.x,"z":animal_cell.y,"yaw":0.0}
 menu.purchases.append(record)
 var animal=Stock.deliver(garden,record);animal.set_physics_process(false)
 var select=animal.find_children("*","Area3D",true,false)[0]
 garden.selected_target=select
 garden._unhandled_input(button(JOY_BUTTON_A))
 assert(garden.placement.animal==animal and animal.has_meta("relocation_owner"))
 var before: Vector3=animal.position
 animal._physics_process(1)
 assert(animal.position==before and animal.animation_player.speed_scale==0)
 assert(garden.cursor.source_colors[0]==garden.cursor.side_color)
 assert(garden.placement.marker.top_color==garden.cursor.top_color)
 var second=garden.local_coop.second
 assert(second.placement.begin_animal(animal))
 assert(not second.placement.active())
 var goal:=Vector2i(12,14)
 garden.blocked_cells[Vector2i(11,14)]=true
 var route=animal.route_to(goal)
 assert(not route.is_empty() and not route.has(Vector2i(11,14)))
 aim(goal);garden.placement.update(1)
 assert(garden.placement.target==goal and garden.placement.problem.is_empty())
 await shot("resident-destination")
 garden.placement.confirm()
 assert(not animal.has_meta("relocation_owner") and animal.position==before and animal.commanded_goal==goal)
 assert(garden.cursor.source_colors.has(garden.cursor.top_color))
 for step in 3000:
  animal.advance(1.0/60.0)
  if animal.commanded_goal==Vector2i(-1,-1):break
 assert(animal.position.distance_to(garden.cell_center(goal))<0.01,"Resident must reach chosen destination")
 assert(menu._save_garden(false))
 assert(int(record.x)==goal.x and int(record.z)==goal.y,"Moved purchased residents persist their position")
 garden.blocked_cells.erase(Vector2i(11,14))
 garden.placement.begin_animal(animal);garden._set_guide(true)
 assert(not garden.placement.active() and not animal.has_meta("relocation_owner"))
 garden._set_guide(false)
 second.set_enabled(true)
 second.handle_input(button(JOY_BUTTON_X));assert(second.tool_wheel.visible)
 second.set_wheel(false)
 assert(second.placement.begin_animal(animal) and second.placement.active())
 assert(second.cursor.source_colors[0]==second.cursor.side_color)
 second.placement.handle(button(JOY_BUTTON_B));assert(not animal.has_meta("relocation_owner"))
 second.set_enabled(false)
 for entry in Stock.STOCK:
  garden.placement.begin_purchase(entry.id)
  assert(not garden.placement.preview_materials.is_empty(),entry.id+" needs a visible ghost")
  garden.placement.cancel(false)
 await process_frame
 garden._set_guide(true)
 menu.open_village();await process_frame
 menu.village.enter_shop(2)
 var balance: int=menu.coins
 menu.village._buy("planter")
 await process_frame
 await process_frame
 assert(not is_instance_valid(menu.village) and garden.placement.purchase_id=="planter")
 assert(menu.coins==balance,"Returning from shop must not spend money yet")
 garden.placement.cancel(false)
 print("PLACEMENT_PASS: X tools; transparent preview, free cancellation, rotation, occupied bounds, charged confirmation, save rotation, frozen resident, split colours, route around obstacle, persisted movement, two-player ownership and pause cleanup")
 menu.queue_free();await create_timer(1.0).timeout;quit()
