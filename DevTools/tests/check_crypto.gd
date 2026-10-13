extends SceneTree
var failures:=0
func _initialize():
 create_timer(100).timeout.connect(func():push_error("CRYPTO TEST TIMEOUT");quit(1))
 run.call_deferred()
func check(ok: bool, message: String):
 if not ok:failures+=1;push_error(message)
func run():
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
 var crypto=garden.get_node("Crypto")
 check(crypto.animation_player.has_animation("Walk") and crypto.animation_player.has_animation("Idle"),"Original walk and idle clips imported")
 var skeleton: Skeleton3D=crypto.visual.find_children("*","Skeleton3D",true,false)[0]
 check(skeleton.get_bone_count()>=100,"Original weighted skeleton retained")
 var ankle=skeleton.find_bone("l_leg_AnkleSHJnt")
 crypto.animation_player.play("Walk");crypto.animation_player.seek(.15,true)
 var pose=skeleton.get_bone_pose(ankle)
 crypto.animation_player.seek(.7,true)
 check(not pose.is_equal_approx(skeleton.get_bone_pose(ankle)),"Walking animation actually moves the leg bones")
 crypto.brain.tick(crypto,.1)
 check(crypto.brain.state=="inspect","Daytime inspection routine")
 var origin: Vector3=crypto.position
 var walked:=false
 for i in 2400:
  crypto.advance(1.0/60)
  walked=walked or crypto.current_clip=="Walk"
 check(walked and crypto.position.distance_to(origin)>.3,"Autonomous AI physically walks with walk clip")
 var other=garden.get_node("Meera")
 check(not crypto._can_reserve(other.next_cell),"Respects another NPC's reserved space")
 var blocked=Vector2i(10,10);garden.set_terrain(blocked,garden.Terrain.WATER)
 check(not crypto._walkable(blocked),"Avoids water")
 garden.valley_cycle.rain_strength=.9;crypto.brain.tick(crypto,.1)
 check(crypto.brain.state=="shelter","Heavy rain changes destination to shelter")
 garden.valley_cycle.rain_strength=0;garden.valley_cycle.elapsed=1700;crypto.brain.tick(crypto,.1)
 check(crypto.brain.state=="rest","Rests at night")
 garden._set_guide(true);var age=crypto.brain.age;crypto.advance(1)
 check(crypto.brain.age==age,"Pause stops NPC decisions")
 garden._set_guide(false)
 garden.valley_cycle.elapsed=600;garden.valley_cycle._process(0)
 garden.hedgehog_intro.set_process(false);garden.northern_arrival.set_process(false)
 garden.local_coop.set_process(false);garden.local_coop.suspend_render()
 if DisplayServer.get_name()!="headless":
  crypto.animation_player.play("Idle");crypto.animation_player.seek(.5,true)
  crypto.visual.rotation.y=0.0
  check(crypto._can_reserve(Vector2i(23,22)),"Portrait location is clear of other NPCs")
  crypto.position=garden.cell_center(Vector2i(23,22))
  crypto.reset_physics_interpolation()
  print("VISUAL_STATE ",crypto.global_position," ",crypto.visual.global_position," ",crypto.is_visible_in_tree()," ",crypto.visual.get_child(0).name)
  var view:=SubViewport.new()
  view.size=Vector2i(1280,720);view.world_3d=garden.get_world_3d()
  view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view)
  var camera:=Camera3D.new()
  view.add_child(camera);camera.make_current()
  camera.environment=garden.camera.environment
  camera.global_position=crypto.global_position+Vector3(1.5,1.2,2.3)
  camera.look_at(crypto.global_position+Vector3(0,.65,0))
  print("CAPTURE_CAMERA ",camera.global_transform)
  for frame in 5:
   camera.make_current()
   await process_frame;await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/crypto-garden.png"))
 menu.queue_free();await create_timer(1).timeout
 if failures==0:print("CRYPTO_PASS: rig, animated bones, autonomous walking, reservations, water avoidance, rain, night and pause")
 quit(1 if failures else 0)
