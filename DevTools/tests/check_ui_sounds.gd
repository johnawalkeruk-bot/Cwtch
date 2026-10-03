extends SceneTree
var cues: Array[String]=[]
func _initialize():run.call_deferred()
func run():
 var ui=root.get_node("UISounds")
 ui.cue_played.connect(func(cue: String):cues.append(cue))
 ui.enabled=true;ui.volume=0.35;ui.unlocked=false
 assert(ui.play("success")==null and cues.is_empty(),"Startup and async work must be silent before input")
 var input:=InputEventKey.new();input.keycode=KEY_ENTER;input.pressed=true
 ui._input(input)
 assert(ui.play("success")!=null)
 assert(ui.play("success")==null,"Duplicate same-frame outcomes are suppressed")
 assert(ui.play("loading")==null,"No repeating UI bed over existing music")
 assert(ui.play("not-a-cue")==null)
 ui.stop_all();assert(ui.voices.is_empty())
 cues.clear()
 for i in 9:ui.play("typing")
 assert(cues.size()==9,"Typing has no rate throttle")
 assert(ui.voices.size()<=6,"Voice count stays bounded")
 ui.set_enabled(false);assert(ui.voices.is_empty() and ui.play("select")==null)
 ui.enabled=true;ui.restore();assert(not ui.enabled,"Mute survives a settings reload")
 for pack in ui.PACKS:
  assert(ui.catalog.has(pack+"/purchase"))
  assert(ResourceLoader.exists(ui.BASE+pack+"/purchase.mp3"))
 ui.set_enabled(true);ui.set_pack("zen");ui.set_volume(0.2);ui.set_typing(true)
 ui.pack="organic";ui.typing=false;ui.restore()
 assert(ui.pack=="zen" and ui.typing and is_equal_approx(ui.volume,0.2))
 ui.stop_all();cues.clear()
 var menu=load("res://main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 menu.cloud.persistence_enabled=false
 await process_frame
 assert(cues.is_empty(),"Background construction/refresh does not play UI sounds")
 assert(menu.options.find_child("UISFXPack",true,false).item_count==12)
 menu._save_options(55)
 ui.restore();assert(ui.pack=="zen" and ui.typing,"Master volume saves preserve UI preferences")
 menu.account_panel.show();menu.account_panel.auth_feedback=true
 menu.cloud.auth_finished.emit(false)
 assert(cues.back()=="error")
 cues.clear();menu.account_panel.refresh();assert(cues.is_empty())
 menu.account_panel.auth_feedback=true;menu.account_panel.hide();menu.cloud.auth_finished.emit(true)
 assert(cues.is_empty(),"Hidden panels do not deliver stale completion cues")
 ui.recent.clear();menu.account_panel.show();menu.account_panel.upload_feedback=true
 menu.cloud.sync_finished.emit(true,"Saved")
 assert(cues==["success"])
 cues.clear();menu.cloud.sync_finished.emit(true,"Background refresh");assert(cues.is_empty())
 var line:=LineEdit.new();root.add_child(line);await process_frame
 line.grab_focus();line.text_changed.emit("a");line.text_changed.emit("ab")
 assert(cues==["typing","typing"])
 cues.clear();line.secret=true;line.text_changed.emit("password");assert(cues.is_empty())
 line.queue_free()
 ui.set_pack("organic");ui.set_typing(false);ui.set_volume(0.35)
 menu.account_panel.hide();menu.options.show();menu.menu_buttons.hide();menu.heading.hide()
 menu.options.find_child("UISFXPack",true,false).select(ui.PACKS.find(ui.pack))
 menu.options.find_child("UISFXVolume",true,false).set_value_no_signal(ui.volume*100)
 menu.options.find_child("UISFXTyping",true,false).set_pressed_no_signal(ui.typing)
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.local/ui-sound-options.png"))
 ui.stop_all();menu.queue_free();await create_timer(0.2).timeout
 assert(ui.voices.is_empty())
 print("UI_SOUNDS_PASS: input gate, 12 packs, mute/volume/style persistence, semantic async outcomes, hidden cleanup, no refresh cues, typing without throttle, password silence, voice limit and teardown")
 quit()
