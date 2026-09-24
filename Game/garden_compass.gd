extends Control
## World north is -Z. Heading follows the camera, independently of movement.
var camera: Camera3D
var heading := 0.0
const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

func setup(view: Camera3D) -> void:
 camera=view
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 offset_left=-150
 offset_right=150
 offset_top=22
 offset_bottom=82

func bearing() -> float:
 var forward: Vector3=-camera.global_basis.z
 return fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)

func _process(_delta: float) -> void:
 if is_instance_valid(camera):
  heading=bearing()
  queue_redraw()

func _draw() -> void:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color(0.10,0.17,0.15,0.88)
 style.set_corner_radius_all(12)
 draw_style_box(style,Rect2(Vector2.ZERO,size))
 var font:=ThemeDB.fallback_font
 var gold:=Color("ebce8b")
 for i in range(-8,9):
  var degree: float=floor(heading/15.0)*15.0+i*15.0
  var x:=size.x*0.5+(degree-heading)*2.0
  if x<15 or x>size.x-15:continue
  draw_line(Vector2(x,34),Vector2(x,39),Color("91a99b"),1)
  if posmod(int(degree),45)==0:
   var label: String=DIRECTIONS[posmod(int(degree)/45,8)]
   draw_string(font,Vector2(x-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x/2,26),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,gold)
 draw_colored_polygon(PackedVector2Array([Vector2(146,3),Vector2(154,3),Vector2(150,9)]),gold)
 var text: String="%03d°"%posmod(roundi(heading),360)
 draw_string(font,Vector2(150-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,54),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,gold)
