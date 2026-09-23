extends "res://main.gd"

enum Tool { HOE, SEEDS, WATER, NONE }
const TOOL_NAMES := ["Hoe", "Seed packet", "Watering can", "No tool equipped"]
const GROW_SECONDS := 12.0
const HARVEST_GOAL := 6
const REACH := 100.0
const DioramaCamera = preload("res://diorama_camera.gd")
const GlidingCursor = preload("res://gliding_cursor.gd")
const ThirdPersonPlayer = preload("res://third_person_player.gd")
const HeightTerrain = preload("res://height_terrain.gd")
const PomMaterial = preload("res://pom_material.gd")
const WelshSky = preload("res://welsh_sky.gd")
const WanderingNPC = preload("res://animated_visitor.gd")
const ChickenNPC = preload("res://chicken_npc.gd")
const SelectionTarget = preload("res://selection_target.gd")
const ValleyAmbience = preload("res://valley_ambience.gd")
const ValleyCycle = preload("res://valley_cycle.gd")
const BackgroundMeadow = preload("res://background_meadow.gd")
const ValleyLandscape = preload("res://valley_landscape.gd")
var valley_landscape: Node3D
const CyclingNPC = preload("res://cycling_npc.gd")
const ProceduralAnimal = preload("res://procedural_animal.gd")
const HedgehogNPC = preload("res://hedgehog_npc.gd")
var blocked_cells: Dictionary = {}
var hedgehog: Node3D
var additional_visitors: Array[Node3D] = []
var background_meadow: Node3D
var valley_cycle: Node3D

var visitor: Node3D
var chicken: Node3D
var selected_target: Area3D
var camera_pitch := PI / 4.0
var aiming := false
var aim_dot: Label

var tool: int = Tool.HOE
var tool_wheel: Control
var floating_tool: Node3D
var watered_cells: Dictionary = {}
var watered_image: Image
var watered_texture: ImageTexture
var toast_timer := 0.0
var last_message := ""
var crops: Dictionary = {}
var harvested := 0
var action_pending := false
var trigger_held := false
var action_mouse := Vector2.ZERO
var pending_bounds := Rect2i()
var pending_tool := 0
var chunk_selection := false
var selection_button: Button
var player: Node3D
var camera_yaw := 0.0
var heightfield: Node3D
var ambience: Node
var ambience_button: Button
var ambience_muted := false
var message := "Welcome to your valley. Prepare a little ground."
var hud: Label
var hint: Label
var notice: Label
var field_book: Control
var guide: PanelContainer
var control_hint: Label
var guide_controls: Label
var tool_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	status.hide()
	_create_garden_ui()
	ControllerInput.mode_changed.connect(_controller_prompts)
	ControllerInput.disconnected.connect(func(): _set_guide(true))
	_controller_prompts()
	_set_guide(true)
	watered_image = Image.create(grid_size.x,grid_size.y,false,Image.FORMAT_R8)
	watered_image.fill(Color.BLACK)
	watered_texture = ImageTexture.create_from_image(watered_image)
	terrain_material.set_shader_parameter("watered_tiles",watered_texture)
	heightfield.water_material.set_shader_parameter("watered_tiles",watered_texture)
	floating_tool = preload("res://floating_tool.gd").new()
	add_child(floating_tool)
	floating_tool.setup(self)
	floating_tool.effect_applied.connect(_apply_tool)
	ambience = ValleyAmbience.new()
	add_child(ambience)
	hedgehog = HedgehogNPC.new()
	hedgehog.name = "Hedgehog"
	add_child(hedgehog)
	hedgehog.setup(self)
	SelectionTarget.attach(hedgehog, "Hedgehog", Vector3(0.3,0.30,0.38))
	visitor = WanderingNPC.new()
	visitor.name = "WanderingVisitor"
	add_child(visitor)
	visitor.setup(self)
	SelectionTarget.attach(visitor, "Valley visitor", Vector3(0.65, 1.5, 0.65))
	chicken = ChickenNPC.new()
	chicken.name = "WanderingChicken"
	add_child(chicken)
	chicken.setup(self)
	SelectionTarget.attach(chicken, "Chicken", Vector3(0.40, 0.48, 0.45))
	valley_cycle = ValleyCycle.new()
	valley_cycle.name = "DayNightWeather"
	add_child(valley_cycle)
	valley_cycle.setup(self)
	background_meadow = BackgroundMeadow.new()
	add_child(background_meadow)
	background_meadow.build(self)
	valley_landscape = ValleyLandscape.new()
	add_child(valley_landscape)
	valley_landscape.build(self)
	for entry in [["Arthur", "npcs/arthur", 0.999512, Vector2i(2, 3)], ["Meera", "npcs/meera", 0.999512, Vector2i(5, 5)]]:
		var npc := CyclingNPC.new()
		npc.name = entry[0]
		npc.display_name = entry[0]
		npc.model_scene = load("res://assets/%s.glb" % entry[1])
		npc.model_height = entry[2]
		npc.cell = entry[3]
		add_child(npc)
		npc.setup(self)
		SelectionTarget.attach(npc, entry[0], Vector3(0.65, 1.5, 0.65))
		additional_visitors.append(npc)
	var angus := preload("res://angus_npc.gd").new()
	angus.name="Angus"
	angus.cell=Vector2i(7,2)
	add_child(angus)
	angus.setup(self)
	SelectionTarget.attach(angus,"Angus McDoogal",Vector3(0.8,1.5,0.8))
	additional_visitors.append(angus)
	for entry in [["Badger","badger",Vector2i(0,4)],["Dragon","dragon",Vector2i(7,5)]]:
		var animal := ProceduralAnimal.new()
		animal.name = entry[0]
		animal.species = entry[1]
		animal.cell = entry[2]
		add_child(animal)
		animal.setup(self)
		SelectionTarget.attach(animal,entry[0],Vector3(0.7,0.45,0.7) if entry[1]=="badger" else Vector3(1.1,0.65,0.8))
		additional_visitors.append(animal)
	var meadow_grass := preload("res://meadow_grass.gd").new()
	add_child(meadow_grass)
	meadow_grass.build(self)
	var model_weather := preload("res://model_weather.gd").new()
	add_child(model_weather)
	model_weather.setup(self)
	_refresh_ui()

func _create_chunks() -> void:
	heightfield = HeightTerrain.new()
	add_child(heightfield)
	heightfield.build(self)

func cell_center(cell: Vector2i) -> Vector3:
	var point := super.cell_center(cell)
	if is_instance_valid(heightfield) and heightfield.heights != null:
		point.y = heightfield.height_at(Vector2(point.x, point.z))
	return point

func _create_cursor() -> void:
	cursor = GlidingCursor.new()
	cursor.name = "GlidingCursor"
	add_child(cursor)

func _toggle_ambience() -> void:
	ambience_muted = not ambience_muted
	ambience.muted = ambience_muted
	ambience_button.text = "Ambience: off [M]" if ambience_muted else "Ambience: on [M]"

func _create_view() -> void:
	super._create_view()
	var world: WorldEnvironment
	var sun: DirectionalLight3D
	for child in get_children():
		if child is WorldEnvironment:
			world = child
		elif child is DirectionalLight3D:
			sun = child
	WelshSky.apply(world, sun)
	player = ThirdPersonPlayer.new()
	player.name = "SpiritController"
	add_child(player)
	player.setup(self)
	DioramaCamera.configure(camera, player.position)
	terrain_material.set_shader_parameter("orthographic_view", false)

func _create_terrain() -> void:
	super._create_terrain()
	var offset := (grid_size - Vector2i(9, 9)) / 2
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			var patch := Vector2i(x, z) - offset
			var kind: int = Terrain.GRASS
			if patch.x >= 0 and patch.x <= 8 and patch.y >= 0 and patch.y <= 8 and (patch.x == 0 or patch.y == 0 or patch.x == 8):
				kind = Terrain.LONG_GRASS
			if patch.y == 7 and patch.x >= 0 and patch.x <= 8:
				kind = Terrain.PATH
			if patch.x >= 1 and patch.x <= 3 and patch.y >= 3 and patch.y <= 5:
				kind = Terrain.HARD_DIRT
			if patch.x >= 0 and patch.x <= 1 and patch.y == 6:
				kind = Terrain.STONE
			terrain_image.set_pixel(x, z, Color(float(kind) / 255.0, 0.0, 0.0))
	terrain_texture.update(terrain_image)
	terrain_material.set_shader_parameter("color_maps", load("res://assets/textures/terrain_colors.res"))
	terrain_material.set_shader_parameter("normal_maps", load("res://assets/textures/terrain_normals.res"))
	terrain_material.set_shader_parameter("detail_maps", load("res://assets/textures/terrain_details.res"))
	terrain_material.set_shader_parameter("riverbed_color", load("res://assets/textures/water/M_RiverBottom_BaseColor.tga"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pad_wheel"):
		if not guide.visible and not floating_tool.busy: _set_wheel(not tool_wheel.visible)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pad_guide") or event.is_action_pressed("ui_cancel") and ControllerInput.using_pad:
		if tool_wheel.visible: _set_wheel(false)
		else: _toggle_guide()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("pad_use"):
		var pressed := event.is_action_pressed("pad_use")
		if pressed and not trigger_held and not guide.visible and not tool_wheel.visible and not floating_tool.busy:
			action_pending=true
		trigger_held=pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB:
			if not guide.visible and not floating_tool.busy: _set_wheel(not tool_wheel.visible)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_ESCAPE and tool_wheel.visible:
			_set_wheel(false)
			return
		if event.keycode in [KEY_F,KEY_ESCAPE]:
			_toggle_guide()
			return
		if event.keycode==KEY_M:
			_toggle_ambience()
			return
		if guide.visible: return
		if event.keycode>=KEY_1 and event.keycode<=KEY_3 and not floating_tool.busy:
			_select_tool(event.keycode-KEY_1)
			_set_wheel(false)
			return
	if guide.visible or tool_wheel.visible: return
	if event is InputEventMouseMotion and aiming:
		camera_yaw -= event.relative.x*0.004
		camera_pitch = clampf(camera_pitch+event.relative.y*0.004,deg_to_rad(-80),deg_to_rad(80))
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not floating_tool.busy: action_pending=true

func _set_wheel(open: bool) -> void:
	action_pending = false
	if open:
		tool_wheel.open(tool)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not ControllerInput.using_pad: Input.warp_mouse(get_viewport().get_visible_rect().size*0.5)
		var focused := get_viewport().gui_get_focus_owner()
		if focused: focused.release_focus()
	else:
		tool_wheel.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not guide.visible else Input.MOUSE_MODE_VISIBLE
	aiming = not open and not guide.visible
	aim_dot.visible = aiming

func _wheel_selected(index: int) -> void:
	_select_tool(index)
	_set_wheel(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(guide):
		_set_guide(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(guide) or guide.visible:
		cursor.clear()
		action_pending = false
		return
	if tool_wheel.visible: return
	terrain_material.set_shader_parameter("world_to_grid",global_transform.affine_inverse())
	var input := Vector2.ZERO
	if not floating_tool.busy:
		input = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		input = (input+ControllerInput.movement()).limit_length()
	var look := ControllerInput.look()
	camera_yaw -= look.x*1.8*delta
	camera_pitch = clampf(camera_pitch+look.y*1.5*delta,deg_to_rad(-80),deg_to_rad(80))
	player.advance(delta,input,camera_yaw)
	DioramaCamera.follow(camera,player.position,camera_yaw,camera_pitch)
	var target: Vector2i = player.cell
	selected_target = null if floating_tool.busy else _pick_object(get_viewport().get_visible_rect().size*0.5)
	if floating_tool.busy:
		cursor.follow_object(floating_tool.target_point,Vector2.ONE*MICRO_SIZE,delta)
	elif is_instance_valid(selected_target):
		cursor.follow_object(to_local(selected_target.subject.global_position),selected_target.selection_size(),delta)
	else:
		cursor.follow_object(player.position,Vector2.ONE*MICRO_SIZE,delta)
	if action_pending:
		action_pending=false
		if is_instance_valid(selected_target) and not contains_cell(selected_target.crop_cell):
			message = selected_target.subject.get_meta("inspection_text",selected_target.label+" is enjoying the valley.")
		elif player.is_settled() and cursor.is_settled():
			if is_instance_valid(selected_target): target=selected_target.crop_cell
			if blocked_cells.has(target): message="This ground is occupied."
			elif tool==Tool.NONE: message="Choose a tool from the wheel to tend the ground."
			else: floating_tool.use_at(target)
		else:
			message="Let the spirit settle, then tend this square."
	hovered_cell=target
	if not watered_cells.is_empty():
		for cell in watered_cells.keys():
			watered_cells[cell]=maxf(0.0,float(watered_cells[cell])-delta/70.0)
			watered_image.set_pixel(cell.x,cell.y,Color(watered_cells[cell],0,0))
			if watered_cells[cell]<=0: watered_cells.erase(cell)
		watered_texture.update(watered_image)
	toast_timer=maxf(0,toast_timer-delta)
	_refresh_ui()

func _pick_cell(mouse: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(mouse) * REACH, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INVALID_CELL
	var point := to_local(hit["position"])
	return local_to_cell(point)

func _pick_object(mouse: Vector2) -> Area3D:
	if not aiming and get_viewport().gui_get_hovered_control() != null:
		return null
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + camera.project_ray_normal(mouse) * REACH, FLOOR_MASK | 2)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is SelectionTarget:
		return hit.collider
	return null

func _act(cell: Vector2i) -> void:
	_apply_tool(cell,tool)

func _apply_tool(cell: Vector2i, active_tool: int) -> void:
	if not contains_cell(cell) or blocked_cells.has(cell): return
	var terrain := get_terrain(cell)
	match active_tool:
		Tool.HOE:
			if terrain in [Terrain.GRASS,Terrain.LONG_GRASS,Terrain.HARD_DIRT]:
				_clear_old_crop(cell)
				set_terrain(cell,Terrain.DIRT)
				message="Fresh earth, ready for a little green."
			else: message="Use the hoe on grass or hard earth."
		Tool.SEEDS:
			if terrain==Terrain.DIRT:
				_clear_old_crop(cell)
				set_terrain(cell,Terrain.GRASS)
				message="A fresh patch of grass."
			else: message="Scatter grass seed onto bare earth."
		Tool.WATER:
			watered_cells[cell]=1.0
			watered_image.set_pixel(cell.x,cell.y,Color(1,0,0))
			watered_texture.update(watered_image)
			message="A gentle drink for the ground."
	_refresh_ui()

func _clear_old_crop(cell: Vector2i) -> void:
	if crops.has(cell):
		crops[cell].node.queue_free()
		crops.erase(cell)

func _mesh_part(parent: Node3D, mesh: Mesh, color: Color, position: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	part.material_override = material
	parent.add_child(part)
	return part

func _make_plant(cell: Vector2i) -> Node3D:
	var plant := Node3D.new()
	add_child(plant)
	plant.position = cell_center(cell)
	var bulb := SphereMesh.new()
	bulb.radius = 0.14
	bulb.height = 0.22
	bulb.radial_segments = 8
	bulb.rings = 4
	_mesh_part(plant, bulb, Color("e6d3ba"), Vector3(0.0, 0.08, 0.0))
	var crown := SphereMesh.new()
	crown.radius = 0.115
	crown.height = 0.10
	crown.radial_segments = 8
	crown.rings = 4
	_mesh_part(plant, crown, Color("a87397"), Vector3(0.0, 0.16, 0.0))
	for i in range(5):
		var leaf := PrismMesh.new()
		leaf.size = Vector3(0.085, 0.27, 0.035)
		var angle := float(i) * TAU / 5.0
		var part := _mesh_part(plant, leaf, Color("60894b"),
			Vector3(sin(angle) * 0.06, 0.28, cos(angle) * 0.06))
		part.rotation = Vector3(0.4, angle, 0.3)
	plant.scale = Vector3.ONE * 0.25
	SelectionTarget.attach(plant, "Turnip", Vector3(0.42, 0.48, 0.42), cell)
	return plant

func _add_water_ring(plant: Node3D) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.21
	ring.rings = 20
	ring.ring_segments = 6
	_mesh_part(plant, ring, Color("80bdc4"), Vector3(0.0, 0.025, 0.0))

func _panel_style(_color: Color) -> StyleBoxFlat:
	return preload("res://cwtch_theme.gd").panel()

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_garden_ui() -> void:
	get_tree().root.theme = preload("res://cwtch_theme.gd").make()
	var layer := CanvasLayer.new()
	layer.name="GardenInterface"
	add_child(layer)
	var root := Control.new()
	root.theme=preload("res://cwtch_theme.gd").make()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	aim_dot=_label("·",24,Color("ead29c"))
	root.add_child(aim_dot)
	aim_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim_dot.offset_left=-8
	aim_dot.offset_right=8
	aim_dot.offset_top=-16
	aim_dot.offset_bottom=16
	aim_dot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var top := PanelContainer.new()
	root.add_child(top)
	top.position=Vector2(28,24)
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",5)
	top.add_child(stack)
	stack.add_child(_label("C W T C H",20,Color("e5c17c")))
	hud=_label("",14,Color("d9e3d5"))
	stack.add_child(hud)
	control_hint=_label("",12,Color("9cb7a8"))
	stack.add_child(control_hint)
	notice=_label("",16,Color("f3ead4"))
	root.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left=-280
	notice.offset_right=280
	notice.offset_top=44
	notice.offset_bottom=84
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_shadow_color",Color("132b26"))
	notice.add_theme_constant_override("shadow_offset_y",2)
	guide=PanelContainer.new()
	root.add_child(guide)
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	guide.offset_left=-250
	guide.offset_right=250
	guide.offset_top=-310
	guide.offset_bottom=310
	var pages := VBoxContainer.new()
	pages.add_theme_constant_override("separation",6)
	guide.add_child(pages)
	pages.add_child(_label("A MOMENT OF REST",24,Color("e5c17c")))
	pages.add_child(_label("A little care goes a long way.",16,Color("b2c6bb")))
	guide_controls=_label("",16,Color("eee5d1"))
	pages.add_child(guide_controls)
	field_book=preload("res://field_book.gd").new()
	root.add_child(field_book)
	field_book.closed.connect(func():
		guide.modulate.a=1.0
		pages.show()
		ControllerInput.focus_first.call_deferred(guide))
	var book_button:=Button.new()
	book_button.text="Open the Field Guide"
	book_button.pressed.connect(func():
		guide.modulate.a=0.0
		pages.hide()
		field_book.open(self))
	pages.add_child(book_button)
	ambience_button=Button.new()
	ambience_button.text="Ambient sounds  ·  on [M]"
	ambience_button.pressed.connect(_toggle_ambience)
	pages.add_child(ambience_button)
	var close := Button.new()
	close.text="Return to the garden"
	close.pressed.connect(_toggle_guide)
	pages.add_child(close)
	if is_instance_valid(get_tree().current_scene) and get_tree().current_scene!=self and get_tree().current_scene.has_method("open_menu"):
		var village_button:=Button.new()
		village_button.text="Visit the village"
		village_button.pressed.connect(get_tree().current_scene.open_village)
		pages.add_child(village_button)
		var back := Button.new()
		back.text="Save & return to main menu"
		back.pressed.connect(get_tree().current_scene.open_menu)
		pages.add_child(back)
		var quit_button:=Button.new()
		quit_button.text="Save & Quit"
		quit_button.pressed.connect(get_tree().current_scene.save_and_quit)
		pages.add_child(quit_button)
	tool_wheel=preload("res://tool_wheel.gd").new()
	root.add_child(tool_wheel)
	tool_wheel.tool_selected.connect(_wheel_selected)
	tool_wheel.cancelled.connect(func(): _set_wheel(false))

func _toggle_guide() -> void:
	_set_guide(not guide.visible)

func _set_guide(open: bool) -> void:
	if is_instance_valid(field_book) and field_book.visible: field_book.close()
	guide.visible=open
	if open: ControllerInput.focus_first.call_deferred(guide)
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused: focused.release_focus()
	if is_instance_valid(tool_wheel): tool_wheel.hide()
	cursor.clear()
	action_pending=false
	pending_bounds=Rect2i()
	aiming=not open
	if is_instance_valid(aim_dot): aim_dot.visible=not open
	selected_target=null
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _select_tool(index: int) -> void:
	tool=clampi(index,0,3)
	action_pending=false
	if is_instance_valid(floating_tool): floating_tool.equip(tool)
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(hud): return
	hud.text=TOOL_NAMES[tool]
	if message!=last_message:
		last_message=message
		toast_timer=3.2
	notice.text=message
	notice.modulate.a=smoothstep(0,0.5,toast_timer)

func _controller_prompts() -> void:
	var pad := ControllerInput.using_pad
	control_hint.text = "Y / Triangle  tools · Menu  pause" if pad else "TAB  tools    ·    ESC  pause"
	guide_controls.text = ("Left stick  glide  ·  Right stick  look\n\nY / Triangle  opens the tool wheel.\nRight trigger  uses the equipped tool.\nA / Cross  confirm  ·  B / Circle  back" if pad else "WASD  glide  ·  Mouse  look\n\nTAB  opens your tool wheel. Click to equip.\nLeft-click to use it above the spirit.") + "\n\nYour garden saves when you leave."
	if field_book.visible: ControllerInput.focus_first.call_deferred(field_book)
	elif guide.visible: ControllerInput.focus_first.call_deferred(guide)
