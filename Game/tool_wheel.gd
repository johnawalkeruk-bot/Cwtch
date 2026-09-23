extends Control
signal tool_selected(index: int)
signal cancelled
const LABELS := ["Hoe", "Seed packet", "Watering can", "Put away"]
const NOTES := ["Turn grass into earth", "Scatter a little green", "Give the ground a drink", "Stow your tool and wander"]
var selected := 0
var hovered := -1
var title: Label
var subtitle: Label
var instruction: Label
var center: Vector2
var icons: Array[Texture2D] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for key in ["hoe","seeds","water"]:
		icons.append(load("res://assets/tools/%s_icon.png" % key) if ResourceLoader.exists("res://assets/tools/%s_icon.png" % key) else null)
	title = _label(24,Color("e5c17c"))
	subtitle = _label(15,Color("d0ded0"))
	instruction = _label(14,Color("b2c6bb"))
	instruction.text = "MOVE MOUSE TO CHOOSE    ·    CLICK TO EQUIP    ·    TAB / ESC TO CLOSE"
	resized.connect(_layout)
	_layout()
	hide()

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _layout() -> void:
	center = size*0.5
	title.position = center+Vector2(-180,-264)
	title.size = Vector2(360,36)
	subtitle.position = center+Vector2(-200,205)
	subtitle.size = Vector2(400,28)
	instruction.position = center+Vector2(-370,244)
	instruction.size = Vector2(740,28)
	queue_redraw()

func open(current: int) -> void:
	selected = current
	hovered = current
	show()
	_refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var offset: Vector2 = event.position-center
		if offset.length()<65 or offset.length()>220:
			hovered = -1
		else:
			hovered = int(floor(fposmod(offset.angle()+PI/2+PI/4,TAU)/(TAU/4)))
		_refresh()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and hovered>=0:
			tool_selected.emit(hovered)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			cancelled.emit()
		accept_event()

func _refresh() -> void:
	instruction.text = "LEFT STICK / D-PAD  CHOOSE · A / CROSS  EQUIP · B / CIRCLE  CLOSE" if ControllerInput.using_pad else "MOVE MOUSE TO CHOOSE · CLICK TO EQUIP · TAB / ESC TO CLOSE"
	title.text = "Choose your tool"
	subtitle.text = NOTES[hovered] if hovered>=0 else "Take your time."
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.045,0.04,0.64))
	for i in range(4):
		var angle := -PI/2+i*TAU/4
		var start := angle-PI/4+0.028
		var end := angle+PI/4-0.028
		var polygon := PackedVector2Array()
		for j in range(41): polygon.append(center+Vector2.from_angle(lerpf(start,end,j/40.0))*198)
		for j in range(40,-1,-1): polygon.append(center+Vector2.from_angle(lerpf(start,end,j/40.0))*72)
		draw_colored_polygon(polygon,Color("395548") if i==hovered else Color("18352f"))
		draw_arc(center,198,start,end,48,Color("e5c17c") if i==hovered else Color("657868"),2.0,true)
		var icon_center := center+Vector2.from_angle(angle)*128
		if icons.size()>i and icons[i]:
			draw_texture_rect(icons[i],Rect2(icon_center-Vector2(48,56),Vector2(96,96)),false)
		var font := get_theme_default_font()
		var text_width := font.get_string_size(LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(font,icon_center+Vector2(-text_width*0.5,57),LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f3ead4"))
	draw_circle(center,67,Color("102a25"))
	draw_arc(center,67,0,TAU,64,Color("9b895f"),1.0,true)
	var font := get_theme_default_font()
	draw_string(font,center+Vector2(-17,6),("Y / △" if ControllerInput.using_pad else "TAB"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e5c17c"))

func _process(_delta: float) -> void:
	if not visible: return
	var stick := ControllerInput.movement()
	if stick.length()>0.35:
		hovered=int(floor(fposmod(stick.angle()+PI/2+PI/4,TAU)/(TAU/4)))
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_accept"):
		tool_selected.emit(hovered if hovered>=0 else selected)
	elif event.is_action_pressed("ui_cancel"):
		cancelled.emit()
	elif event.is_action_pressed("ui_left"):
		hovered=posmod(hovered-1,4)
	elif event.is_action_pressed("ui_right"):
		hovered=posmod(hovered+1,4)
	elif event.is_action_pressed("ui_up"):
		hovered=0
	elif event.is_action_pressed("ui_down"):
		hovered=2
	else: return
	_refresh()
	get_viewport().set_input_as_handled()
