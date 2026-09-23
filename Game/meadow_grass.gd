extends Node3D
## Batched, deterministic grass. Terrain textures keep it in sync with tools and saves.
var garden: Node3D
var exclusions: Image
var exclusion_texture: ImageTexture
var refresh_time := 0.0
const TUFTS_PER_PATCH := 320

func build(world: Node3D) -> void:
	garden = world
	name = "MeadowGrass"
	exclusions = Image.create(world.grid_size.x, world.grid_size.y, false, Image.FORMAT_R8)
	exclusion_texture = ImageTexture.create_from_image(exclusions)
	_refresh_exclusions()
	var material := ShaderMaterial.new()
	material.shader = preload("res://meadow_grass.gdshader")
	material.set_shader_parameter("terrain_ids", world.terrain_texture)
	material.set_shader_parameter("exclusions", exclusion_texture)
	material.set_shader_parameter("grid_min", world.grid_min)
	material.set_shader_parameter("grid_size", Vector2(world.grid_size))
	material.set_shader_parameter("micro_size", world.MICRO_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891
	var blade_mesh := _tuft()
	# One batch per 4 m patch allows Godot to cull distant patches independently.
	for z in range(-5, 5):
		for x in range(-5, 5):
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.use_colors = true
			batch.mesh = blade_mesh
			batch.instance_count = TUFTS_PER_PATCH
			for i in range(batch.instance_count):
				var point := Vector3(x * 4.0 + rng.randf_range(0.12, 3.88), 0.008, z * 4.0 + rng.randf_range(0.12, 3.88))
				var scale_factor := rng.randf_range(0.65, 1.3)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_factor)
				batch.set_instance_transform(i, Transform3D(basis, point))
				batch.set_instance_color(i, Color(rng.randf_range(0.8, 1.13), rng.randf_range(0.9, 1.1), 0.9))
			var patch := MultiMeshInstance3D.new()
			patch.multimesh = batch
			patch.material_override = material
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			patch.extra_cull_margin = 0.6
			patch.visibility_range_end = 32.0
			add_child(patch)

func _tuft() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var angle := float(i) * 2.39996
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.017
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.035
		var base := lean * 0.3
		var mid := base + lean + Vector3.UP * 0.10
		var tip := base + lean * 2.2 + Vector3.UP * (0.17 + float(i) * 0.014)
		var vertices := [base-side, base+side, mid-side*0.55, base+side, mid+side*0.55, mid-side*0.55, mid-side*0.55, mid+side*0.55, tip]
		for vertex: Vector3 in vertices:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(0.5, vertex.y / 0.22))
			surface.add_vertex(vertex)
	return surface.commit()

func _refresh_exclusions() -> void:
	exclusions.fill(Color.BLACK)
	for cell: Vector2i in garden.blocked_cells:
		if garden.contains_cell(cell):
			exclusions.set_pixel(cell.x, cell.y, Color.WHITE)
	for cell: Vector2i in garden.crops:
		if garden.contains_cell(cell):
			exclusions.set_pixel(cell.x, cell.y, Color.WHITE)
	exclusion_texture.update(exclusions)

func _process(delta: float) -> void:
	refresh_time += delta
	if refresh_time >= 0.5:
		refresh_time = 0.0
		_refresh_exclusions()
