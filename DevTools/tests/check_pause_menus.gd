extends SceneTree
func _initialize():
 create_timer(90).timeout.connect(func():push_error("MENU TEST TIMEOUT");quit(1))
 run.call_deferred()
func shot(name):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/"+name+".png"))
func caps(node):
 for button in node.find_children("*","Button",true,false):assert(button.text==button.text.to_upper(),button.text)
func run():
 var menu=load("res://main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 caps(menu.menu_buttons);caps(menu.options);caps(menu.account_panel)
 var pack=menu.options.find_child("UISFXPack",true,false)
 for index in pack.item_count:assert(pack.get_item_text(index)==pack.get_item_text(index).to_upper())
 await menu._begin_garden(true)
 var garden=menu.garden
 garden.northern_arrival.finish();garden.hedgehog_intro.welcome_pending=false
 if garden.hedgehog_intro.active:garden.hedgehog_intro._finish()
 garden._set_guide(true);caps(garden.guide)
 await shot("uppercase-garden-pause")
 var audio=root.get_node("AudioOptions")
 var sound: Button
 for button in garden.guide.find_children("*","Button",true,false):
  if button.text=="SOUND OPTIONS":sound=button
 assert(sound!=null);sound.grab_focus();sound.pressed.emit()
 assert(audio.opened and garden.guide.visible and not garden.aiming)
 audio.panel.find_child("SpeechVolume",true,false).value=38
 assert(is_equal_approx(root.get_node("AudioSettings").levels.Speech,0.38))
 await shot("pause-sound-options")
 var event: InputEvent=InputEventAction.new();event.action="ui_cancel";event.pressed=true
 Input.parse_input_event(event);await process_frame
 assert(not audio.opened and garden.guide.visible,"Back closes audio, leaving garden paused")
 assert(sound.has_focus(),"Return focus to sound button")
 menu.open_village();await process_frame
 menu.village._pause(true);caps(menu.village.pause_panel)
 audio.open();assert(menu.village.paused and audio.opened)
 assert(audio.panel.find_child("SpeechVolume",true,false).value==38)
 event=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=true
 Input.parse_input_event(event);await process_frame
 assert(not audio.opened and menu.village.paused,"B closes audio without unpausing the village")
 menu.return_from_village(false);menu.open_menu()
 load("res://audio_mixer.gd").refresh(menu.options)
 assert(menu.options.find_child("SpeechVolume",true,false).value==38,"Start menu reflects pause changes")
 menu.queue_free();await create_timer(0.5).timeout
 print("PAUSE_MENUS_PASS: uppercase menus, shared volume settings, garden/village pause preserved, cancel/B and focus restoration")
 quit()
