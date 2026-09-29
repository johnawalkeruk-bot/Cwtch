extends Node3D
const SelectionTarget=preload("res://selection_target.gd")
## A second actor, sharing terrain and simulation but never input or tool state.
var world: Node3D
var village := false
var enabled := false
var release_required := true
var player: CharacterBody3D
var cursor: Node3D
var camera: Camera3D
var floating_tool: Node3D
var camera_yaw := 0.0
var camera_pitch := PI/4.0
var message := "Welcome, player two."
var message_time := 0.0
var selected_shop := -1
var guide: Control:
	get: return world.guide
var tool_wheel: Control
var dev_console: CanvasLayer:
	get: return world.dev_console

func setup(scene: Node3D, in_village: bool) -> void:
	world=scene
	village=in_village
	name="PlayerTwo"
	if village:
		player=CharacterBody3D.new()
		player.collision_layer=0
		player.collision_mask=1
		add_child(player)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius=0.28
		shape.shape=sphere
		shape.position.y=0.4
		player.add_child(shape)
		player.position=Vector3(1,0,16)
	else:
		player=preload("res://third_person_player.gd").new()
		add_child(player)
		player.setup(world)
		place_near_player_one()
	cursor=preload("res://gliding_cursor.gd").new()
	cursor.top_color=Color("fff02b")
	cursor.side_color=Color("ef181b")
	cursor.bottom_color=Color("c90f16")
	add_child(cursor)
	cursor.surface_height=func(point: Vector2) -> float: return 0.0 if village else world.heightfield.surface_at(point)
	camera=Camera3D.new()
	camera.fov=world.camera.fov
	camera.near=world.camera.near
	camera.far=world.camera.far
	add_child(camera)
	camera.current=false
	if not village:
		floating_tool=preload("res://floating_tool.gd").new()
		add_child(floating_tool)
		floating_tool.setup(self)
		floating_tool.effect_applied.connect(_apply_tool)
	set_enabled(false)

func place_near_player_one() -> void:
	for offset in [Vector3(0.9,0,0),Vector3(-0.9,0,0),Vector3(0,0,0.9),Vector3.ZERO]:
		var point: Vector3=world.player.position+offset
		if player._allowed(point):
			player.restore_position(point)
			return

func set_enabled(value: bool) -> void:
	enabled=value
	visible=value
	clear_use()
	if is_instance_valid(floating_tool):floating_tool.process_mode=Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func clear_use() -> void:
	release_required=true
	if is_instance_valid(player):player.velocity=Vector3.ZERO
	if is_instance_valid(floating_tool):floating_tool.cancel_use()

func blocked() -> bool:
	if not enabled:return true
	if village:return world.paused or world.current_shop>=0
	return world.guide.visible or world.field_book.visible or world.dev_console.opened or world.hedgehog_intro.active or (is_instance_valid(tool_wheel) and tool_wheel.visible)

func cell_center(cell: Vector2i) -> Vector3:
	return world.cell_center(cell)

func _apply_tool(cell: Vector2i, tool: int, mode: int) -> void:
	if blocked():return
	message=world._tool_result(cell,tool,mode)
	message_time=3.2

func handle_input(event: InputEvent) -> void:
	if blocked() or not event is InputEventJoypadButton or not event.pressed:return
	if village:
		if event.button_index==JOY_BUTTON_A and selected_shop>=0:world.enter_shop(selected_shop)
		return
	if event.button_index==JOY_BUTTON_A:
		set_wheel(true)
		return
	var tool_map := {JOY_BUTTON_DPAD_UP:0,JOY_BUTTON_DPAD_RIGHT:1,JOY_BUTTON_DPAD_DOWN:2,JOY_BUTTON_DPAD_LEFT:3,JOY_BUTTON_B:4}
	if tool_map.has(event.button_index):
		clear_use()
		floating_tool.equip(tool_map[event.button_index])
	elif event.button_index==JOY_BUTTON_X and floating_tool.selected==3:
		floating_tool.shovel_mode=posmod(floating_tool.shovel_mode+1,4)
	elif event.button_index==JOY_BUTTON_RIGHT_STICK:world._trigger_tardis()

func _physics_process(delta: float) -> void:
	if not enabled:return
	if blocked():
		clear_use()
		cursor.clear()
		if is_instance_valid(floating_tool):floating_tool.hide()
		return
	message_time=maxf(0,message_time-delta)
	var id: int=ControllerInput.secondary_device()
	var use := ControllerInput.use_held(id)
	if not use:release_required=false
	var look := ControllerInput.look(id)
	camera_yaw-=look.x*1.8*delta
	camera_pitch=clampf(camera_pitch+look.y*1.5*delta,deg_to_rad(-80),deg_to_rad(80))
	if village:
		var move := ControllerInput.movement(id)
		player.velocity=Basis(Vector3.UP,camera_yaw)*Vector3(move.x,0,move.y)*3.0
		player.move_and_slide()
		player.position.x=clampf(player.position.x,-12,12)
		player.position.z=clampf(player.position.z,-24,19)
		player.position.y=0
	else:player.advance(delta,ControllerInput.movement(id),camera_yaw)
	preload("res://diorama_camera.gd").follow(camera,player.position,camera_yaw,camera_pitch)
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*(24.0 if village else 100.0),17 if village else 3)
	query.collide_with_areas=true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if village:
		selected_shop=int(hit.collider.get_meta("shop",-1)) if not hit.is_empty() else -1
		cursor.follow_feet(player.position,Vector2.ONE*0.7,delta)
		if selected_shop>=0:
			cursor.follow_object(Vector3(-7 if selected_shop%2==0 else 7,0,-10 if selected_shop<2 else 4),Vector2.ONE*6.4,delta)
			if use and not release_required:
				release_required=true
				world.enter_shop(selected_shop)
		return
	var target: Area3D=null
	if not floating_tool.busy and not hit.is_empty() and hit.collider is SelectionTarget:target=hit.collider
	if floating_tool.busy:cursor.follow_object(floating_tool.target_point,Vector2.ONE*world.MICRO_SIZE,delta)
	elif is_instance_valid(target):cursor.follow_object(world.to_local(target.subject.global_position),target.selection_size(),delta)
	else:cursor.follow_feet(player.position,Vector2.ONE*world.MICRO_SIZE,delta)
	if use and not release_required and not floating_tool.busy:
		if is_instance_valid(target) and not world.contains_cell(target.crop_cell):
			message=target.subject.get_meta("inspection_text",target.label+" is enjoying the valley.")
			message_time=3.2
		elif not world.blocked_cells.has(player.cell):
			floating_tool.use_at(target.crop_cell if is_instance_valid(target) else player.cell)

func save_data() -> Dictionary:
	return {"position":[player.position.x,player.position.z],"tool":floating_tool.selected,"mode":floating_tool.shovel_mode,"yaw":camera_yaw,"pitch":camera_pitch}

func restore(data: Dictionary) -> void:
	place_near_player_one()
	var point=data.get("position",[])
	if point is Array and point.size()==2:player.restore_position(Vector3(float(point[0]),0,float(point[1])))
	floating_tool.equip(clampi(int(data.get("tool",0)),0,4))
	floating_tool.shovel_mode=clampi(int(data.get("mode",0)),0,3)
	camera_yaw=float(data.get("yaw",0))
	camera_pitch=clampf(float(data.get("pitch",PI/4)),deg_to_rad(-80),deg_to_rad(80))
	if not is_finite(camera_yaw):camera_yaw=0
	if not is_finite(camera_pitch):camera_pitch=PI/4

func set_wheel(open: bool) -> void:
	clear_use()
	if open:
		tool_wheel.owner_device=ControllerInput.secondary_device()
		tool_wheel.open(floating_tool.selected)
	else:tool_wheel.hide()
