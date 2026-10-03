extends Control
const Petals=preload("res://petal_shapes.gd")
const Icons=preload("res://controller_icons.gd")
var world: Node3D
var garden: Node3D
var player_slot := 0
var village := false
var font: Font

func setup(scene: Node3D, slot: int=0, in_village: bool=false) -> void:
	world=scene
	player_slot=slot
	village=in_village
	garden=world.host.garden if village else world
	font=Petals.serif()
	position=Vector2(20,18)
	size=Vector2(302,192)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if is_instance_valid(garden):queue_redraw()

func prompts() -> Array:
	if village:
		return [["accept","Select"],["back","Back"]] if world.paused or world.current_shop>=0 else [["accept","Enter shop"],["pause","Pause"]]
	if garden.field_book.visible:return [["left","Category"],["right","Category"],["back","Close"]]
	if garden.guide.visible:return [["accept","Select"],["back","Back"]]
	var wheel: Control=garden.tool_wheel if player_slot==0 else garden.local_coop.second.tool_wheel
	if wheel.visible:return [["accept","Select"],["back","Close"],["move","Choose"]]
	var placement: Node=garden.placement if player_slot==0 else garden.local_coop.second.placement
	if is_instance_valid(placement) and placement.active():
		var actions: Array=[["accept","Place" if not placement.purchase_id.is_empty() else "Send here"],["back","Cancel"]]
		if not placement.purchase_id.is_empty():actions.append_array([["left","Rotate left"],["right","Rotate right"]])
		return actions
	var items := [["mode","Tools"],["accept","Move animal"],["use","Use tool"],["back","Put away"],["pause","Pause"]]

	return items

func _text(text: String, at: Vector2, size_px: int, color: Color=Petals.INK) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _draw() -> void:
	if not is_instance_valid(garden) or not is_instance_valid(garden.valley_cycle):return
	var cycle: Node3D=garden.valley_cycle
	var at := Vector2(76,74)
	var progress: float=garden.experience.progress()
	for i in 12:
		var angle := -PI/2+float(i)*TAU/12.0
		Petals.petal(self,at+Vector2.from_angle(angle)*44,angle,29,24,Petals.GOLD if float(i)/12.0<progress else Color("a99664"))
	draw_circle(at+Vector2(0,3),46,Color(0,0,0,0.25))
	draw_circle(at,46,Petals.INK)
	draw_circle(at,42,Petals.PAPER)
	for i in 12:
		var direction := Vector2.from_angle(-PI/2+float(i)*TAU/12)
		draw_line(at+direction*34,at+direction*38,Petals.INK,2,true)
	var hours := fposmod(6.0+cycle.elapsed*24.0/cycle.FULL_CYCLE,24.0)
	var hour_angle := hours/12.0*TAU-PI/2
	var minute_angle := fposmod(hours,1.0)*TAU-PI/2
	_text("AM" if hours<12 else "PM",at+Vector2(-10,25),10)
	draw_line(at,at+Vector2.from_angle(hour_angle)*23,Petals.INK,4,true)
	draw_line(at,at+Vector2.from_angle(minute_angle)*33,Petals.INK,2,true)
	draw_circle(at,4,Color("b88b37"))
	var day := int(floor((cycle.elapsed+600.0)/cycle.FULL_CYCLE))+1
	var style:=preload("res://cwtch_theme.gd").compact_card()
	draw_style_box(style,Rect2(12,151,134,56))
	_text("LEVEL %d · DAY %d"%[garden.experience.level(),day],Vector2(21,174),12,Petals.PAPER)
	_text(cycle.WEATHER_NAMES[cycle.weather_index],Vector2(21,195),14,Petals.PAPER)
	var device: int=ControllerInput.primary_device() if player_slot==0 else ControllerInput.secondary_device()
	var pad: bool=device>=0 and (player_slot==1 or ControllerInput.using_pad)
	var items:=prompts()
	for i in items.size():
		var action: String=items[i][0]
		var y := 19+i*34
		if pad:draw_texture_rect(Icons.texture(action,device),Rect2(160,y,28,28),false)
		else:
			var key: String={"accept":"Enter" if garden.guide.visible or village or (not village and garden.tool_wheel.visible) else "R","back":"Esc" if garden.guide.visible or village or (not village and garden.tool_wheel.visible) else "T","mode":"Tab","use":"Click","pause":"Esc","move":"Mouse","left":"←","right":"→"}.get(action,"")
			if not village and is_instance_valid(garden.placement) and garden.placement.active():
				key={"accept":"Click","back":"Esc","left":"Q","right":"E"}.get(action,key)
			draw_string_outline(font,Vector2(157,y+19),key,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color("172d2a"))
			_text(key,Vector2(157,y+19),11,Petals.GOLD)
		draw_string_outline(font,Vector2(195,y+20),items[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("172d2a"))
		_text(items[i][1],Vector2(195,y+20),14,Petals.PAPER)
