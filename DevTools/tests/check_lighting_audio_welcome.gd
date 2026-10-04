extends SceneTree
const History=preload("res://welcome_history.gd")
func _initialize():
 create_timer(100).timeout.connect(func():push_error("TEST TIMEOUT");quit(1))
 run.call_deferred()
func shot(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/"+name+".png"))
func run():
 var settings=root.get_node("AudioSettings")
 for bus in settings.BUSES:
  settings.set_level(bus,0.0)
  assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)))
  settings.set_level(bus,0.43)
  assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)))
  assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))),0.43))
 settings.restore()
 assert(is_equal_approx(settings.levels.Speech,0.43))
 var ui=root.get_node("UISounds")
 ui.set_volume(0.26);settings.set_level("Music",0.6);ui.restore()
 assert(is_equal_approx(ui.volume,0.26),"Mixer preserves UI settings")
 assert(is_equal_approx(settings.read_options().audio.Music,0.6))
 assert(History.should_play("test-account","","test-release"))
 History.complete("test-account","test-release")
 assert(not History.should_play("test-account","","test-release"),"New garden/restart does not repeat welcome")
 assert(History.should_play("test-account","test-release","next-release"),"A real update welcomes again")
 assert(not History.should_play("other-computer","test-release","test-release"),"Cloud save carries heard release")
 assert(History.should_play("another-account","","test-release"),"Other accounts retain their welcome")
 var menu=load("res://main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 for name in ["Volume","MusicVolume","UISFXVolume","AmbienceVolume","SoundeffectsVolume","SpeechVolume"]:
  assert(menu.options.find_child(name,true,false) is HSlider,"All six sliders on start menu")
 menu.options.show();menu.menu_buttons.hide();menu.heading.hide()
 menu.options.find_child("SpeechVolume",true,false).value=61
 assert(is_equal_approx(settings.levels.Speech,0.61))
 menu._save_options(70);settings.restore()
 assert(is_equal_approx(settings.levels.Speech,0.61),"Fullscreen/master save preserves mixer")
 await shot("six-channel-audio-options")
 menu._close_options()
 await menu._begin_garden(true)
 var garden=menu.garden
 garden.northern_arrival.finish()
 var intro=garden.hedgehog_intro
 intro.welcome_pending=false
 intro._begin("welcome")
 assert(intro.active and intro.voice.bus=="Speech")
 intro._begin_return();intro._finish()
 assert(intro.save_data().welcome_version==History.VERSION)
 intro.request_welcome()
 assert(not intro.welcome_pending,"Return to garden does not replay welcome")
 var old=preload("res://hedgehog_intro.gd").new()
 old.garden=garden;old.arthur=intro.arthur
 old.restore(intro.save_data());old.request_welcome();assert(not old.welcome_pending);old.free()
 menu.coins=731;garden.experience.total=248
 garden.set_terrain(Vector2i(1,1),2)
 garden.watered_cells[Vector2i(1,1)]=0.0;garden.watered_cells[Vector2i(2,1)]=0.7
 assert(menu._write_garden(false))
 var saved=JSON.parse_string(FileAccess.get_file_as_string(menu.SAVE_PATH))
 assert(saved.coins==731 and saved.experience.total==248 and saved.terrain[37]==2)
 assert(saved.watered.size()==1 and saved.summary.level==3)
 assert(preload("res://cloud_save_validator.gd").valid(saved))
 assert(garden.floating_tool.audio.bus=="Sound effects")
 for layer in menu.ambience.layers.values():assert(layer.bus=="Ambience")
 for channel in menu.valley_music.channels:assert(channel.bus=="Music")
 garden.hedgehog_intro.set_process(false)
 garden.set_process(false);garden.set_physics_process(false);garden.player.set_physics_process(false)
 garden.camera.position=Vector3(8,3.5,11);garden.camera.look_at(Vector3(0,0.5,0));garden.camera.make_current()
 garden.valley_cycle.set_process(false)
 for moment in [{"name":"daylight","time":600.0,"cloud":0.15,"rain":0.0},{"name":"rain","time":600.0,"cloud":0.95,"rain":0.7},{"name":"night","time":1800.0,"cloud":0.2,"rain":0.0}]:
  garden.valley_cycle.elapsed=moment.time;garden.valley_cycle.cloud_cover=moment.cloud;garden.valley_cycle.rain_strength=moment.rain
  garden.valley_cycle._update_visuals()
  assert(garden.valley_cycle.environment.ambient_light_energy>=0.19)
  assert(garden.valley_cycle.environment.ambient_light_energy<=0.4)
  assert(garden.valley_cycle.sun.shadow_enabled)
  await create_timer(0.25).timeout
  await shot("valley-lighting-"+moment.name)
 menu.queue_free();await create_timer(0.3).timeout
 print("LIGHT_AUDIO_WELCOME_PASS: six independent levels, mute/persistence/routing, once-per-release history/cloud restore, complete save metrics, day/rain/night")
 quit()
