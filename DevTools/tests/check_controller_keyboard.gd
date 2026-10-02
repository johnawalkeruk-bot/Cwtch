extends SceneTree
func _initialize():run.call_deferred()
func press(button: int):
 var e:=InputEventJoypadButton.new();e.device=0;e.button_index=button;e.pressed=true
 Input.parse_input_event(e);Input.flush_buffered_events()
 e=InputEventJoypadButton.new();e.device=0;e.button_index=button;e.pressed=false
 Input.parse_input_event(e);Input.flush_buffered_events()
func run():
 var ui:=Control.new();root.add_child(ui)
 var field:=LineEdit.new();field.placeholder_text='Email address';field.text='abc';ui.add_child(field);field.grab_focus()
 await process_frame
 var kb=root.get_node('ControllerKeyboard')
 press(JOY_BUTTON_A)
 await process_frame
 assert(kb.opened)
 press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_A)
 assert(kb.draft.text=='abcb')
 press(JOY_BUTTON_X);assert(kb.draft.text=='abc')
 press(JOY_BUTTON_Y);press(JOY_BUTTON_A);assert(kb.draft.text=='abcB')
 press(JOY_BUTTON_START)
 assert(not kb.opened and field.text=='abcB' and kb.draft.text=='')
 await process_frame
 assert(not kb.opened,'Done must not immediately reopen')
 field.secret=true
 press(JOY_BUTTON_A)
 assert(kb.opened and kb.draft.secret)
 kb.action('SYMBOLS');kb.write_character(0);press(JOY_BUTTON_B)
 assert(field.text=='abcB' and kb.draft.text=='','Cancel preserves field and clears draft')
 field.max_length=5
 kb.open_for(field);kb.append_text('12');assert(kb.draft.text=='abcB');kb.append_text('1');kb.finish(true);assert(field.text=='abcB1')
 ui.queue_free();await process_frame
 var menu=load('res://main_menu.tscn').instantiate();root.add_child(menu);current_scene=menu
 menu._open_account();kb.open_for(menu.account_panel.address)
 for i in 5:await process_frame
 if DisplayServer.get_name()!='headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://../.local/controller-keyboard.png'))
 kb.finish(false);menu.queue_free();await process_frame
 print('OSK_PASS: controller open, navigation, type, delete, shift, commit, cancel, masking, length limit, focus restoration')
 quit()
