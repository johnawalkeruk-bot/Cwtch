extends SceneTree
func _initialize():run.call_deferred()
func shot(name):
 if DisplayServer.get_name()=='headless':return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://../.local/'+name+'.png'))
func run():
 var menu=load('res://main_menu.tscn').instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 menu._open_account()
 var panel=menu.account_panel
 assert(panel.login_box.visible and not panel.register_box.visible)
 panel.password.text='not-a-real-password';panel.set_registration(true)
 assert(not panel.login_box.visible and panel.register_box.visible and panel.password.text.is_empty())
 await shot('game-registration-form')
 panel.set_registration(false);await shot('game-signin-form')
 menu.cloud.token='fixture-access';menu.cloud.email='fixture@example.invalid';menu.cloud.profile={'username':'ValleyGardener'};menu.cloud.expires=Time.get_unix_time_from_system()+3600;menu.cloud.connected=true
 menu.cloud.changed.emit();menu.account_status._process(0)
 var overlay=menu.account_status
 assert(overlay.popup.visible and overlay.greeting.text.contains('Hello ValleyGardener'))
 assert(overlay.continue_button.has_focus())
 await shot('game-welcome-save')
 overlay.popup.hide();overlay._process(0)
 assert(not overlay.popup.visible,'No repeated welcome during the same sign-in')
 overlay.begin_save();overlay._process(0.2)
 var initial=overlay.save_icon.rotation;overlay._process(0.2)
 assert(overlay.save_icon.visible and overlay.save_icon.rotation>initial)
 overlay.end_save();menu.cloud.syncing=true;overlay._process(1)
 assert(overlay.save_icon.visible,'Indicator stays on while cloud sync is active')
 menu.cloud.syncing=false;overlay._process(1);assert(overlay.save_icon.visible)
 overlay._process(3.1);assert(not overlay.save_icon.visible)
 menu.cloud.connected=false
 overlay.show_welcome('ValleyGardener')
 var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.pressed=true
 Input.parse_input_event(event)
 await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
 await create_timer(0.1).timeout
 assert(not overlay.popup.visible and menu.loading,'A enters the garden')
 while menu.loading:await process_frame
 menu.cloud.token='';menu.cloud.profile={};menu.cloud.changed.emit()
 assert(overlay.shown_for.is_empty(),'Signout resets welcome for next sign-in')
 print('WELCOME_SAVE_PASS: separate forms, username popup, controller accept, single welcome, rotation and cloud indicator lifetime')
 menu.queue_free();await create_timer(0.2).timeout;quit()
