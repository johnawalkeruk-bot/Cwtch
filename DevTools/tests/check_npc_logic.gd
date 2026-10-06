extends SceneTree
var failures:=0
func _initialize():
 create_timer(100).timeout.connect(func():push_error("NPC TEST TIMEOUT");quit(1))
 run.call_deferred()
func check(ok: bool, message: String):
 if not ok:failures+=1;push_error(message)
func shot(file: String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/"+file+".png"))
func place(actor, world, at: Vector2i):
 actor.cell=at;actor.next_cell=at;actor.position=world.cell_center(at);actor.destination=actor.position
 actor.directed_path.clear();actor.commanded_goal=Vector2i(-1,-1);actor.manual_order=false;actor.arrival_rest=0
 actor.brain.activity_left=0;actor.brain.retry_left=0
func run():
 var scenic=load("res://meadow_animal_ai.gd").new()
 check(scenic.decide(true,12,0)=="rest","Rabbit rests in daytime")
 check(scenic.decide(false,12,0)=="graze","Bulls graze during daylight")
 check(scenic.decide(false,12,1)=="shelter","Bulls respond to rain")
 scenic.free()
 var brain=load("res://npc_brain.gd").new()
 for kind in ["arthur","meera","chicken","peacock","robin","hedgehog","badger","dragon"]:
  check(brain.priority(kind,12,0.8,true)=="shelter",kind+" seeks rain shelter")
  var nocturnal=kind in ["hedgehog","badger"]
  check(brain.priority(kind,12 if nocturnal else 23,0,true)=="rest",kind+" has species sleep hours")
 check(brain.priority("arthur",8,0,false)=="welcome","Arthur at entrance in morning")
 check(brain.priority("arthur",12,0,false)=="inspect","Arthur inspects plots")
 check(brain.priority("meera",12,0,false)=="plants","Meera attends plants")
 brain.thirst=.9
 check(brain.priority("chicken",12,0,true)=="drink","Thirst prioritizes water")
 brain.thirst=.1;brain.hunger=.1
 check(brain.priority("dragon",12,0,true)=="bask","Fed dragon basks")
 check(brain.priority("peacock",12,0,true)=="display","Fed peacock displays")
 var menu=load("res://main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 await menu._begin_garden(true)
 var garden=menu.garden
 garden.northern_arrival.finish();garden.hedgehog_intro.welcome_pending=false
 if garden.hedgehog_intro.active:garden.hedgehog_intro._finish()
 garden._set_guide(false);garden.set_physics_process(false);garden.valley_cycle.set_process(false)
 garden.valley_cycle.elapsed=600;garden.valley_cycle.rain_strength=0
 for actor in get_nodes_in_group("garden_npcs"):actor.set_physics_process(false)
 garden.wildlife.hedgehog.set_physics_process(false);garden.wildlife.robin.set_physics_process(false)
 check(not garden.has_node("Visitor") and not garden.has_node("Angus"),"Visitor and Angus removed from garden")
 check(garden.wildlife.hedgehog.visit_state=="outside" and garden.wildlife.robin.visit_state=="outside","Wildlife still waits outside a new garden")
 var arthur=garden.get_node("Arthur");var meera=garden.get_node("Meera")
 if arthur.has_meta("arrival_waiting"):arthur.remove_meta("arrival_waiting")
 var Stock=load("res://village_stock.gd")
 var chicken=Stock.deliver(garden,{"id":"chicken","x":8,"z":18,"yaw":0.0});chicken.set_physics_process(false)
 place(chicken,garden,Vector2i(8,18))
 garden.set_terrain(Vector2i(9,18),garden.Terrain.GRASS)
 chicken.brain.tick(chicken,.1)
 check(chicken.brain.state=="forage" and chicken.brain.goal==Vector2i(9,18),"Chicken chooses reachable grass, not a random destination")
 for i in 1000:
  chicken.advance(1.0/60)
  if chicken.brain.activity_left>0:break
 check(chicken.cell==Vector2i(9,18),"AI physically reaches its selected food")
 garden.set_terrain(Vector2i(12,18),garden.Terrain.WATER)
 place(chicken,garden,Vector2i(11,18));chicken.brain.thirst=.9;chicken.brain.tick(chicken,.1)
 check(chicken.brain.state=="drink" and chicken.brain.goal==Vector2i(11,18),"Drink from a dry bank without walking into water")
 check(not chicken._walkable(Vector2i(12,18)),"Water remains an obstacle")
 garden.blocked_cells[Vector2i(10,18)]=true
 var path=chicken.route_to(Vector2i(9,18))
 check(not path.is_empty() and not path.has(Vector2i(10,18)),"Path routes around placed objects")
 place(meera,garden,Vector2i(9,18));check(not chicken._can_reserve(meera.cell),"NPC destinations reserve collision space")
 place(meera,garden,Vector2i(24,24))
 check(chicken.command_move(Vector2i(11,20)),"Player order accepted")
 garden.valley_cycle.rain_strength=1
 chicken.brain.tick(chicken,.1)
 check(chicken.manual_order and chicken.commanded_goal==Vector2i(11,20),"Player order overrides automatic shelter goal")
 for i in 2000:
  chicken.advance(1.0/60)
  if not chicken.manual_order:break
 check(chicken.cell==Vector2i(11,20) and not chicken.manual_order,"Player destination reached")
 chicken.arrival_rest=0;chicken.brain.tick(chicken,.1)
 check(chicken.brain.state=="shelter","Routine resumes after player order")
 place(arthur,garden,Vector2i(17,2));garden.valley_cycle.elapsed=200;garden.valley_cycle.rain_strength=0
 arthur.brain.tick(arthur,.1);check(arthur.brain.state=="welcome","Arthur morning routine wired to clock")
 garden.valley_cycle.elapsed=600;arthur.brain.tick(arthur,.1)
 check(arthur.brain.state=="inspect","Arthur routine changes with time")
 meera.brain.state="plants";meera.brain.activity_left=5;meera.advance(.1)
 check(meera.current_clip=="Start_Walk" and meera.animation_player.current_animation_position==0,"Meera uses still pose when no idle clip is supplied")
 garden._set_guide(true);var age=arthur.brain.age;arthur.advance(1)
 check(arthur.brain.age==age,"Pause freezes NPC decisions")
 garden._set_guide(false)
 menu.open_village();await process_frame
 var village=menu.village
 check(village.shop_rooms.size()==4,"Four distinct interiors")
 for index in 4:
  village.enter_shop(index);await process_frame
  check(village.active_keeper.angus==(index==3),"Only construction is run by Angus")
  check(village.active_keeper.state=="greeting","Keeper greets on entry")
  village.active_keeper._process(4);check(village.active_keeper.state=="explaining","Keeper discusses stock after greeting")
  village.active_keeper._process(6);check(village.active_keeper.state=="waiting","Keeper returns to idle")
  for other in 4:check(village.shop_rooms[other].visible==(other==index),"Only chosen room is visible")
  if index==0:village._display("hedgehog");check(village.showcase.get_child_count()==1,"Hedgehog shop preview works")
  await create_timer(0.4).timeout
  await shot("shop-"+str(index))
  village._leave_shop()
 menu.queue_free();await create_timer(1).timeout
 if failures==0:print("NPC_LOGIC_PASS: needs, species routines, reachable food and water, movement, obstacles, reservations, player priority, pause, visitor removal and all four keepers")
 quit(1 if failures else 0)
