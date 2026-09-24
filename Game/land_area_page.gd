extends Control
## One map pixel-block per micro-tile, measured from the editable garden only.
const COLORS := [Color("876343"),Color("b29a76"),Color("72914b"),Color("365d39"),Color("68a5ad"),Color("365574"),Color("cdb891"),Color("85858b")]
const INK := Color("483322")
const MAP := Rect2(40,15,330,330)
var garden: Node3D
var font: Font
var counts: Array[int]=[]
var percentages: Array[float]=[]
var tile_types: Array[int]=[]
var selected := Vector2i.ZERO
var dirty := true

func setup(world: Node3D, handwriting: Font) -> void:
 if garden!=world:
  if is_instance_valid(garden) and garden.terrain_changed.is_connected(_changed):garden.terrain_changed.disconnect(_changed)
  garden=world
  garden.terrain_changed.connect(_changed)
 font=handwriting
 position=Vector2(80,138)
 size=Vector2(920,374)
 mouse_filter=Control.MOUSE_FILTER_PASS
 selected=selected.clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 refresh()

func _changed(_cell: Vector2i, _kind: int) -> void:
 dirty=true

func refresh() -> void:
 counts.assign([0,0,0,0,0,0,0,0])
 tile_types.clear()
 var total: int=garden.grid_size.x*garden.grid_size.y
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   var kind: int=garden.get_terrain(Vector2i(x,z))
   tile_types.append(kind)
   counts[kind]+=1
 percentages.clear()
 for count in counts:percentages.append(100.0*float(count)/float(total))
 dirty=false
 queue_redraw()

func _process(_delta: float) -> void:
 if is_visible_in_tree() and dirty:refresh()

func move_selection(offset: Vector2i) -> void:
 selected=(selected+offset).clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 queue_redraw()

func turn(direction: int) -> void:
 var index: int=posmod(selected.y*garden.grid_size.x+selected.x+direction,tile_types.size())
 selected=Vector2i(index%garden.grid_size.x,index/garden.grid_size.x)
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion or event is InputEventMouseButton and event.pressed:
  var point: Vector2=event.position
  if MAP.has_point(point):
   selected=Vector2i((point-MAP.position)/MAP.size*Vector2(garden.grid_size)).clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
   queue_redraw()
   accept_event()

func _draw() -> void:
 if not is_instance_valid(garden) or tile_types.is_empty():return
 var cell_size:=MAP.size/Vector2(garden.grid_size)
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   draw_rect(Rect2(MAP.position+Vector2(x,z)*cell_size,cell_size),COLORS[tile_types[z*garden.grid_size.x+x]])
 for x in range(garden.grid_size.x+1):
  var px:=MAP.position.x+x*cell_size.x
  draw_line(Vector2(px,MAP.position.y),Vector2(px,MAP.end.y),Color(0.24,0.17,0.1,0.22))
 for z in range(garden.grid_size.y+1):
  var pz:=MAP.position.y+z*cell_size.y
  draw_line(Vector2(MAP.position.x,pz),Vector2(MAP.end.x,pz),Color(0.24,0.17,0.1,0.22))
 draw_rect(MAP,INK,false,2)
 var chosen:=Rect2(MAP.position+Vector2(selected)*cell_size,cell_size)
 draw_rect(chosen,Color("fff1c9"),false,3)
 draw_rect(chosen.grow(1),INK,false,1)
 _text(Vector2(173,9),"↑ NORTH",13)
 var kind: int=tile_types[selected.y*garden.grid_size.x+selected.x]
 _text(Vector2(30,366),"Tile %d, %d  ·  %s"%[selected.x+1,selected.y+1,garden.TERRAIN_NAMES[kind]],16)
 _text(Vector2(500,96),"%.0f m × %.0f m   ·   %d tiles"%[garden.chunk_count.x*garden.CHUNK_SIZE,garden.chunk_count.y*garden.CHUNK_SIZE,tile_types.size()],17)
 for i in counts.size():
  var y:=128.0+i*28.0
  draw_rect(Rect2(500,y-13,14,14),COLORS[i])
  draw_rect(Rect2(500,y-13,14,14),INK,false,1)
  _text(Vector2(524,y),garden.TERRAIN_NAMES[i],17)
  _text(Vector2(706,y),str(counts[i]),16)
  _text(Vector2(820,y),"%.2f%%"%percentages[i],16)
 _text(Vector2(500,366),"Garden ground only. Each square is one tile.",14)

func _text(at: Vector2, value: String, font_size: int) -> void:
 draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,INK)
