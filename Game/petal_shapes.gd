extends RefCounted
const GOLD := Color("f4d03f")
const EARTH := Color("aa914b")
const INK := Color("263c35")
const PAPER := Color("f3e6c9")

static func petal(canvas: CanvasItem, at: Vector2, angle: float, length: float, width: float, color: Color, glow: bool=false) -> void:
	var axis := Vector2.from_angle(angle)
	var side := axis.orthogonal()
	var points := PackedVector2Array([at,at+axis*length*0.3-side*width*0.48,at+axis*length*0.73-side*width*0.42,at+axis*length,at+axis*length*0.73+side*width*0.42,at+axis*length*0.3+side*width*0.48])
	if glow:
		canvas.draw_circle(at+axis*length*0.55,width*0.72,Color(1,0.69,0.12,0.13))
	canvas.draw_colored_polygon(points,color)
	canvas.draw_colored_polygon(PackedVector2Array([points[0],points[3],points[4],points[5]]),color.lightened(0.14))
	canvas.draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[4],points[5],points[0]]),color.darkened(0.3),1.5,true)

static func serif() -> Font:
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["Georgia","Cambria","Times New Roman"])
	return font
