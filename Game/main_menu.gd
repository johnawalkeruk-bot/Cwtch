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
var weather_pattern := preload("res://weather_pattern.gd").new()
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
var cloud: Node
var account_panel: PanelContainer
var autosave_age := 0.0
var account_status: CanvasLayer
var autosave_sync_pending:=false
var autosave_writing:=false
var quitting := false
var loading := false
var garden_loader: CanvasLayer
var valley_music: Node

func _ready() -> void:
	get_tree().root.theme = preload("res://cwtch_theme.gd").make()
	get_tree().auto_accept_quit = false
	rng.seed = 1891
	stage = Node3D.new()
	add_child(stage)
	_build_landscape()
	cloud=preload("res://cloud_account.gd").new()
	add_child(cloud)
	_build_ui()
	account_status=preload("res://account_status.gd").new()
	add_child(account_status)
	account_status.setup(self)
	cloud.sync_finished.connect(_autosave_sync_finished)
	cloud.restore_login.call_deferred()
	garden_loader=preload("res://garden_loading.gd").new()
	add_child(garden_loader)
	ControllerInput.mode_changed.connect(_focus_menu)
	ambience = Ambience.new()
	ambience.stream_level = 0.22
	add_child(ambience)
	valley_music=preload("res://valley_music.gd").new()
	add_child(valley_music)
	valley_music.setup(self)
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
	camera.position = Vector3(12,16,62)
	camera.look_at(Vector3(-5,27,-110))
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
	var studio := TextureRect.new()
	studio.texture=preload("res://assets/branding/wgs.png")
	studio.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	studio.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	studio.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	studio.offset_left=-155;studio.offset_right=-15;studio.offset_top=-150;studio.offset_bottom=-10
	heading = VBoxContainer.new()
	root.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	heading.offset_left = -300
	heading.offset_right = 300
	heading.offset_top = 130
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
	menu_buttons.offset_left = -180
	menu_buttons.offset_right = 180
	menu_buttons.offset_top = -330
	menu_buttons.offset_bottom = -24
	_button("enter garden",func(): _begin_garden(false),menu_buttons)
	_button("new garden",_request_new,menu_buttons)
	_button("options",func(): UISounds.play("open"); options.show(); menu_buttons.hide(); heading.hide(); ControllerInput.focus_first.call_deferred(options),menu_buttons)
	_button("ACCOUNT & CLOUD",_open_account,menu_buttons)
	_button("QUIT GAME",save_and_quit,menu_buttons)
	account_panel=preload("res://account_panel.gd").new()
	root.add_child(account_panel)
	account_panel.setup(self,cloud)
	weather_label = _label("",14,Color("e5c17c"))
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
	options.offset_left = -270
	options.offset_right = 270
	options.offset_top = -295
	options.offset_bottom = 295
	options.add_theme_stylebox_override("panel",_style(Color(0.07,0.13,0.12,0.97)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	var scroll:=ScrollContainer.new()
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var options_layout:=VBoxContainer.new()
	options.add_child(options_layout)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	options_layout.add_child(scroll)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label("OPTIONS",24,Color("e2bf6e")))
	for bus in ["Master","Music","UI","Ambience","Sound effects","Speech"]:
		var row:=HBoxContainer.new()
		var audio_title:=_label(bus,15,Color("eee6d0"))
		audio_title.custom_minimum_size.x=140;audio_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(audio_title)
		var slider:=HSlider.new()
		slider.name="UISFXVolume" if bus=="UI" else ("Volume" if bus=="Master" else bus.replace(" ","")+"Volume")
		slider.max_value=100;slider.step=1;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size=Vector2(180,30)
		slider.value=(UISounds.volume if bus=="UI" else float(AudioSettings.levels[bus]))*100.0
		slider.tooltip_text=bus+" volume"
		var amount:=_label(str(roundi(slider.value))+"%",15,Color("e2bf6e"));amount.custom_minimum_size.x=48
		slider.value_changed.connect(func(value: float):
			amount.text=str(roundi(value))+"%"
			if bus=="UI":UISounds.set_volume(value/100.0)
			else:AudioSettings.set_level(bus,value/100.0);UISounds.play("volume-change"))
		row.add_child(slider);row.add_child(amount);box.add_child(row)
	var ui_enabled:=CheckButton.new();ui_enabled.name="UISFXEnabled";ui_enabled.text="Interface sounds";ui_enabled.button_pressed=UISounds.enabled
	ui_enabled.toggled.connect(UISounds.set_enabled);box.add_child(ui_enabled)
	box.add_child(_label("Interface sound style",16,Color("eee6d0")))
	var ui_pack:=OptionButton.new();ui_pack.name="UISFXPack"
	for value in UISounds.PACKS:ui_pack.add_item(str(value).capitalize())
	ui_pack.select(UISounds.PACKS.find(UISounds.pack))
	ui_pack.item_selected.connect(func(index: int):UISounds.set_pack(UISounds.PACKS[index]));box.add_child(ui_pack)
	var ui_typing:=CheckButton.new();ui_typing.name="UISFXTyping";ui_typing.text="Quiet typing sounds (optional)";ui_typing.button_pressed=UISounds.typing
	ui_typing.toggled.connect(UISounds.set_typing);box.add_child(ui_typing)
	_button("toggle fullscreen",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_options(float(AudioSettings.levels.Master)*100.0),box)
	var preview := OptionButton.new()
	preview.add_item("WEATHER: NATURAL CYCLE")
	for weather in Weather.WEATHER_NAMES:
		preview.add_item(weather.to_upper())
	preview.item_selected.connect(func(index: int): weather_override = index-1)
	box.add_child(preview)
	_button("back",func(): _close_options(),options_layout)
	options.hide()

func _process(delta: float) -> void:
	if loading:return
	if not menu_active and is_instance_valid(garden):autosave_age+=delta
	if autosave_age>=300.0 and is_instance_valid(garden):
		autosave_age=0.0
		_autosave()
	if not menu_active:
		return
	elapsed += delta
	_update_weather(delta)

func _update_weather(delta: float) -> void:
	var next := weather_pattern.advance(weather_index,weather_elapsed,delta)
	weather_index=int(next[0])
	weather_elapsed=float(next[1])
	var index := weather_index if weather_override < 0 else weather_override
	rain_strength = move_toward(rain_strength,Weather.RAIN_LEVELS[index],delta/12.0)
	cloud_cover = move_toward(cloud_cover,Weather.CLOUD_LEVELS[index],delta/30.0)
	var angle := fposmod(elapsed,Weather.FULL_CYCLE)/Weather.FULL_CYCLE*TAU
	var direction := Vector3(cos(angle),sin(angle),0.25).normalized()
	var daylight := smoothstep(-0.08,0.20,direction.y)
	sun.look_at(-direction,Vector3.UP)
	var env := world.environment
	preload("res://valley_lighting.gd").update(env,sun,direction.y,daylight,cloud_cover)
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
	camera.look_at(Vector3(-5,27,-110))
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
	if loading:return
	UISounds.stop_all()
	loading=true
	autosave_age=0.0
	if ControllerKeyboard.opened:ControllerKeyboard.finish(false)
	garden_loader.begin()
	ambience.update_mix(0,0,0,true)
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
		var error := ResourceLoader.load_threaded_request("res://main.tscn")
		if error!=OK:
			_loading_failed()
			return
		while ResourceLoader.load_threaded_get_status("res://main.tscn")==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status("res://main.tscn")!=ResourceLoader.THREAD_LOAD_LOADED:
			_loading_failed()
			return
		var scene: PackedScene=ResourceLoader.load_threaded_get("res://main.tscn")
		garden = scene.instantiate()
		garden.process_mode=Node.PROCESS_MODE_DISABLED
		garden.set_meta("loading_screen",garden_loader)
		add_child(garden)
		while not garden.loading_complete:
			await get_tree().process_frame
		garden.remove_meta("loading_screen")
		for child in garden.get_children():
			if child is WorldEnvironment: garden.camera.environment = child.environment
		if not fresh: _restore_garden()
	menu_active = false
	stage.hide()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	interface.hide()
	ambience.update_mix(0,rain_strength,1,true)
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false):
		if layer!=garden.hedgehog_intro.ui:layer.show()
	garden.process_mode = Node.PROCESS_MODE_DISABLED
	garden.camera.make_current()
	garden._set_guide(false)
	garden.local_coop.suspend_render()
	preload("res://diorama_camera.gd").follow(garden.camera,garden.player.position,garden.camera_yaw,garden.camera_pitch)
	# Prepare the first walking view, but keep its clock frozen behind the reveal.
	if fresh:
		garden.northern_arrival.start()
		garden.northern_arrival.set_process(false)
	# Reveal a ready, stationary garden before starting its arrival/dialogue.
	await get_tree().process_frame
	await garden_loader.finish()
	loading=false
	garden.process_mode=Node.PROCESS_MODE_INHERIT
	if fresh: garden.northern_arrival.set_process(true)
	else: garden.hedgehog_intro.request_welcome()
	_save_garden()
	loading_label.text = ""
	menu_buttons.show()

func open_menu() -> void:
	UISounds.stop_all()
	_save_garden()
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stream_paused = true
	garden.local_coop.suspend_render()
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

func _save_garden(sync_cloud: bool=true) -> bool:
	account_status.begin_save()
	var saved:=_write_garden(sync_cloud)
	account_status.end_save()
	return saved

func _write_garden(sync_cloud: bool=true) -> bool:
	if not is_instance_valid(garden): return true
	for actor in garden.additional_visitors:
		if is_instance_valid(actor) and actor.has_meta("purchase_record"):
			var record: Dictionary=actor.get_meta("purchase_record")
			var cell: Vector2i=garden.local_to_cell(actor.position)
			record.x=cell.x;record.z=cell.y;record.yaw=actor.visual.rotation.y
	var terrain := []
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x): terrain.append(garden.get_terrain(Vector2i(x,z)))
	var crops := []
	for cell in garden.crops:
		var crop: Dictionary = garden.crops[cell]
		crops.append({"x":cell.x,"z":cell.y,"age":crop.age,"watered":crop.watered})
	var data := {"version":1,"terrain":terrain,"crops":crops,"harvested":garden.harvested,
		"player":[garden.player.cell.x,garden.player.cell.y],"player_position":[garden.player.position.x,garden.player.position.z],"elapsed":garden.valley_cycle.elapsed,
		"weather_pattern":garden.valley_cycle.weather_pattern.save_data(),"weather":garden.valley_cycle.weather_index,"weather_elapsed":garden.valley_cycle.weather_elapsed,
		"experience":garden.experience.save_data(),"local_coop":garden.local_coop.second.save_data(),"deformation":garden.heightfield.save_deformation(),"wildlife":garden.wildlife.save_data(),"hedgehog_intro":garden.hedgehog_intro.save_data(),"wetness":garden.valley_cycle.wetness,"watered":_saved_watered(),"coins":coins,"purchases":purchases}
	data["summary"]=_cloud_summary()
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var success := file.get_error()==OK
	file.close()
	if not success:return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH+".tmp"),ProjectSettings.globalize_path(SAVE_PATH))!=OK:return false
	if sync_cloud:cloud.sync(data)
	return true

func _saved_watered() -> Array:
	var values := []
	for cell in garden.watered_cells:
		if float(garden.watered_cells[cell])<=0.0:continue
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
	garden.heightfield.restore_deformation(data.get("deformation",{}))
	garden.experience.restore(data.get("experience",{}))
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
	var free_position = data.get("player_position",[])
	if free_position is Array and free_position.size()==2:
		garden.player.restore_position(Vector3(float(free_position[0]),0,float(free_position[1])))
	garden.valley_cycle.elapsed = float(data.get("elapsed",0))
	garden.valley_cycle.weather_index = clampi(int(data.get("weather",0)),0,6)
	garden.valley_cycle.weather_elapsed = garden.valley_cycle.weather_pattern.restore(data.get("weather_pattern",{}),garden.valley_cycle.weather_index,float(data.get("weather_elapsed",0)))
	garden.valley_cycle.wetness = float(data.get("wetness",0))
	for value in data.get("watered",[]):
		var wet_cell := Vector2i(int(value[0]),int(value[1]))
		if garden.contains_cell(wet_cell):
			garden.watered_cells[wet_cell]=clampf(float(value[2]),0,1)
			garden.watered_image.set_pixel(wet_cell.x,wet_cell.y,Color(garden.watered_cells[wet_cell],0,0))
	garden.watered_texture.update(garden.watered_image)
	coins=maxi(0,int(data.get("coins",500)))
	garden.wildlife.suppress_events=true
	garden.wildlife.restore(data.get("wildlife",{}))
	garden.hedgehog_intro.restore(data.get("hedgehog_intro",{}))
	purchases.clear()
	for record in data.get("purchases",[]):
		if not record is Dictionary or not record.has_all(["id","x","z"]): continue
		if preload("res://village_stock.gd").item(str(record.id)).is_empty(): continue
		if not garden.contains_cell(Vector2i(int(record.x),int(record.z))): continue
		purchases.append(record)
		preload("res://village_stock.gd").deliver(garden,record)
	garden.local_coop.second.restore(data.get("local_coop",{}))
	garden.wildlife.suppress_events=false
	garden.valley_cycle._update_visuals()
	garden._refresh_ui()

func _save_options(volume: float) -> void:
	AudioSettings.set_level("Master",volume/100.0)
	var data: Dictionary=AudioSettings.read_options()
	data["fullscreen"]=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	data["ui_sfx"]=UISounds.preferences()
	var file:=FileAccess.open(OPTIONS_PATH,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(data))

func _load_options() -> void:
	var data: Dictionary=AudioSettings.read_options()
	if data.get("fullscreen",false):DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_and_quit()

func _focus_menu() -> void:
	if loading:return
	if ControllerKeyboard.opened:return
	if is_instance_valid(account_status) and account_status.popup.visible:return
	if menu_active:
		ControllerInput.focus_first.call_deferred(account_panel if account_panel.visible else (options if options.visible else menu_buttons))

func _close_options() -> void:
	if options.visible:UISounds.play("close")
	options.hide()
	menu_buttons.show()
	heading.show()
	_focus_menu()

func _unhandled_input(event: InputEvent) -> void:
	if menu_active and event.is_action_pressed("ui_cancel") and account_panel.visible and not cloud.busy:
		account_panel.hide()
		menu_buttons.show()
		heading.show()
		_focus_menu()
		get_viewport().set_input_as_handled()
		return
	if menu_active and event.is_action_pressed("ui_cancel") and options.visible:
		_close_options()
		get_viewport().set_input_as_handled()

func save_and_quit() -> void:
	if loading:
		garden_loader.abort()
		get_tree().quit()
		return
	if quitting:return
	if not _save_garden():
		if is_instance_valid(garden):
			garden.message="Could not save your garden. Please try again."
			garden._refresh_ui()
		else: loading_label.text="COULD NOT SAVE. PLEASE TRY AGAIN."
		return
	quitting=true
	var deadline := Time.get_ticks_msec()+18000
	while cloud.busy and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	get_tree().quit()

func open_village() -> void:
	UISounds.stop_all()
	if not is_instance_valid(garden) or is_instance_valid(village): return
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false): audio.stream_paused=true
	garden.local_coop.suspend_render()
	garden.process_mode=Node.PROCESS_MODE_DISABLED
	garden.hide()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.hide()
	village=preload("res://village.tscn").instantiate()
	add_child(village)
	village.activate(self)

func return_from_village(welcome: bool=true) -> void:
	if not is_instance_valid(village): return
	garden.valley_cycle.active_ambience=null
	village.free()
	village=null
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false):
		if layer!=garden.hedgehog_intro.ui:layer.show()
	garden.process_mode=Node.PROCESS_MODE_INHERIT
	garden.camera.make_current()
	garden._set_guide(false)
	if welcome:garden.hedgehog_intro.request_welcome()
	_save_garden()

func purchase_village_item(id: String, player_slot: int=0) -> String:
	var item: Dictionary=preload("res://village_stock.gd").item(id)
	if item.is_empty():return "That item is unavailable."
	if coins<int(item.price):return "There are not enough coins in your purse."
	if id=="hedgehog" and garden.wildlife.grass_ratio()<0.01:return "Hedgehogs need at least 1% grass before visiting."
	_begin_purchase_preview.call_deferred(id,player_slot)
	return "Choose where to place it in your garden. Coins are charged when you confirm."

func _begin_purchase_preview(id: String, player_slot: int=0) -> void:
	return_from_village(false)
	if player_slot==1 and garden.local_coop.second.enabled: garden.local_coop.second.placement.begin_purchase(id)
	else:garden.placement.begin_purchase(id)

func confirm_garden_purchase(id: String, cell: Vector2i, yaw: float) -> String:
	var stock=preload("res://village_stock.gd")
	var item: Dictionary=stock.item(id)
	if item.is_empty() or coins<int(item.price):return "There are not enough coins in your purse."
	if id=="hedgehog" and garden.wildlife.grass_ratio()<0.01:return "Hedgehogs still need at least 1% grass before visiting."
	var problem: String=stock.placement_error(garden,id,cell,yaw)
	if not problem.is_empty():return problem
	var record: Dictionary={"id":id,"x":cell.x,"z":cell.y,"yaw":yaw}
	coins-=int(item.price);purchases.append(record)
	if not _save_garden(false):
		coins+=int(item.price);purchases.pop_back()
		return "The purchase could not be saved. No coins were spent."
	stock.deliver(garden,record)
	_save_garden()
	return ""

func _open_account() -> void:
	UISounds.play("open")
	menu_buttons.hide()
	heading.hide()
	account_panel.show()
	account_panel.refresh()
	ControllerInput.focus_first.call_deferred(account_panel)
func use_cloud_garden(data: Variant) -> void:
	if not preload("res://cloud_save_validator.gd").valid(data):
		cloud.status="Cloud save is incompatible or damaged. Local garden unchanged."
		cloud.changed.emit()
		return
	if FileAccess.file_exists(SAVE_PATH):
		var backup := SAVE_PATH+".before-cloud-"+str(Time.get_ticks_usec())+".json"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(backup))!=OK:
			cloud.status="Could not make a backup. Local garden unchanged."
			cloud.changed.emit()
			return
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if not file:cloud.status="Could not write cloud garden.";cloud.changed.emit();return
	file.store_string(JSON.stringify(data));file.flush()
	var success := file.get_error()==OK
	file.close()
	if not success or DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH+".tmp"),ProjectSettings.globalize_path(SAVE_PATH))!=OK:
		cloud.status="Could not replace local save.";cloud.changed.emit();return
	if is_instance_valid(garden):garden.free();garden=null
	valley_music.silence()
	valley_music.band=""
	cloud.connected=true
	cloud.remember()
	cloud.status="Cloud garden ready. Choose ENTER GARDEN. Previous local save backed up."
	cloud.changed.emit()
func _cloud_summary() -> Dictionary:
	var population := 0
	for actor in garden.get_children():
		if actor is Node3D and actor.visible and actor.has_meta("animal_id"):
			if actor==garden.wildlife.hedgehog and actor.visit_state!="inside":continue
			if actor==garden.wildlife.robin and not garden.wildlife.records.has("robin"):continue
			population+=1
	return {"animals":population,"day":garden.wildlife.day(),"level":garden.experience.level()}

func _loading_failed() -> void:
	garden_loader.abort()
	loading=false
	menu_buttons.show()
	loading_label.text="COULD NOT OPEN THE GARDEN. PLEASE TRY AGAIN."
	_focus_menu()

func _autosave() -> void:
	if autosave_writing:return
	autosave_writing=true
	account_status.begin_save()
	await get_tree().process_frame
	if not _save_garden(false):
		autosave_writing=false
		account_status.end_save()
		account_status.show_toast("Could not save garden · please check available disk space")
		return
	autosave_writing=false
	account_status.end_save()
	account_status.show_toast("Garden saved locally · syncing…" if not cloud.token.is_empty() else "Garden saved locally · offline")
	autosave_sync_pending=true
	var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	cloud.sync(data)

func _autosave_sync_finished(_ok: bool, message: String) -> void:
	if not autosave_sync_pending:return
	autosave_sync_pending=false
	account_status.show_toast(message)
