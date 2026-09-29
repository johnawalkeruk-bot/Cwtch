extends Node
## Two cameras render the same World3D. Simulation and saves remain shared.
var world: Node3D
var village := false
var second: Node3D
var split := false
var rendering := false
var layer: CanvasLayer
var views: Array[SubViewport]=[]
var cameras: Array[Camera3D]=[]
var labels: Array[Label]=[]
var notes: Array[Label]=[]
var dots: Array[Label]=[]
var clocks: Array[Control]=[]

func setup(scene: Node3D, in_village: bool=false) -> void:
	world=scene
	village=in_village
	process_priority=100
	second=preload("res://coop_spirit.gd").new()
	world.add_child(second)
	second.setup(world,village)
	layer=CanvasLayer.new()
	layer.name="LocalSplitScreen"
	layer.layer=-1
	add_child(layer)
	var row := HBoxContainer.new()
	layer.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",3)
	for index in 2:
		var container := SubViewportContainer.new()
		container.stretch=true
		container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		container.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(container)
		var view := SubViewport.new()
		view.world_3d=world.get_world_3d()
		view.handle_input_locally=false
		view.gui_disable_input=true
		view.audio_listener_enable_3d=true
		container.add_child(view)
		views.append(view)
		var cam := Camera3D.new()
		view.add_child(cam)
		cam.make_current()
		cameras.append(cam)
		var ui := CanvasLayer.new()
		view.add_child(ui)
		var title := Label.new()
		var card := PanelContainer.new()
		card.theme=preload("res://cwtch_theme.gd").make()
		card.add_theme_stylebox_override("panel",preload("res://cwtch_theme.gd").compact_card())
		card.position=Vector2(24,24)
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ui.add_child(card)
		card.add_child(title)
		title.add_theme_font_size_override("font_size",17)
		title.add_theme_color_override("font_color",Color("f4c568") if index==0 else Color("ffd45a"))
		title.add_theme_color_override("font_shadow_color",Color("14231f"))
		title.add_theme_constant_override("shadow_offset_y",2)
		labels.append(title)
		var note := Label.new()
		ui.add_child(note)
		note.position=Vector2(24,237)
		note.add_theme_font_size_override("font_size",14)
		note.add_theme_color_override("font_shadow_color",Color.BLACK)
		note.add_theme_constant_override("shadow_offset_y",2)
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		notes.append(note)
		var dot := Label.new()
		ui.add_child(dot)
		dot.text="·"
		dot.add_theme_font_size_override("font_size",24)
		dots.append(dot)
		var clock:=preload("res://petal_clock.gd").new()
		ui.add_child(clock)
		clock.setup(world,index,village)
		clocks.append(clock)
	if not village:
		var wheel_layer:=CanvasLayer.new()
		wheel_layer.layer=21
		world.add_child(wheel_layer)
		second.tool_wheel=preload("res://tool_wheel.gd").new()
		second.tool_wheel.player_slot=1
		wheel_layer.add_child(second.tool_wheel)
		second.tool_wheel.attach_clock(world,1)
		second.tool_wheel.tool_selected.connect(func(index: int):
			second.clear_use()
			second.floating_tool.equip(index)
			if index==3:second.tool_wheel.open_modes(second.floating_tool.shovel_mode)
			else:second.set_wheel(false))
		second.tool_wheel.mode_selected.connect(func(index: int):
			second.floating_tool.shovel_mode=index
			second.set_wheel(false))
		second.tool_wheel.cancelled.connect(func(): second.set_wheel(false))
	layer.hide()
	ControllerInput.players_changed.connect(_players_changed)
	_players_changed()

func _players_changed() -> void:
	split=ControllerInput.secondary_device()>=0
	second.set_enabled(split)
	if not village:
		world._set_wheel(false)
		second.set_wheel(false)
	if not split:suspend_render()

func suspend_render() -> void:
	if rendering:
		get_viewport().disable_3d=false
		get_viewport().audio_listener_enable_3d=true
	rendering=false
	if is_instance_valid(layer):layer.hide()
	for view in views:view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	suspend_render()

func _process(_delta: float) -> void:
	if not village:
		var screen:=get_viewport().get_visible_rect().size
		world.tool_wheel.position=Vector2.ZERO
		world.tool_wheel.size=Vector2(screen.x*0.5,screen.y) if split else screen
		second.tool_wheel.position=Vector2(screen.x*0.5,0)
		second.tool_wheel.size=Vector2(screen.x*0.5,screen.y)
	var fullscreen_scene: bool=world.current_shop>=0 if village else world.hedgehog_intro.active
	var visible_split: bool=split and world.is_visible_in_tree() and not fullscreen_scene
	if not visible_split:
		suspend_render()
	else:
		rendering=true
		get_viewport().disable_3d=true
		get_viewport().audio_listener_enable_3d=false
		layer.show()
		for i in 2:
			views[i].render_target_update_mode=SubViewport.UPDATE_ALWAYS
			var source: Camera3D=world.camera if i==0 else second.camera
			cameras[i].global_transform=source.global_transform
			cameras[i].fov=source.fov
			cameras[i].near=source.near
			cameras[i].far=source.far
			cameras[i].environment=world.camera.environment
			cameras[i].attributes=source.attributes
			var forward: Vector3=-source.global_basis.z
			var bearing := fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)
			var heading: String=["N","NE","E","SE","S","SW","W","NW"][int(round(bearing/45.0))%8]
			var text := "PLAYER %d   ·   %s  %03d°" % [i+1,heading,int(bearing)]
			if not village:
				var tool: Node3D=world.floating_tool if i==0 else second.floating_tool
				text+="\n"+world.TOOL_NAMES[tool.selected]
				if tool.selected==3:text+=" · "+tool.MODES[tool.shovel_mode]
			else:text+="\nThe village · %d coins"%world.host.coins
			labels[i].text=text
			labels[i].get_parent().position=Vector2(maxf(328,views[i].size.x-265),24)
			labels[i].custom_minimum_size=Vector2(200,0)
			labels[i].autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			clocks[i].visible=not fullscreen_scene
			labels[i].get_parent().visible=not (world.paused or world.current_shop>=0) if village else not world.guide.visible and not world.field_book.visible
			dots[i].visible=not second.blocked()
			dots[i].position=Vector2(views[i].size)*0.5-Vector2(4,16)
			notes[i].size=Vector2(maxf(100,views[i].size.x-40),70)
			notes[i].visible=not second.blocked()
			if village:
				var shop: int=world.selected_shop if i==0 else second.selected_shop
				notes[i].text=world.SHOPS[shop] if shop>=0 else ""
			else:notes[i].text=(world.message if world.toast_timer>0 else "") if i==0 else (second.message if second.message_time>0 else "")
	# The full-screen menus, clock, guide and animal notices remain shared overlays.
	world.hud.get_parent().get_parent().visible=not visible_split
	world.hud.get_parent().get_parent().position=Vector2(get_viewport().get_visible_rect().size.x-265,24)
	world.clock_ui.visible=not visible_split and (not world.host.garden.field_book.visible if village else not world.field_book.visible)
	world.compass_view.visible=not visible_split and (not world.paused and world.current_shop<0 if village else not world.guide.visible and not world.hedgehog_intro.active)
	if village:world.prompt.visible=not visible_split and world.current_shop<0
	else:
		world.aim_dot.visible=not visible_split and not world.guide.visible
		world.notice.visible=not visible_split and not world.guide.visible

func route_input(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton and not event is InputEventJoypadMotion:return false
	if event.device not in [ControllerInput.primary_device(),ControllerInput.secondary_device()]:return true
	# Shared modal UI accepts either controller. Gameplay has fixed controller owners.
	if second.blocked():return false
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_START:return false
	if event.device==ControllerInput.secondary_device() and split:
		second.handle_input(event)
		get_viewport().set_input_as_handled()
		return true
	return event.device!=ControllerInput.primary_device()
