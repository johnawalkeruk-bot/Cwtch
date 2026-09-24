extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(1.3,0.8,2.6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 1.2
	scene.add_child(light)
	for i in range(4):
		var model := preload("res://floating_tool.gd").make_model(i)
		scene.add_child(model)
		camera.size = 1.1 if i==3 else (0.95 if i==0 else 0.72)
		print("TOOL BOUNDS ",i," ",preload("res://floating_tool.gd").bounds(model))
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/tools/%s_icon.png" % ["hoe","seeds","water","shovel"][i])
		model.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	quit()
