extends CanvasLayer
var host: Node
var badge: Label
var toast: Label
var age:=0.0
var save_icon: TextureRect
var local_saving:=false
var save_tail:=0.0
var was_syncing:=false
var popup: ColorRect
var greeting: Label
var invitation: RichTextLabel
var prompt_icon: Texture2D
var cloud_note: Label
var continue_button: Button
var shown_for:=""
const SAVE_ICON=preload("res://assets/ui/save.png")
func setup(owner_node: Node) -> void:
 host=owner_node
 layer=180
 var root:=Control.new();root.theme=preload("res://cwtch_theme.gd").make();add_child(root)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 badge=Label.new();root.add_child(badge)
 badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 badge.offset_left=-400;badge.offset_right=-24;badge.offset_top=20;badge.offset_bottom=64
 badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 badge.add_theme_color_override("font_color",Color("f0d69a"))
 badge.add_theme_color_override("font_shadow_color",Color("10251f"))
 badge.add_theme_constant_override("shadow_offset_y",2)
 badge.add_theme_font_size_override("font_size",18)
 toast=Label.new();root.add_child(toast)
 toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 toast.offset_left=-350;toast.offset_right=350;toast.offset_top=-86;toast.offset_bottom=-38
 toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 toast.add_theme_color_override("font_color",Color("f5ebd3"))
 toast.add_theme_stylebox_override("normal",preload("res://cwtch_theme.gd").compact_card())
 toast.hide()
 save_icon=TextureRect.new();root.add_child(save_icon)
 save_icon.texture=SAVE_ICON;save_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;save_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 save_icon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 save_icon.offset_left=-96;save_icon.offset_right=-32;save_icon.offset_top=-100;save_icon.offset_bottom=-36
 save_icon.pivot_offset=Vector2(32,32);save_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;save_icon.hide()
 _build_welcome(root)
 host.cloud.changed.connect(refresh)
 refresh()
func refresh() -> void:
 var account: Node=host.cloud
 var name:=str(account.profile.get("username",account.email))
 badge.text="Signed in · "+name if not account.token.is_empty() else "Offline · not signed in"
 if account.token.is_empty():shown_for="";popup.hide()
func show_toast(message: String) -> void:
 toast.text=message;age=5.0;toast.show()
func _process(delta: float) -> void:
 age=maxf(0,age-delta);toast.visible=age>0
 if host.cloud.syncing and not was_syncing:save_tail=maxf(save_tail,4.0)
 was_syncing=host.cloud.syncing
 save_tail=maxf(0,save_tail-delta)
 save_icon.visible=local_saving or host.cloud.syncing or save_tail>0
 if save_icon.visible:save_icon.rotation=fposmod(save_icon.rotation+delta*0.55,TAU)
 var account: Node=host.cloud
 var username:=str(account.profile.get("username",""))
 if host.menu_active and not host.loading and not account.busy and not account.token.is_empty() and account.expires>Time.get_unix_time_from_system() and not username.is_empty() and shown_for!=account.email:
  shown_for=account.email
  show_welcome(username)
 if popup.visible:
  var icon:=preload("res://controller_icons.gd").texture("accept",ControllerInput.primary_device())
  continue_button.icon=icon
  if icon!=prompt_icon:
   prompt_icon=icon
   invitation.text="Grab your tools and press [img=28x28]%s[/img] whenever you're ready to head outside."%icon.resource_path
 var paused:=false
 if is_instance_valid(host.village):paused=host.village.paused
 elif is_instance_valid(host.garden) and host.garden.loading_complete:
  paused=host.garden.guide.visible or host.garden.hedgehog_intro.paused
 badge.visible=not host.loading and not popup.visible and (host.menu_active or paused)

func begin_save() -> void:
 local_saving=true;save_tail=maxf(save_tail,4.0)
func end_save() -> void:
 local_saving=false
func _build_welcome(root: Control) -> void:
 popup=ColorRect.new();root.add_child(popup)
 popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);popup.color=Color(0.015,0.035,0.03,0.8);popup.hide()
 var panel:=PanelContainer.new();popup.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-340;panel.offset_right=340;panel.offset_top=-220;panel.offset_bottom=220
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",20);panel.add_child(box)
 greeting=Label.new();greeting.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;greeting.add_theme_font_size_override("font_size",24);greeting.add_theme_color_override("font_color",Color("e5c17c"));box.add_child(greeting)
 var note:=RichTextLabel.new();note.bbcode_enabled=true;note.fit_content=true;note.scroll_active=false
 note.text="[b]Note:[/b] [b]Cwtch[/b] autosaves your progress and syncs it to the cloud automatically. Do not close the game while [img=42x42]res://assets/ui/save.png[/img] is on screen."
 box.add_child(note)
 invitation=RichTextLabel.new();invitation.bbcode_enabled=true;invitation.fit_content=true;invitation.scroll_active=false;box.add_child(invitation)
 cloud_note=Label.new();cloud_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cloud_note.add_theme_font_size_override("font_size",14);box.add_child(cloud_note)
 continue_button=Button.new();continue_button.text="HEAD OUTSIDE · ENTER";continue_button.expand_icon=true;continue_button.add_theme_constant_override("icon_max_width",32);continue_button.custom_minimum_size.y=48;box.add_child(continue_button)
 continue_button.pressed.connect(head_outside)
 var back:=Button.new();back.text="STAY AT THE MENU";box.add_child(back);back.pressed.connect(func(): popup.hide();host._focus_menu())
func show_welcome(username: String) -> void:
 if ControllerKeyboard.opened:ControllerKeyboard.finish(false)
 greeting.text="Hello %s, welcome back—you're all signed in and ready to get to work."%username
 cloud_note.text="" if host.cloud.connected else "Cloud sync needs a garden choice in Account & Cloud. Your progress will still save locally."
 popup.show();continue_button.grab_focus()
func head_outside() -> void:
 popup.hide();host.account_panel.hide()
 host._begin_garden(not FileAccess.file_exists(host.SAVE_PATH))
func _input(event: InputEvent) -> void:
 if not is_instance_valid(popup) or not popup.visible:return
 if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A):
  var focused:=get_viewport().gui_get_focus_owner()
  if focused is Button and popup.is_ancestor_of(focused) and focused!=continue_button:focused.pressed.emit()
  else:head_outside()
  get_viewport().set_input_as_handled()
 elif event.is_action_pressed("ui_cancel"):
  popup.hide();host._focus_menu();get_viewport().set_input_as_handled()
