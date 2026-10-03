extends Control
signal tool_selected(index: int)
signal mode_selected(index: int)
signal cancelled
const Petals=preload("res://petal_shapes.gd")
const LABELS=["Hoe","Seed packet","Watering can","Shovel","Put away"]
const MODE_LABELS=["Dig","Pick","Pour","Thump"]
const NOTES=["Turn grass into earth","Scatter a little green","Give the ground a drink","Shape the garden","Stow your tool and wander"]
const MODE_NOTES=["Dig a water-filled hollow","Make a small seed hole","Fill the ground with dirt","Level the whole tile"]
var mode_page:=false
var selected:=0
var hovered:=0
var player_slot:=0
var owner_device:=-1
var center:=Vector2.ZERO
var radius_scale:=1.0
var title: Label
var subtitle: Label
var icons: Array[Texture2D]=[]
var sizes: Array[float]=[1.0,1.0,1.0,1.0,1.0]
var backdrop: ColorRect
var opening_frame:=0

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_STOP
 backdrop=ColorRect.new()
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 backdrop.material=ShaderMaterial.new()
 backdrop.material.shader=preload("res://petal_backdrop.gdshader")
 add_child(backdrop)
 # Canvas child must draw before the parent's petals.
 backdrop.show_behind_parent=true
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for key in ["hoe","seeds","water","shovel"]:icons.append(load("res://assets/tools/%s_icon.png"%key))
 title=_label(21)
 title.add_theme_font_override("font",Petals.serif())
 subtitle=_label(17)
 subtitle.add_theme_color_override("font_color",Petals.PAPER)
 resized.connect(_layout)
 _layout()
 hide()

func _label(font_size: int) -> Label:
 var label:=Label.new()
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Petals.INK)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(label)
 return label

func _layout() -> void:
 center=size*Vector2(0.5,0.56)
 radius_scale=minf(1.0,minf(size.x/600.0,size.y/680.0))
 if is_instance_valid(title):
  title.position=center-Vector2(69,45)*radius_scale
  title.size=Vector2(138,90)*radius_scale
  subtitle.position=center+Vector2(-200,218)*radius_scale
  subtitle.size=Vector2(400,55)*radius_scale
 if is_instance_valid(backdrop):
  var screen:=get_viewport_rect().size
  backdrop.material.set_shader_parameter("region_min",global_position/screen)
  backdrop.material.set_shader_parameter("region_max",(global_position+size)/screen)
 queue_redraw()

func open(current: int) -> void:
 if not visible:UISounds.play("open")
 mode_page=false
 selected=clampi(current,0,4)
 hovered=selected
 opening_frame=Engine.get_process_frames()
 show()
 _layout()
 _refresh()

func open_modes(current: int) -> void:
 mode_page=true
 hovered=clampi(current,0,3)
 selected=hovered
 _refresh()

func _labels() -> Array:
 return MODE_LABELS if mode_page else LABELS

func _refresh() -> void:
 title.text=_labels()[hovered]
 subtitle.text=(MODE_NOTES if mode_page else NOTES)[hovered]
 queue_redraw()

func _choose() -> void:
 UISounds.play("select")
 if mode_page:mode_selected.emit(hovered)
 else:tool_selected.emit(hovered)

func _sector(offset: Vector2) -> int:
 var step:=TAU/_labels().size()
 return int(floor(fposmod(offset.angle()+PI/2+step/2,TAU)/step))

func handle_event(event: InputEvent) -> bool:
 if not visible:return false
 if event is InputEventJoypadButton or event is InputEventJoypadMotion:
  if event.device!=owner_device:return false
  if event is InputEventJoypadButton and event.pressed:
   match event.button_index:
    JOY_BUTTON_A:_choose()
    JOY_BUTTON_B:_cancel()
    JOY_BUTTON_START:
     _cancel()
     return false
    JOY_BUTTON_DPAD_LEFT:hovered=posmod(hovered-1,_labels().size())
    JOY_BUTTON_DPAD_RIGHT:hovered=posmod(hovered+1,_labels().size())
    JOY_BUTTON_DPAD_UP:hovered=0
    JOY_BUTTON_DPAD_DOWN:hovered=2
  _refresh()
  return true
 if player_slot!=0:return false
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_ESCAPE,KEY_TAB]:_cancel()
  elif event.keycode in [KEY_ENTER,KEY_SPACE]:_choose()
  elif event.keycode in [KEY_LEFT,KEY_RIGHT]:hovered=posmod(hovered+(-1 if event.keycode==KEY_LEFT else 1),_labels().size())
  _refresh()
  return true
 return false

func _input(event: InputEvent) -> void:
 if handle_event(event):get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
 if player_slot!=0:return
 if event is InputEventMouseMotion:
  var offset: Vector2=event.position-center
  if offset.length()>78*radius_scale and offset.length()<225*radius_scale:hovered=_sector(offset)
  _refresh()
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_LEFT and (event.position-center).length()<230*radius_scale:_choose()
  elif event.button_index==MOUSE_BUTTON_RIGHT:_cancel()
  accept_event()

func _process(delta: float) -> void:
 if not visible:return
 var stick:=ControllerInput.movement(owner_device)
 if stick.length()>0.4:hovered=_sector(stick)
 for i in sizes.size():sizes[i]=lerpf(sizes[i],1.1 if i==hovered else 0.96,1.0-exp(-14.0*delta))
 _refresh()

func _draw() -> void:
 var labels:=_labels()
 for i in labels.size():
  var angle: float=-PI/2+i*TAU/labels.size()
  var axis:=Vector2.from_angle(angle)
  var base:=center+axis*76*radius_scale
  var color:=Petals.GOLD if i==hovered else Petals.EARTH
  Petals.petal(self,base,angle,133*radius_scale*sizes[i],125*radius_scale*sizes[i],color,i==hovered)
  var at:=center+axis*141*radius_scale
  var icon_index:=3 if mode_page else i
  if icon_index<icons.size():
   var extent:=Vector2.ONE*70*radius_scale*sizes[i]
   draw_texture_rect(icons[icon_index],Rect2(at-extent*0.5,extent),false)
  else:
   draw_circle(at,16*radius_scale,Petals.PAPER)
   draw_line(at-Vector2(9,0)*radius_scale,at+Vector2(9,0)*radius_scale,Petals.INK,3,true)
  if mode_page:
   var font:=get_theme_default_font()
   var width:=font.get_string_size(labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
   draw_string(font,at+Vector2(-width/2,47),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Petals.INK)
 draw_circle(center,79*radius_scale,Petals.INK)
 draw_circle(center,75*radius_scale,Petals.PAPER)
 draw_arc(center,69*radius_scale,0,TAU,64,Color("c5b286"),1.0,true)

func attach_clock(world: Node3D, slot: int) -> void:
 var clock:=preload("res://petal_clock.gd").new()
 add_child(clock)
 clock.setup(world,slot)

func _cancel() -> void:
 UISounds.play("cancel")
 cancelled.emit()
