extends CanvasLayer
var host: Node
var badge: Label
var toast: Label
var age:=0.0
func setup(owner_node: Node) -> void:
 host=owner_node
 layer=180
 var root:=Control.new();add_child(root)
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
 host.cloud.changed.connect(refresh)
 refresh()
func refresh() -> void:
 var account: Node=host.cloud
 var name:=str(account.profile.get("username",account.email))
 badge.text="Signed in · "+name if not account.token.is_empty() else "Offline · not signed in"
func show_toast(message: String) -> void:
 toast.text=message;age=5.0;toast.show()
func _process(delta: float) -> void:
 age=maxf(0,age-delta);toast.visible=age>0
 var paused:=false
 if is_instance_valid(host.village):paused=host.village.paused
 elif is_instance_valid(host.garden) and host.garden.loading_complete:
  paused=host.garden.guide.visible or host.garden.hedgehog_intro.paused
 badge.visible=not host.loading and (host.menu_active or paused)
