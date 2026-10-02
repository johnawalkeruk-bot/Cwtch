extends CanvasLayer
## A procedural six-petal animation inspired by Art/Loading/petal_reference.mp4.
## Completion is driven by garden readiness, never by an audio/video duration.
class Petals extends Control:
 var elapsed := 0.0
 var reveal := -1.0
 var caption := "OPENING YOUR GARDEN"
 var fragments: Array[Dictionary]=[]
 var border: Texture2D=preload("res://assets/ui/Border-1.png")
 func _process(delta: float) -> void:
  elapsed+=delta
  if reveal>=0:reveal+=delta
  queue_redraw()
 func scatter() -> void:
  reveal=0
  fragments.clear()
  var rng:=RandomNumberGenerator.new();rng.seed=91831
  for y in 6:
   for x in 10:
    var start:=Vector2((x+0.5)*size.x/10,(y+0.5)*size.y/6)
    var direction: Vector2=(start-size*0.5).normalized().rotated(rng.randf_range(-0.8,0.8))
    fragments.append({"start":start,"velocity":direction*rng.randf_range(420,850),"angle":rng.randf_range(-PI,PI),"spin":rng.randf_range(-3,3),"size":rng.randf_range(110,230)})
 func petal_points() -> PackedVector2Array:
  var points:=PackedVector2Array()
  var root:=Vector2(0,-20);var tip:=Vector2(0,-207)
  for side in [1,-1]:
   var a: Vector2=root if side==1 else tip
   var b: Vector2=tip if side==1 else root
   var control:=Vector2(86*side,-126)
   for i in 25:
    var t:=float(i)/24
    points.append((1-t)*(1-t)*a+2*(1-t)*t*control+t*t*b)
  return points
 func _draw() -> void:
  var fade:=1.0 if reveal<0 else 1.0-smoothstep(0,0.45,reveal)
  draw_rect(Rect2(Vector2.ZERO,size),Color(0.022,0.042,0.047,fade))
  var center:=size*0.5-Vector2(0,25)
  var scale_factor:=minf(size.x/1280,size.y/720)
  if fade>0:
   for i in 34:
    var point:=Vector2(fposmod(i*173.7,size.x),fposmod(i*97.1-elapsed*3,size.y))
    draw_circle(point,1.2,Color(0.3,0.6,0.66,fade*(0.045+0.025*sin(elapsed+i))))
   var points:=petal_points()
   for i in 6:
    var cycle:=fposmod(elapsed*1.5-i,6.0)
    var light:=exp(-cycle*0.85)*(0.85+0.15*sin(elapsed*2.5))
    var angle:=i*TAU/6
    for halo in range(7,0,-1):
     draw_set_transform(center,angle,Vector2.ONE*scale_factor*(1+halo*0.018))
     draw_colored_polygon(points,Color(0.1,0.65,1,light*0.025*fade))
    draw_set_transform(center,angle,Vector2.ONE*scale_factor)
    var color:=Color("202e33").lerp(Color("32d4f5"),light)
    color.a=fade
    draw_colored_polygon(points,color)
    var outline:=points.duplicate();outline.append(points[0])
    draw_polyline(outline,Color(0.40,0.65,0.73,(0.24+light*0.6)*fade),2,true)
   draw_set_transform(Vector2.ZERO)
   var font:=ThemeDB.fallback_font
   var text_size:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
   draw_string(font,Vector2((size.x-text_size.x)/2,center.y+270*scale_factor),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.77,0.86,0.85,fade))
  if reveal>=0:
   var t:=reveal
   for piece in fragments:
    var position: Vector2=piece.start+piece.velocity*t+Vector2(0,180*t*t)
    var width: float=piece.size*(1+0.35*t)
    draw_set_transform(position,piece.angle+piece.spin*t)
    draw_texture_rect(border,Rect2(Vector2.ONE*(-width/2),Vector2.ONE*width),false,Color(1,1,1,1-smoothstep(0.25,0.95,t)))
   draw_set_transform(Vector2.ZERO)

var art: Petals
var music: AudioStreamPlayer
var fading: Tween
var active := false
func _ready() -> void:
 layer=240
 art=Petals.new()
 add_child(art)
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.mouse_filter=Control.MOUSE_FILTER_STOP
 music=AudioStreamPlayer.new()
 music.stream=preload("res://audio/loading/i_will_wait.mp3")
 music.volume_db=-12
 add_child(music)
 music.finished.connect(func():
  if active and art.reveal<0:music.play())
 hide()
func begin() -> void:
 if fading and fading.is_running():fading.kill()
 active=true
 art.elapsed=0;art.reveal=-1;art.fragments.clear()
 art.caption="OPENING YOUR GARDEN"
 music.volume_db=-12
 music.play()
 show()
func report(message: String) -> void:
 art.caption=message.to_upper()
func finish() -> void:
 art.scatter()
 fading=create_tween()
 fading.tween_property(music,"volume_db",-60.0,0.22)
 fading.tween_callback(music.stop)
 await get_tree().create_timer(1.0).timeout
 active=false
 music.stop()
 hide()
func abort() -> void:
 active=false
 if fading and fading.is_running():fading.kill()
 music.stop()
 hide()
func _input(event: InputEvent) -> void:
 if active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventJoypadButton or event is InputEventJoypadMotion):
  get_viewport().set_input_as_handled()
