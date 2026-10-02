extends SceneTree
var done := false
func _initialize():run.call_deferred()
func shot(name: String):
 await process_frame
 if DisplayServer.get_name()!='headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://../.local/'+name+'.png'))
func reveal(loader):
 await loader.finish()
 done=true
func run():
 var menu=load('res://main_menu.tscn').instantiate()
 root.add_child(menu);current_scene=menu
 await process_frame
 var loader=menu.garden_loader
 loader.begin()
 assert(loader.music.playing)
 await create_timer(0.5).timeout
 await shot('garden-loading-petals')
 var started:=Time.get_ticks_msec()
 reveal(loader)
 await create_timer(0.35).timeout
 assert(not loader.music.playing,'Song stops before transition finishes')
 await shot('garden-loading-scatter')
 while not done:await process_frame
 assert(Time.get_ticks_msec()-started<2000,'No wait for the song duration')
 assert(not loader.active)
 await menu._begin_garden(true)
 assert(menu.garden.loading_complete and not menu.loading)
 assert(not loader.music.playing and not loader.visible)
 assert(menu.garden.northern_arrival.active,'Arrival starts after reveal')
 menu.garden.northern_arrival.finish()
 if menu.garden.hedgehog_intro.active:menu.garden.hedgehog_intro._finish()
 menu.garden.hedgehog_intro.welcome_pending=false
 menu.open_menu()
 await menu._begin_garden(false)
 assert(not menu.loading and not loader.music.playing)
 assert(not menu.garden.northern_arrival.active,'Returning garden skips arrival')
 print('LOADING_PASS: animation, song, early stop, scatter, new garden, return garden and arrival handoff')
 menu.queue_free();await process_frame;quit()
