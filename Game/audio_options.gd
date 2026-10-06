extends CanvasLayer
## Shared modal sound page. Its caller remains paused behind the overlay.
var opened:=false
var screen: Control
var panel: PanelContainer
var mixer: VBoxContainer
var previous_focus: WeakRef
func _ready() -> void:
 layer=120
 screen=Control.new();add_child(screen);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade:=ColorRect.new();screen.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.color=Color(0.025,0.055,0.05,0.8)
 panel=PanelContainer.new();screen.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-270;panel.offset_right=270;panel.offset_top=-205;panel.offset_bottom=205
 panel.theme=preload("res://cwtch_theme.gd").make()
 mixer=VBoxContainer.new();mixer.add_theme_constant_override("separation",12);panel.add_child(mixer)
 var title:=Label.new();title.text="SOUND OPTIONS";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",24);title.add_theme_color_override("font_color",Color("e5c17c"));mixer.add_child(title)
 preload("res://audio_mixer.gd").populate(mixer)
 var back:=Button.new();back.text="BACK";back.pressed.connect(close);mixer.add_child(back)
 screen.hide()
 ControllerInput.mode_changed.connect(func():if opened:focus())
func open() -> void:
 if opened:return
 var control:=get_viewport().gui_get_focus_owner()
 previous_focus=weakref(control) if control else null
 preload("res://audio_mixer.gd").refresh(mixer)
 opened=true;screen.show();focus();UISounds.play("open")
func focus() -> void:
 panel.find_child("Volume",true,false).grab_focus.call_deferred()
func close() -> void:
 if not opened:return
 opened=false;screen.hide();UISounds.play("back")
 var control=previous_focus.get_ref() if previous_focus else null
 if is_instance_valid(control) and control.is_visible_in_tree():control.grab_focus()
func _input(event: InputEvent) -> void:
 if opened and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide")):
  close();get_viewport().set_input_as_handled()
