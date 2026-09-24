extends CanvasLayer
## FIFO notices ensure an arrival and residency on the same frame are both seen.
const DURATION := 6.0
const TITLES := {"visit":"New visitor", "resident":"New resident", "birth":"A new arrival", "death":"A life remembered"}
var garden: Node3D
var queue: Array[Dictionary]=[]
var current: Dictionary={}
var elapsed := 0.0
var panel: PanelContainer
var heading: Label
var detail: Label
var date_label: Label

func setup(world: Node3D) -> void:
 garden=world
 layer=8
 panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.offset_left=28
 panel.offset_right=408
 panel.offset_top=-160
 panel.offset_bottom=-28
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_theme_stylebox_override("panel",garden._panel_style(Color("233b32")))
 var stack:=VBoxContainer.new()
 stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
 stack.add_theme_constant_override("separation",5)
 panel.add_child(stack)
 heading=garden._label("",19,Color("ebce8b"))
 detail=garden._label("",16,Color("f0eadb"))
 detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 date_label=garden._label("",13,Color("afc5b4"))
 for label in [heading,detail,date_label]:
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  stack.add_child(label)
 panel.hide()
 garden.wildlife.animal_event.connect(enqueue)

func enqueue(kind: String, species: String, event_day: int) -> void:
 if not TITLES.has(kind):return
 queue.append({"kind":kind,"species":species,"day":event_day})

func _process(delta: float) -> void:
 if garden.guide.visible:
  panel.hide()
  return
 if current.is_empty():
  if queue.is_empty():
   panel.hide()
   return
  current=queue.pop_front()
  elapsed=0.0
  heading.text=TITLES[current.kind]
  var animal: String=str(current.species).capitalize()
  match current.kind:
   "visit":detail.text=animal+" visited your garden."
   "resident":detail.text=animal+" became a resident."
   "birth":detail.text="A "+animal.to_lower()+" was born."
   "death":detail.text=animal+" has died."
  date_label.text="Day %d"%int(current.day)
 panel.show()
 elapsed+=delta
 panel.modulate.a=minf(smoothstep(0.0,0.3,elapsed),1.0-smoothstep(DURATION-0.5,DURATION,elapsed))
 panel.offset_left=28.0-12.0*(1.0-smoothstep(0.0,0.3,elapsed))
 panel.offset_right=panel.offset_left+380.0
 if elapsed>=DURATION:
  current={}
  panel.hide()
