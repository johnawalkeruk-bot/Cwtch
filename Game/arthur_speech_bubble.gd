extends PanelContainer
## Alternating daffodils follow the bubble perimeter, leaving its text unobstructed.
const FLOWERS = [preload("res://assets/ui/Border-1.png"),preload("res://assets/ui/Border-2.png")]
func _ready() -> void:
 resized.connect(queue_redraw)
func _draw() -> void:
 var fill:=Color("f4ead2")
 var edge:=Color("b69755")
 var points:=PackedVector2Array([Vector2(2,42),Vector2(-23,63),Vector2(2,69)])
 draw_colored_polygon(points,fill)
 draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),edge,2.0,true)

 var perimeter := 2.0*(size.x+size.y)
 var count := maxi(4,int(ceil(perimeter/29.0)))
 if count%2!=0:count+=1
 for i in count:
  var distance := float(i)*perimeter/count
  var at: Vector2
  var turn: float
  if distance<size.x:
   at=Vector2(distance,0);turn=0
  elif distance<size.x+size.y:
   at=Vector2(size.x,distance-size.x);turn=PI/2
  elif distance<2*size.x+size.y:
   at=Vector2(2*size.x+size.y-distance,size.y);turn=PI
  else:
   at=Vector2(0,perimeter-distance);turn=3*PI/2
  turn+=deg_to_rad(-17.0 if i%2==0 else 21.0)
  draw_set_transform(at,turn,Vector2.ONE)
  draw_texture_rect(FLOWERS[i%2],Rect2(-Vector2.ONE*17,Vector2.ONE*34),false)
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
