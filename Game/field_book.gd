extends Control
## A separate lit 3D world keeps book previews independent of the paused garden.
signal closed
const INK := Color("483322")
const ENTRIES := [
 ["People","Arthur","Arthur brings a steady pace to the garden. Between quiet walks he pauses to enjoy the valley, content to let the day unfold.","Arthur"],
 ["People","Meera","A familiar face among the garden paths. Meera wanders between the plots and the wild edge, taking in the changing light.","Meera"],
 ["People","Angus McDoogal","There is always a little movement where Angus stands. His lively gestures bring a welcome touch of company to a quiet afternoon.","Angus"],
 ["People","The visitor","A traveller passing through the valley. Stop for a moment and watch: even an unhurried garden has its small conversations.","WanderingVisitor"],
 ["Animals","Peacock","A colourful garden companion, with an iridescent neck and a magnificent tail.","Peacock"],
 ["Animals","Chicken","A small, busy companion on the garden paths. Watch those quick steps and curious pauses as it explores the ground.","WanderingChicken"],
 ["Animals","Hedgehog","Low to the ground and never in a hurry. The hedgehog noses around the garden, stopping now and then before continuing its little journey.","Hedgehog"],
 ["Animals","Badger","A sturdy visitor with a distinctive striped face. The badger takes slow turns around the plots and shares the paths with its neighbours.","Badger"],
 ["Animals","Dragon","A little valley wonder. Folded wings, a restless tail and gentle movements make this unusual garden guest hard to overlook.","Dragon"],
 ["Plants","Ash","Tall woodland shapes frame the valley beyond the garden. Turn this specimen to see the branching crown and the texture of its trunk.","res://assets/trees/ash_forest.glb"],
 ["Plants","Birch","Pale trunks catch the changing light at the wild edge. Birch trees soften the transition from tended ground to the woodland beyond.","res://assets/trees/birch_forest.glb"]
]
var garden: Node3D
var page := 0
var category := "People"
var entries: Array[int] = []
var spread: Control
var title: Label
var description: Label
var visit_notes: Label
var folio: Label
var section: Label
var land_page: Control
var preview_holder: SubViewportContainer
var viewport: SubViewport
var turntable: Node3D
var preview: Node3D
var previous: Button
var tabs: Array[Button] = []
var navigation_hint: Label
const CATEGORIES := ["People","Animals","Plants","Land area"]
var serif: SystemFont
var opening: Control
var reveal_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	serif=SystemFont.new()
	serif.font_names=PackedStringArray(["Segoe Print","Ink Free","Segoe Script"])
	spread=Control.new()
	add_child(spread)
	spread.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	spread.offset_left=-540
	spread.offset_right=540
	spread.offset_top=-300
	spread.offset_bottom=300
	spread.draw.connect(_draw_book)
	_text("C W T C H   /   F I E L D   N O T E S",Vector2(76,48),Vector2(470,28),17)
	for i in CATEGORIES.size():
		var label: String=CATEGORIES[i]
		var tab:=_button(label,Vector2(-82,154+i*70),Vector2(128,54),func(): _category(label))
		tabs.append(tab)
	navigation_hint=_text("LB / RB  ·  category\nArrows  ·  entries     B / Esc  ·  close",Vector2(580,48),Vector2(425,76),15)
	section=_text("",Vector2(84,98),Vector2(410,28),14)
	title=_text("",Vector2(580,139),Vector2(405,65),35)
	description=_text("",Vector2(580,232),Vector2(395,210),21)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	visit_notes=_text("",Vector2(580,446),Vector2(410,76),16)
	folio=_text("",Vector2(450,542),Vector2(160,28),15)
	folio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	previous=_button("‹  Previous",Vector2(80,533),Vector2(150,38),func(): _turn(-1))
	_button("Next  ›",Vector2(240,533),Vector2(130,38),func(): _turn(1))
	_button("Close book",Vector2(823,533),Vector2(175,38),close)
	var holder:=SubViewportContainer.new()
	preview_holder=holder
	holder.position=Vector2(80,138)
	holder.size=Vector2(420,365)
	holder.stretch=true
	holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spread.add_child(holder)
	viewport=SubViewport.new()
	viewport.size=Vector2i(420,365)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	holder.add_child(viewport)
	turntable=Node3D.new()
	viewport.add_child(turntable)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.7
	camera.position=Vector3(0,0.3,4)
	camera.look_at(Vector3.ZERO)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("fff0d8")
	environment.environment.ambient_light_energy=0.75
	viewport.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	light.light_energy=1.2
	viewport.add_child(light)
	land_page=preload("res://land_area_page.gd").new()
	spread.add_child(land_page)
	land_page.hide()
	opening=preload("res://book_opening.gd").new()
	add_child(opening)
	opening.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	opening.offset_left=-540
	opening.offset_right=540
	opening.offset_top=-300
	opening.offset_bottom=300
	opening.finished.connect(_finish_opening)
	hide()

func _finish_opening() -> void:
	spread.show()
	spread.modulate.a=0.0
	reveal_tween=create_tween()
	reveal_tween.tween_property(spread,"modulate:a",1.0,0.25)
	var focused:=get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func _text(value: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label:=Label.new()
	label.text=value
	label.position=at
	label.size=dimensions
	label.add_theme_font_override("font",serif)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spread.add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button:=Button.new()
	button.text=value
	button.focus_mode=Control.FOCUS_NONE
	button.position=at
	button.size=dimensions
	button.add_theme_font_override("font",serif)
	button.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("d9bc85") if state in ["hover","pressed"] else Color("e6d0a1")
		style.border_color=Color("866037")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_"+state+"_color",INK)
	button.add_theme_color_override("font_color",INK)
	button.pressed.connect(action)
	spread.add_child(button)
	return button

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.012,0.008,0.78))

func _draw_book() -> void:
	spread.draw_style_box(_panel(Color(0,0,0,0.4),18),Rect2(9,14,1080,600))
	spread.draw_style_box(_panel(Color("4b2c1d"),16),Rect2(0,0,1080,600))
	# Deterministic leather grain and rubbed edges, drawn without bitmap assets.
	var random:=RandomNumberGenerator.new()
	random.seed=1891
	for i in range(2800):
		spread.draw_circle(Vector2(random.randf_range(8,1072),random.randf_range(8,592)),random.randf_range(.3,1.2),Color(0.76,0.55,0.31,0.12))
	for x in range(24,1060,9):
		spread.draw_line(Vector2(x,14),Vector2(x+4,14),Color("a07b4b"))
		spread.draw_line(Vector2(x,586),Vector2(x+4,586),Color("a07b4b"))
	spread.draw_style_box(_panel(Color("bea275"),5),Rect2(28,29,1024,548))
	spread.draw_style_box(_panel(Color("eddbb2"),5),Rect2(32,24,505,552))
	spread.draw_style_box(_panel(Color("f0dfbb"),5),Rect2(543,24,505,552))
	for x in range(515,566):
		spread.draw_line(Vector2(x,25),Vector2(x,575),Color(0.22,0.12,0.04,0.24*(1.0-absf(x-540)/26.0)),1)
	for i in range(700):
		spread.draw_circle(Vector2(random.randf_range(42,1038),random.randf_range(30,570)),random.randf_range(.3,1.1),Color(0.35,0.2,0.08,0.055))
	spread.draw_line(Vector2(580,214),Vector2(986,214),Color("aa8954"),1)
	spread.draw_line(Vector2(82,512),Vector2(498,512),Color("aa8954"),1)

func _panel(color: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	return style

func open(world: Node3D) -> void:
	garden=world
	show()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_category(category)
	if reveal_tween: reveal_tween.kill()
	spread.hide()
	spread.modulate.a=1.0
	opening.start()

func close() -> void:
	opening.stop()
	if reveal_tween: reveal_tween.kill()
	hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(preview):
		preview.free()
		preview=null
	closed.emit()

func _category(value: String) -> void:
	category=value
	for tab in tabs:
		tab.modulate=Color("ffe5ae") if tab.text==category else Color("b9aa8c")
	entries.clear()
	for i in ENTRIES.size():
		if ENTRIES[i][0]==category:
			if category!="Animals" or garden.wildlife.records.has(str(ENTRIES[i][1]).to_lower()): entries.append(i)
	page=0
	_show_entry()

func _turn(direction: int) -> void:
	if category=="Land area":
		land_page.turn(direction)
		return
	if entries.is_empty():return
	page=posmod(page+direction,entries.size())
	_show_entry()

func _show_entry() -> void:
	visit_notes.text=""
	var land: bool=category=="Land area"
	land_page.visible=land
	preview_holder.visible=not land
	description.visible=not land
	if land:
		if is_instance_valid(preview):preview.free();preview=null
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		land_page.setup(garden,serif)
		title.text="Land area"
		section.text="LAND AREA   /   GARDEN SURVEY"
		navigation_hint.text="LB / RB  ·  category\nArrows / hover  ·  inspect tiles"
		folio.text="Garden survey"
		return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	navigation_hint.text="LB / RB  ·  category\nArrows  ·  entries     B / Esc  ·  close"
	if entries.is_empty():
		title.text="No animal visits yet"
		description.text="Make a little grass and watch the wild edge. Your first visitor will appear here after entering the garden."
		section.text=category.to_upper()
		folio.text="-"
		if is_instance_valid(preview):preview.free();preview=null
		return
	var entry: Array=ENTRIES[entries[page]]
	title.text=entry[1]
	description.text=entry[2]
	if category=="Animals":
		var record: Dictionary=garden.wildlife.records[str(entry[1]).to_lower()]
		visit_notes.text="First visit: Day %d\n"%int(record.visit_day)
		visit_notes.text+=("Resident since: Day %d"%int(record.resident_day)) if int(record.resident_day)>0 else ("Resident requirement: 5% grass" if entry[1]=="Hedgehog" else "Not yet resident")
	section.text=category.to_upper()+"   /   OBSERVATIONS FROM THE VALLEY"
	folio.text="%02d   /   %02d" % [page+1,entries.size()]
	if is_instance_valid(preview): preview.free()
	preview=Node3D.new()
	turntable.add_child(preview)
	var model: Node3D
	if str(entry[3]).begins_with("res://"):
		model=load(entry[3]).instantiate()
	else:
		var actor: Node3D=garden.wildlife.actor_for(str(entry[1]).to_lower()) if category=="Animals" else garden.get_node_or_null(entry[3])
		if not is_instance_valid(actor):return
		model=actor.visual.duplicate(0)
		model.rotation=Vector3.ZERO
	preview.add_child(model)
	for animation in model.find_children("*","AnimationPlayer",true,false): animation.stop(true)
	var bounds: AABB=preload("res://floating_tool.gd").bounds(model)
	var factor:=2.15/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	preview.scale=Vector3.ONE*factor
	preview.position=-bounds.get_center()*factor
	turntable.rotation.y=-0.25

func _process(delta: float) -> void:
	if visible and category!="Land area": turntable.rotation.y+=delta*0.22

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide") or event is InputEventKey and event.pressed and event.keycode in [KEY_F,KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
	elif opening.active:
		if event is InputEventJoypadButton or event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		_category(CATEGORIES[posmod(CATEGORIES.find(category)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),CATEGORIES.size())])
		get_viewport().set_input_as_handled()
	elif category=="Land area" and _land_navigation(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_DOWN]:
		_turn(-1 if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP] else 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]:
		_turn(-1 if event.keycode in [KEY_LEFT,KEY_UP] else 1)
		get_viewport().set_input_as_handled()

func _land_navigation(event: InputEvent) -> bool:
	var direction:=Vector2i.ZERO
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:direction=Vector2i.LEFT
			KEY_RIGHT:direction=Vector2i.RIGHT
			KEY_UP:direction=Vector2i.UP
			KEY_DOWN:direction=Vector2i.DOWN
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT:direction=Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT:direction=Vector2i.RIGHT
			JOY_BUTTON_DPAD_UP:direction=Vector2i.UP
			JOY_BUTTON_DPAD_DOWN:direction=Vector2i.DOWN
	if direction==Vector2i.ZERO:return false
	land_page.move_selection(direction)
	return true
