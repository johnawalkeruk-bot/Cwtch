extends CanvasLayer
## Controller text entry. Drafts stay local until Done; Cancel never changes a field.
var shade: ColorRect
var panel: PanelContainer
var draft: LineEdit
var heading: Label
var source: LineEdit
var suppressed: LineEdit
var keys: Array[Button]=[]
var shift := false
var symbols := false
var opened := false
var selected := 0
var axis := Vector2.ZERO
var repeat_age := 0.0
const LETTERS := "abcdefghijklmnopqrstuvwxyz0123456789@._-"
const SYMBOLS := "!@#$%^&*()_+-=[]{};:'\"/?,.<>\\|`~ "

func _ready() -> void:
 layer=250
 shade=ColorRect.new()
 add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.color=Color(0.025,0.07,0.055,0.88)
 panel=PanelContainer.new()
 shade.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-470;panel.offset_right=470;panel.offset_top=-240;panel.offset_bottom=240
 panel.theme=preload("res://cwtch_theme.gd").make()
 panel.add_theme_stylebox_override("panel",preload("res://cwtch_theme.gd").panel(Color("182e28")))
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",12)
 panel.add_child(box)
 heading=Label.new();heading.add_theme_font_size_override("font_size",24);box.add_child(heading)
 draft=LineEdit.new();draft.editable=false;draft.focus_mode=Control.FOCUS_NONE;draft.custom_minimum_size.y=44;box.add_child(draft)
 var grid:=GridContainer.new();grid.columns=10;grid.add_theme_constant_override("h_separation",7);grid.add_theme_constant_override("v_separation",7);box.add_child(grid)
 for i in 40:
  var key:=Button.new();key.custom_minimum_size=Vector2(82,43);grid.add_child(key);keys.append(key)
  key.pressed.connect(func():write_character(i))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);box.add_child(row)
 for label in ["SHIFT","SYMBOLS","SPACE","DELETE","CANCEL","DONE"]:
  var key:=Button.new();key.text=label;key.size_flags_horizontal=Control.SIZE_EXPAND_FILL;key.custom_minimum_size.y=44;row.add_child(key);keys.append(key)
  key.pressed.connect(func():action(label))
 for i in keys.size():keys[i].focus_entered.connect(func():selected=i)
 shade.hide()

func _process(delta: float) -> void:
 if opened:
  if not is_instance_valid(source) or not source.is_visible_in_tree():finish(false);return
  if axis.length()>0.5:
   repeat_age-=delta
   if repeat_age<=0:move_focus(Vector2i(signi(int(axis.x)),signi(int(axis.y))));repeat_age=0.14
  return
 var focus:=get_tree().root.gui_get_focus_owner()
 if focus!=suppressed:suppressed=null
 if focus is LineEdit and focus.editable and focus.is_visible_in_tree() and focus!=suppressed and ControllerInput.using_pad:
  open_for(focus)

func open_for(field: LineEdit) -> void:
 source=field
 draft.text=field.text
 draft.secret=field.secret
 draft.max_length=field.max_length
 heading.text=field.placeholder_text if not field.placeholder_text.is_empty() else "ENTER TEXT"
 shift=false;symbols=false;axis=Vector2.ZERO
 opened=true
 shade.show()
 refresh_keys()
 selected=0
 keys[0].grab_focus()

func refresh_keys() -> void:
 var chars:=SYMBOLS if symbols else LETTERS
 if shift:chars=chars.to_upper()
 for i in 40:
  keys[i].text=chars[i] if i<chars.length() else ""
  keys[i].disabled=i>=chars.length()
 keys[40].text="SHIFT ON" if shift else "SHIFT"
 keys[41].text="LETTERS" if symbols else "SYMBOLS"

func write_character(index: int) -> void:
 var chars:=SYMBOLS if symbols else LETTERS
 if shift:chars=chars.to_upper()
 if index<chars.length():append_text(chars[index])

func append_text(value: String) -> void:
 if draft.max_length>0 and draft.text.length()+value.length()>draft.max_length:return
 draft.text+=value
 if UISounds.typing and not draft.secret:UISounds.play("typing")
 draft.caret_column=draft.text.length()

func action(label: String) -> void:
 match label:
  "SHIFT":shift=not shift;refresh_keys()
  "SYMBOLS":symbols=not symbols;refresh_keys()
  "SPACE":append_text(" ")
  "DELETE":
   if not draft.text.is_empty() and UISounds.typing and not draft.secret:UISounds.play("typing")
   draft.text=draft.text.left(maxi(0,draft.text.length()-1))
  "CANCEL":finish(false)
  "DONE":finish(true)

func finish(accept: bool) -> void:
 var field:=source
 opened=false
 shade.hide()
 if is_instance_valid(field):
  if accept:
   field.text=draft.text
   field.caret_column=field.text.length()
   field.text_changed.emit(field.text)
  suppressed=field
  if field.is_visible_in_tree():field.grab_focus()
 draft.clear()
 source=null
 axis=Vector2.ZERO

func move_focus(direction: Vector2i) -> void:
 var row:=selected/10 if selected<40 else 4
 var column:=selected%10 if selected<40 else selected-40
 if direction.y!=0:
  row=posmod(row+direction.y,5)
  column=mini(column,5 if row==4 else 9)
 else:column=posmod(column+direction.x,6 if row==4 else 10)
 selected=row*10+column if row<4 else 40+column
 if keys[selected].disabled:
  selected=40+mini(column,5)
 keys[selected].grab_focus()

func _input(event: InputEvent) -> void:
 if not opened:
  if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:
   var field:=get_tree().root.gui_get_focus_owner()
   if field is LineEdit and field.editable:
    open_for(field);get_viewport().set_input_as_handled()
  return
 if event is InputEventJoypadMotion:
  if event.axis==JOY_AXIS_LEFT_X:axis.x=signf(event.axis_value) if absf(event.axis_value)>0.55 else 0
  if event.axis==JOY_AXIS_LEFT_Y:axis.y=signf(event.axis_value) if absf(event.axis_value)>0.55 else 0
  if absf(axis.x)>0:axis.y=0
  if axis==Vector2.ZERO:repeat_age=0
  get_viewport().set_input_as_handled()
 elif event is InputEventJoypadButton:
  if event.pressed:
   match event.button_index:
    JOY_BUTTON_A:keys[selected].pressed.emit()
    JOY_BUTTON_B:finish(false)
    JOY_BUTTON_X:action("DELETE")
    JOY_BUTTON_Y:action("SHIFT")
    JOY_BUTTON_START:finish(true)
    JOY_BUTTON_DPAD_LEFT:move_focus(Vector2i.LEFT)
    JOY_BUTTON_DPAD_RIGHT:move_focus(Vector2i.RIGHT)
    JOY_BUTTON_DPAD_UP:move_focus(Vector2i.UP)
    JOY_BUTTON_DPAD_DOWN:move_focus(Vector2i.DOWN)
  get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed:
  match event.keycode:
   KEY_ESCAPE:finish(false)
   KEY_ENTER,KEY_KP_ENTER:finish(true)
   KEY_BACKSPACE:action("DELETE")
   KEY_LEFT:move_focus(Vector2i.LEFT)
   KEY_RIGHT:move_focus(Vector2i.RIGHT)
   KEY_UP:move_focus(Vector2i.UP)
   KEY_DOWN:move_focus(Vector2i.DOWN)
   _:
    if event.unicode>=32:append_text(String.chr(event.unicode))
  get_viewport().set_input_as_handled()
