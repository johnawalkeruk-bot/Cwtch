extends SceneTree
func _initialize():run.call_deferred()
func run():
 var menu=load('res://main_menu.tscn').instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 assert(menu.account_status.badge.text.contains('Offline'))
 await menu._begin_garden(true)
 menu.garden.northern_arrival.finish()
 if menu.garden.hedgehog_intro.active:menu.garden.hedgehog_intro._finish()
 menu.garden.hedgehog_intro.welcome_pending=false
 menu.set_process(false)
 menu.autosave_age=0
 menu._process(299)
 assert(not menu.account_status.toast.visible,'No autosave before five minutes')
 menu._process(1)
 assert(menu.autosave_age==0 and FileAccess.file_exists(menu.SAVE_PATH))
 assert(menu.account_status.toast.text.contains('offline'),'Offline saves must not claim cloud success')
 menu.cloud.email='fixture@example.invalid';menu.cloud.token='fixture';menu.cloud.profile={'username':'ValleyGardener'};menu.cloud.changed.emit()
 menu.garden._set_guide(true);menu.account_status._process(0)
 assert(menu.account_status.badge.visible and menu.account_status.badge.text.contains('ValleyGardener'))
 menu.autosave_sync_pending=true;menu.cloud.sync_finished.emit(true,'Garden saved · synced to cloud')
 assert(menu.account_status.toast.text.contains('synced to cloud'))
 menu.open_village();await process_frame
 menu.village._pause(true);menu.account_status._process(0)
 assert(menu.account_status.badge.visible,'Village pause shows the signed-in badge')
 menu.autosave_sync_pending=true;menu.cloud.sync_finished.emit(false,'Saved locally · cloud sync needs attention')
 assert(menu.account_status.toast.text.contains('needs attention'))
 if DisplayServer.get_name()!='headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://../.local/account-badge-toast.png'))
 menu.cloud.token='';menu.cloud.profile={};menu.cloud.email='';menu.cloud.changed.emit()
 assert(menu.account_status.badge.text.contains('Offline'))
 menu.queue_free();await process_frame
 print('AUTOSAVE_PASS: five-minute timing, local write, offline/success/failure toast, account identity and garden/village pause badges');quit()
