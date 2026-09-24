extends PanelContainer
## Parchment speech bubble; the tail points back toward Arthur's portrait.
func _draw() -> void:
 var fill:=Color("f4ead2")
 var edge:=Color("b69755")
 var points:=PackedVector2Array([Vector2(2,42),Vector2(-23,63),Vector2(2,69)])
 draw_colored_polygon(points,fill)
 draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),edge,2.0,true)
