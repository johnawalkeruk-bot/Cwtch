extends Control
## Perspective-like hinged leaves, drawn in the same coordinates as the spread.
signal finished
var elapsed := 0.0
var active := false
var font: SystemFont
const HOLD := 0.65
const DURATION := 3.15

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Segoe Print","Ink Free","Segoe Script"])
	hide()

func start() -> void:
	elapsed=0.0
	active=true
	show()
	queue_redraw()

func stop() -> void:
	active=false
	hide()

func _process(delta: float) -> void:
	if not active: return
	elapsed=minf(DURATION,elapsed+delta)
	queue_redraw()
	if elapsed>=DURATION:
		stop()
		finished.emit()

func _ease(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _box(color: Color, radius: int=8) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(radius)
	return box

func _draw() -> void:
	var reveal:=_ease((elapsed-HOLD)/1.75)
	# A closed book begins at screen centre, then settles into the open spread.
	var shift:=-270.0*(1.0-reveal)
	draw_set_transform(Vector2(shift,0))
	draw_style_box(_box(Color(0,0,0,0.4),16),Rect2(548,14,540,590))
	draw_style_box(_box(Color("4b2c1d"),14),Rect2(538,0,542,600))
	for i in range(6):
		draw_style_box(_box(Color("b49b72").lerp(Color("ecd9b1"),i/6.0),4),Rect2(545,17-i,519+i,570))
	draw_style_box(_box(Color("f0dfbb"),4),Rect2(544,24,504,552))
	# Cover turns first, followed by two overlapping flyleaves.
	_leaf(_ease((elapsed-HOLD)/1.55),true,shift)
	for i in range(2):
		var progress:=_ease((elapsed-HOLD-0.65-i*0.30)/1.25)
		if progress>0.0: _leaf(progress,false,shift)
	draw_set_transform(Vector2.ZERO)

func _leaf(progress: float, leather: bool, shift: float) -> void:
	var angle:=progress*PI
	var width:=(540.0 if leather else 505.0)*cos(angle)
	var lift:=sin(angle)*32.0
	var top:=0.0 if leather else 24.0
	var bottom:=600.0 if leather else 576.0
	var edge:=540.0+width
	draw_set_transform(Vector2(shift,0))
	var polygon:=PackedVector2Array([Vector2(540,top),Vector2(edge,top-lift),Vector2(edge,bottom+lift),Vector2(540,bottom)])
	var color:=Color("593721") if leather and progress<0.5 else Color("e9d5ab")
	color=color.darkened(sin(angle)*0.22)
	draw_colored_polygon(polygon,color)
	draw_polyline(PackedVector2Array([polygon[0],polygon[1],polygon[2],polygon[3],polygon[0]]),Color("997347"),2,true)
	if leather and progress<0.5 and width>5:
		# Decorations squash with the front cover as it swings around the spine.
		draw_set_transform(Vector2(540+shift,0),0,Vector2(width/540.0,1))
		var random:=RandomNumberGenerator.new()
		random.seed=1891
		for i in range(1700):
			draw_circle(Vector2(random.randf_range(12,528),random.randf_range(12,588)),random.randf_range(.4,1.4),Color(0.8,0.61,0.35,0.11))
		draw_rect(Rect2(26,26,488,548),Color("b18b51"),false,2)
		draw_rect(Rect2(34,34,472,532),Color("82613d"),false,1)
		for y in range(46,557,10):
			draw_line(Vector2(17,y),Vector2(17,y+4),Color("b69260"))
			draw_line(Vector2(523,y),Vector2(523,y+4),Color("b69260"))
		_gold("C W T C H",198,39)
		_gold("FIELD GUIDE",254,27)
		_gold("Your slice of the valley",430,18)
		draw_arc(Vector2(270,330),42,0,TAU,60,Color("c5a363"),2,true)
		draw_polyline(PackedVector2Array([Vector2(236,345),Vector2(262,314),Vector2(276,330),Vector2(290,305),Vector2(307,345)]),Color("c5a363"),2,true)
	elif not leather:
		for i in range(12):
			var x:=540+width*(i/12.0)
			draw_line(Vector2(x,top),Vector2(x,bottom),Color(0.35,0.22,0.09,0.05*sin(angle)),2)
	draw_set_transform(Vector2(shift,0))

func _gold(text: String, y: float, font_size: int) -> void:
	var x:=(540-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)*0.5
	draw_string(font,Vector2(x+1,y+2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("28170f"))
	draw_string(font,Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d8b879"))
