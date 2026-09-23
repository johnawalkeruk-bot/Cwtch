extends Node3D
## The menu stays alive while the garden runs, preserving its scene and clock.
const Ambience = preload("res://valley_ambience.gd")
const Weather = preload("res://valley_cycle.gd")
const SAVE_PATH := "user://garden.json"
const OPTIONS_PATH := "user://options.json"
var stage: Node3D
var interface: CanvasLayer
var camera: Camera3D
var sun: DirectionalLight3D
var lightning: DirectionalLight3D
var world: WorldEnvironment
var ambience: Node
var sky_material: ShaderMaterial
var scenery_material: ShaderMaterial
var rain: CPUParticles3D
var birds: Array[Node3D] = []
var landscape: Node3D
var garden: Node3D
var village: Node3D
var coins := 500
var purchases: Array = []
var menu_active := true
var elapsed := 1000.0
var weather_elapsed := 0.0
var weather_index := 0
var rain_strength := 0.0
var cloud_cover := 0.3
var flash := 0.0
var storm_wait := 12.0
var thunder_delay := -1.0
var options: PanelContainer
var menu_buttons: VBoxContainer
var heading: VBoxContainer
var weather_label: Label
var loading_label: Label
var new_dialog: ConfirmationDialog
var rng := RandomNumberGenerator.new()
var weather_override := -1

func _ready() -> void:
	get_tree().root.theme = preload("res://cwtch_theme.gd").make()
	get_tree().auto_accept_quit = false
	rng.seed = 1891
	stage = Node3D.new()
	add_child(stage)
	_build_landscape()
	_build_ui()
	ControllerInput.mode_changed.connect(_focus_menu)
	ambience = Ambience.new()
	ambience.stream_level = 0.22
	add_child(ambience)
	_load_options()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_weather(0.0)
	var model_weather := preload("res://model_weather.gd").new()
	stage.add_child(model_weather)
	model_weather.setup(self)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _build_landscape() -> void:
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.position = Vector3(17,16,110)
	camera.look_at(Vector3(-5,31,-80))
	camera.far = 300
	camera.current = true
	sun = DirectionalLight3D.new()
	stage.add_child(sun)
	world = WorldEnvironment.new()
	stage.add_child(world)
	preload("res://welsh_sky.gd").apply(world,sun)
	camera.environment = world.environment
	sky_material = world.environment.sky.sky_material
	world.environment.sky.sky_material = sky_material
	world.environment.fog_enabled = true
	world.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	lightning = DirectionalLight3D.new()
	lightning.rotation_degrees = Vector3(-55,-20,0)
	lightning.light_energy = 0
	stage.add_child(lightning)
	landscape = preload("res://menu_valley_3d.gd").new()
	stage.add_child(landscape)
	landscape.build()
	birds = landscape.birds
	scenery_material = landscape.material
	rain = CPUParticles3D.new()
	rain.position = Vector3(10,40,85)
	rain.amount = 1200
	rain.lifetime = 2.5
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(40,0.1,22)
	rain.direction = Vector3(0.12,-1,0)
	rain.spread = 4
	rain.initial_velocity_min = 10
	rain.initial_velocity_max = 12
	var drop := BoxMesh.new()
	drop.size = Vector3(0.035,0.6,0.035)
	var drop_material := _material(Color(0.65,0.75,0.8,0.35))
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_material
	rain.mesh = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(rain)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _style(color: Color) -> StyleBoxFlat:
	return preload("res://cwtch_theme.gd").panel(color)

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.custom_minimum_size = Vector2(280,51)
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_color_override("font_color",Color("ecdfbd"))
	button.add_theme_stylebox_override("normal",_style(Color(0.08,0.15,0.13,0.89)))
	button.add_theme_stylebox_override("hover",_style(Color(0.22,0.29,0.21,0.97)))
	button.add_theme_stylebox_override("pressed",_style(Color("172a24")))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	interface = CanvasLayer.new()
	add_child(interface)
	var root := Control.new()
	root.theme = preload("res://cwtch_theme.gd").make()
	interface.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading = VBoxContainer.new()
	root.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	heading.offset_left = -300
	heading.offset_right = 300
	heading.offset_top = 146
	var title := _label("CWTCH",112,Color("ffbf55"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial","Segoe UI"])
	font.font_weight = 800
	title.add_theme_font_override("font",font)
	title.add_theme_color_override("font_shadow_color",Color(0.16,0.29,0.31,0.45))
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",3)
	title.add_theme_constant_override("shadow_outline_size",0)
	heading.add_child(title)
	var tagline := _label("Y O U R  S L I C E  O F  T H E\nV A L L E Y.",20,Color("ffbf55"))
	tagline.add_theme_font_override("font",font)
	tagline.add_theme_color_override("font_shadow_color",Color("18251f"))
	tagline.add_theme_constant_override("shadow_offset_y",2)
	heading.add_child(tagline)
	menu_buttons = VBoxContainer.new()
	menu_buttons.add_theme_constant_override("separation",12)
	root.add_child(menu_buttons)
	menu_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu_buttons.offset_left = -150
	menu_buttons.offset_right = 150
	menu_buttons.offset_top = -285
	menu_buttons.offset_bottom = -24
	_button("enter garden",func(): _begin_garden(false),menu_buttons)
	_button("new garden",_request_new,menu_buttons)
	_button("options",func(): options.show(); menu_buttons.hide(); heading.hide(); ControllerInput.focus_first.call_deferred(options),menu_buttons)
	_button("QUIT GAME",save_and_quit,menu_buttons)
	weather_label = _label("",14,Color("66818a"))
	root.add_child(weather_label)
	weather_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	weather_label.offset_left = 24
	weather_label.offset_right = 310
	weather_label.offset_top = -32
	weather_label.offset_bottom = -10
	loading_label = _label("",18,Color("f2e5c4"))
	root.add_child(loading_label)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.offset_left = -220
	loading_label.offset_right = 220
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "A FRESH GARDEN"
	new_dialog.dialog_text = "START AGAIN? THIS REPLACES YOUR SAVED GARDEN."
	new_dialog.confirmed.connect(func(): _begin_garden(true))
	root.add_child(new_dialog)
	new_dialog.get_ok_button().text="START AGAIN"
	new_dialog.get_cancel_button().text="CANCEL"
	options = PanelContainer.new()
	root.add_child(options)
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.offset_left = -220
	options.offset_right = 220
	options.offset_top = -55
	options.add_theme_stylebox_override("panel",_style(Color(0.07,0.13,0.12,0.97)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	options.add_child(box)
	box.add_child(_label("options",24,Color("e2bf6e")))
	box.add_child(_label("Sound volume",16,Color("eee6d0")))
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.min_value = 0
	volume.max_value = 100
	volume.value = 70
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value/100.0,0.0001)))
		_save_options(value))
	box.add_child(volume)
	_button("toggle fullscreen",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_options(volume.value),box)
	var preview := OptionButton.new()
	preview.add_item("WEATHER: NATURAL CYCLE")
	for weather in Weather.WEATHER_NAMES:
		preview.add_item(weather.to_upper())
	preview.item_selected.connect(func(index: int): weather_override = index-1)
	box.add_child(preview)
	_button("back",func(): _close_options(),box)
	options.hide()

func _process(delta: float) -> void:
	if not menu_active:
		return
	elapsed += delta
	_update_weather(delta)

func _update_weather(delta: float) -> void:
	weather_elapsed += delta
	while weather_elapsed >= Weather.WEATHER_DURATIONS[weather_index]:
		weather_elapsed -= Weather.WEATHER_DURATIONS[weather_index]
		weather_index = (weather_index+1)%Weather.WEATHER_NAMES.size()
	var index := weather_index if weather_override < 0 else weather_override
	rain_strength = move_toward(rain_strength,Weather.RAIN_LEVELS[index],delta/12.0)
	cloud_cover = move_toward(cloud_cover,Weather.CLOUD_LEVELS[index],delta/30.0)
	var angle := fposmod(elapsed,Weather.FULL_CYCLE)/Weather.FULL_CYCLE*TAU
	var direction := Vector3(cos(angle),sin(angle),0.25).normalized()
	var daylight := smoothstep(-0.08,0.20,direction.y)
	sun.look_at(-direction,Vector3.UP)
	sun.light_energy = maxf(0.0,direction.y)*1.3*(1-cloud_cover*0.65)
	sun.light_color = Color("ffc18b").lerp(Color("fff0cd"),smoothstep(0,0.5,direction.y))
	var env := world.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("748bb9").lerp(Color("dad7c0"),daylight)
	env.ambient_light_energy = lerpf(0.35,0.8,daylight)
	env.fog_light_color = Color("25384d").lerp(Color("b5b9ac"),daylight)
	env.fog_density = lerpf(0.0018,0.0045,rain_strength)
	sky_material.set_shader_parameter("sun_direction",direction)
	sky_material.set_shader_parameter("daylight",daylight)
	sky_material.set_shader_parameter("cloud_cover",cloud_cover)
	sky_material.set_shader_parameter("cycle_time",elapsed)
	scenery_material.set_shader_parameter("daylight",daylight)
	scenery_material.set_shader_parameter("rain_strength",rain_strength)
	scenery_material.set_shader_parameter("haze_color",env.fog_light_color)
	var count := maxi(1,roundi(1600*Weather.RAIN_LEVELS[index]))
	if rain.amount != count: rain.amount = count
	rain.emitting = rain_strength > 0.03
	rain.mesh.material.albedo_color.a = rain_strength*0.5
	flash = move_toward(flash,0,delta*3.5)
	if thunder_delay >= 0:
		thunder_delay -= delta
		if thunder_delay < 0: ambience.thunder()
	if index == 5 and rain_strength > 0.7:
		storm_wait -= delta
		if storm_wait <= 0:
			flash = 1.1
			thunder_delay = randf_range(1.5,3.5)
			storm_wait = randf_range(16,32)
	else:
		storm_wait = 8
	lightning.light_energy = flash
	landscape.animate(elapsed,daylight,rain_strength)
	camera.position.x = 17+sin(elapsed*0.025)*7
	camera.look_at(Vector3(-5,31,-80))
	sky_material.set_shader_parameter("lightning",flash)
	ambience.update_mix(delta,rain_strength,daylight,false)
	var minutes := int(fposmod(6+elapsed*24/Weather.FULL_CYCLE,24)*60)
	weather_label.text = "%02d:%02d  ·  %s" % [minutes/60,minutes%60,Weather.WEATHER_NAMES[index].to_upper()]

func _request_new() -> void:
	if is_instance_valid(garden) or FileAccess.file_exists(SAVE_PATH):
		new_dialog.popup_centered()
	else:
		_begin_garden(true)

func _begin_garden(fresh: bool) -> void:
	if fresh:
		coins=500
		purchases.clear()
	menu_buttons.hide()
	loading_label.text = "OPENING YOUR GARDEN…"
	await get_tree().process_frame
	await get_tree().process_frame
	if fresh and is_instance_valid(garden):
		remove_child(garden)
		garden.free()
	if not is_instance_valid(garden):
		garden = load("res://main.tscn").instantiate()
		add_child(garden)
		for child in garden.get_children():
			if child is WorldEnvironment: garden.camera.environment = child.environment
		if not fresh: _restore_garden()
	menu_active = false
	stage.hide()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	interface.hide()
	ambience.update_mix(0,rain_strength,1,true)
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.show()
	garden.process_mode = Node.PROCESS_MODE_INHERIT
	garden.camera.make_current()
	garden._set_guide(false)
	_save_garden()
	loading_label.text = ""
	menu_buttons.show()

func open_menu() -> void:
	_save_garden()
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stream_paused = true
	garden.process_mode = Node.PROCESS_MODE_DISABLED
	garden.hide()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.hide()
	stage.show()
	stage.process_mode = Node.PROCESS_MODE_INHERIT
	interface.show()
	camera.make_current()
	menu_active = true
	_focus_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _save_garden() -> bool:
	if not is_instance_valid(garden): return true
	var terrain := []
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x): terrain.append(garden.get_terrain(Vector2i(x,z)))
	var crops := []
	for cell in garden.crops:
		var crop: Dictionary = garden.crops[cell]
		crops.append({"x":cell.x,"z":cell.y,"age":crop.age,"watered":crop.watered})
	var data := {"version":1,"terrain":terrain,"crops":crops,"harvested":garden.harvested,
		"player":[garden.player.cell.x,garden.player.cell.y],"elapsed":garden.valley_cycle.elapsed,
		"weather":garden.valley_cycle.weather_index,"weather_elapsed":garden.valley_cycle.weather_elapsed,
		"wetness":garden.valley_cycle.wetness,"watered":_saved_watered(),"coins":coins,"purchases":purchases}
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	return file.get_error()==OK

func _saved_watered() -> Array:
	var values := []
	for cell in garden.watered_cells:
		values.append([cell.x,cell.y,garden.watered_cells[cell]])
	return values

func _restore_garden() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or data.get("version",0) != 1: return
	var terrain: Array = data.get("terrain",[])
	if terrain.size() != garden.grid_size.x*garden.grid_size.y: return
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x): garden.set_terrain(Vector2i(x,z),clampi(int(terrain[z*garden.grid_size.x+x]),0,7))
	for saved in data.get("crops",[]):
		var cell := Vector2i(int(saved.x),int(saved.z))
		if not garden.contains_cell(cell) or garden.blocked_cells.has(cell): continue
		var plant: Node3D = garden._make_plant(cell)
		garden.crops[cell] = {"node":plant,"age":float(saved.age),"watered":bool(saved.watered)}
		if bool(saved.watered): garden._add_water_ring(plant)
	garden.harvested = int(data.get("harvested",0))
	var cell := Vector2i(int(data.player[0]),int(data.player[1]))
	if garden.contains_cell(cell) and not garden.blocked_cells.has(cell):
		garden.player.cell = cell
		garden.player.target_cell = cell
		garden.player.position = garden.cell_center(cell)
	garden.valley_cycle.elapsed = float(data.get("elapsed",0))
	garden.valley_cycle.weather_index = clampi(int(data.get("weather",0)),0,6)
	garden.valley_cycle.weather_elapsed = float(data.get("weather_elapsed",0))
	garden.valley_cycle.wetness = float(data.get("wetness",0))
	for value in data.get("watered",[]):
		var wet_cell := Vector2i(int(value[0]),int(value[1]))
		if garden.contains_cell(wet_cell):
			garden.watered_cells[wet_cell]=clampf(float(value[2]),0,1)
			garden.watered_image.set_pixel(wet_cell.x,wet_cell.y,Color(garden.watered_cells[wet_cell],0,0))
	garden.watered_texture.update(garden.watered_image)
	coins=maxi(0,int(data.get("coins",500)))
	purchases.clear()
	for record in data.get("purchases",[]):
		if not record is Dictionary or not record.has_all(["id","x","z"]): continue
		if preload("res://village_stock.gd").item(str(record.id)).is_empty(): continue
		if not garden.contains_cell(Vector2i(int(record.x),int(record.z))): continue
		purchases.append(record)
		preload("res://village_stock.gd").deliver(garden,record)
	garden.valley_cycle._update_visuals()
	garden._refresh_ui()

func _save_options(volume: float) -> void:
	var file := FileAccess.open(OPTIONS_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"volume":volume,"fullscreen":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN}))

func _load_options() -> void:
	var volume := 70.0
	if FileAccess.file_exists(OPTIONS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(OPTIONS_PATH))
		if data is Dictionary:
			volume = clampf(float(data.get("volume",70)),0,100)
			if data.get("fullscreen",false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume/100,0.0001)))
	options.find_child("Volume",true,false).set_value_no_signal(volume)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_and_quit()

func _focus_menu() -> void:
	if menu_active:
		ControllerInput.focus_first.call_deferred(options if options.visible else menu_buttons)

func _close_options() -> void:
	options.hide()
	menu_buttons.show()
	heading.show()
	_focus_menu()

func _unhandled_input(event: InputEvent) -> void:
	if menu_active and event.is_action_pressed("ui_cancel") and options.visible:
		_close_options()
		get_viewport().set_input_as_handled()

func save_and_quit() -> void:
	if not _save_garden():
		if is_instance_valid(garden):
			garden.message="Could not save your garden. Please try again."
			garden._refresh_ui()
		else: loading_label.text="COULD NOT SAVE. PLEASE TRY AGAIN."
		return
	get_tree().quit()

func open_village() -> void:
	if not is_instance_valid(garden) or is_instance_valid(village): return
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false): audio.stream_paused=true
	garden.process_mode=Node.PROCESS_MODE_DISABLED
	garden.hide()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.hide()
	village=preload("res://village.tscn").instantiate()
	add_child(village)
	village.activate(self)

func return_from_village() -> void:
	if not is_instance_valid(village): return
	village.free()
	village=null
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.show()
	garden.process_mode=Node.PROCESS_MODE_INHERIT
	garden.camera.make_current()
	garden._set_guide(false)
	_save_garden()

func purchase_village_item(id: String) -> String:
	var item: Dictionary=preload("res://village_stock.gd").item(id)
	if item.is_empty(): return "That item is unavailable."
	if coins<int(item.price): return "There are not enough coins in your purse."
	var cell: Vector2i=preload("res://village_stock.gd").find_space(garden,id)
	if cell.x<0: return "Your garden needs more clear ground for this delivery."
	var record: Dictionary={"id":id,"x":cell.x,"z":cell.y}
	coins-=int(item.price)
	purchases.append(record)
	if not _save_garden():
		coins+=int(item.price)
		purchases.pop_back()
		return "The purchase could not be saved. No coins were spent."
	preload("res://village_stock.gd").deliver(garden,record)
	return "%s delivered to your garden.\n%d coins remaining."%[item.name,coins]
