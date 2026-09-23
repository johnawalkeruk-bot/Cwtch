extends Node3D

signal micro_tile_hovered(cell: Vector2i, terrain: int)
signal terrain_changed(cell: Vector2i, terrain: int)

enum Terrain { DIRT, HARD_DIRT, GRASS, LONG_GRASS, WATER, DEEP_WATER, PATH, STONE }
const CHUNK_SIZE := 2.0
const SUBDIVISIONS := 3
const MICRO_SIZE := CHUNK_SIZE / float(SUBDIVISIONS)
const FLOOR_MASK := 1
const INVALID_CELL := Vector2i(-1, -1)
const TERRAIN_NAMES := ["Dirt", "Hard dirt", "Grass", "Long grass", "Water", "Deep water", "Path", "Stone"]

@export var chunk_count := Vector2i(3, 3)

var grid_size: Vector2i
var grid_min: Vector2
var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_material: ShaderMaterial
var chunks: Dictionary = {}
var camera: Camera3D
var cursor: Node3D
var status: Label
var hovered_cell := INVALID_CELL
var selected_terrain: int = Terrain.GRASS
var paint_requested := false

func _ready() -> void:
	chunk_count = Vector2i(maxi(chunk_count.x, 1), maxi(chunk_count.y, 1))
	grid_size = chunk_count * SUBDIVISIONS
	grid_min = -Vector2(chunk_count) * CHUNK_SIZE * 0.5
	_create_terrain()
	_create_chunks()
	_create_view()
	_create_cursor()
	_update_status()

func _create_terrain() -> void:
	terrain_image = Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_R8)
	# Seven demonstration bands; each row crosses chunk boundaries.
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			var kind := mini(int(float(z) * 7.0 / float(grid_size.y)), 6)
			terrain_image.set_pixel(x, z, Color(float(kind) / 255.0, 0.0, 0.0))
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://terrain.gdshader")
	terrain_material.set_shader_parameter("terrain_ids", terrain_texture)
	terrain_material.set_shader_parameter("grid_size", Vector2(grid_size))
	terrain_material.set_shader_parameter("grid_min", grid_min)
	terrain_material.set_shader_parameter("micro_size", MICRO_SIZE)
	terrain_material.set_shader_parameter("world_to_grid", global_transform.affine_inverse())

func _create_chunks() -> void:
	# Same dimensions and nine surface quads as the Blender asset.
	var surface := PlaneMesh.new()
	surface.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	surface.subdivide_width = SUBDIVISIONS - 1
	surface.subdivide_depth = SUBDIVISIONS - 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(CHUNK_SIZE, 0.2, CHUNK_SIZE)
	for z in range(chunk_count.y):
		for x in range(chunk_count.x):
			var chunk := Node3D.new()
			chunk.name = "Chunk_%d_%d" % [x, z]
			chunk.position = Vector3(grid_min.x + (x + 0.5) * CHUNK_SIZE,
				0.0, grid_min.y + (z + 0.5) * CHUNK_SIZE)
			add_child(chunk)
			chunks[Vector2i(x, z)] = chunk
			var ground := MeshInstance3D.new()
			ground.mesh = surface
			ground.material_override = terrain_material
			chunk.add_child(ground)
			var body := StaticBody3D.new()
			body.collision_layer = FLOOR_MASK
			body.collision_mask = 0
			chunk.add_child(body)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position.y = -0.1
			body.add_child(collider)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(chunk_count.x * CHUNK_SIZE, 0.3, chunk_count.y * CHUNK_SIZE)
	base.mesh = box
	base.position.y = -0.155
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("493a2d")
	earth.roughness = 1.0
	base.material_override = earth
	add_child(base)

func _create_view() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7.0, 9.0, 9.0)
	camera.look_at(to_global(Vector3.ZERO), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(chunk_count.x, chunk_count.y) * CHUNK_SIZE * 1.7
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263137")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c2cb")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var ui := CanvasLayer.new()
	add_child(ui)
	status = Label.new()
	status.position = Vector2(20.0, 20.0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(status)

func _create_cursor() -> void:
	cursor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * MICRO_SIZE * 0.95
	cursor.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://cursor.gdshader")
	cursor.material_override = material
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			selected_terrain = event.keycode - KEY_1
			_update_status()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			paint_requested = true

func _physics_process(_delta: float) -> void:
	terrain_material.set_shader_parameter("world_to_grid", global_transform.affine_inverse())
	var cell := INVALID_CELL
	var mouse := get_viewport().get_mouse_position()
	if get_viewport().get_visible_rect().has_point(mouse):
		var origin := camera.project_ray_origin(mouse)
		var end := origin + camera.project_ray_normal(mouse) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(origin, end, FLOOR_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var local_hit := to_local(hit["position"])
			# Reject the side walls of floor colliders.
			if absf(local_hit.y) < 0.001:
				cell = local_to_cell(local_hit)
	cursor.visible = cell != INVALID_CELL
	if cursor.visible:
		cursor.position = cell_center(cell) + Vector3.UP * 0.025
	if cell != hovered_cell:
		hovered_cell = cell
		micro_tile_hovered.emit(cell, get_terrain(cell))
		_update_status()
	if paint_requested and cell != INVALID_CELL:
		set_terrain(cell, selected_terrain)
	paint_requested = false

func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func local_to_cell(point: Vector3) -> Vector2i:
	var p := (Vector2(point.x, point.z) - grid_min) / MICRO_SIZE
	var cell := Vector2i(floori(p.x), floori(p.y))
	return cell if contains_cell(cell) else INVALID_CELL

func cell_center(cell: Vector2i) -> Vector3:
	var p := grid_min + (Vector2(cell) + Vector2.ONE * 0.5) * MICRO_SIZE
	return Vector3(p.x, 0.0, p.y)

func get_terrain(cell: Vector2i) -> int:
	if not contains_cell(cell):
		return -1
	return roundi(terrain_image.get_pixel(cell.x, cell.y).r * 255.0)

func set_terrain(cell: Vector2i, terrain: int) -> void:
	if not contains_cell(cell) or terrain < Terrain.DIRT or terrain > Terrain.STONE:
		return
	if get_terrain(cell) == terrain:
		return
	terrain_image.set_pixel(cell.x, cell.y, Color(float(terrain) / 255.0, 0.0, 0.0))
	terrain_texture.update(terrain_image)
	terrain_changed.emit(cell, terrain)
	_update_status()

func _update_status() -> void:
	status.text = "ABERGLEN\n1–7: select terrain • Left click: paint\nBrush: %s\nCell: %s" % [
		TERRAIN_NAMES[selected_terrain], str(hovered_cell)]
