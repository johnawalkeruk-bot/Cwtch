extends Node3D
## Instanced mesh blades, without selection or movement colliders.
var garden: Node3D
var patches: Dictionary = {}
var material: ShaderMaterial
var tuft: ArrayMesh
var wind_time := 0.0

func setup(world: Node3D) -> void:
	garden = world
	material = ShaderMaterial.new()
	material.shader = preload("res://grass.gdshader")
	tuft = _make_tuft()
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x):
			var cell := Vector2i(x, z)
			update_cell(cell, garden.get_terrain(cell))
	garden.terrain_changed.connect(update_cell)

func _make_tuft() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(7):
		var angle := blade * TAU / 7.0
		var sideways := Vector3(cos(angle), 0, sin(angle))
		var lean := Vector3(-sin(angle), 0, cos(angle)) * (0.12 + blade * 0.015)
		var base := sideways * 0.04
		for segment in range(3):
			var a := float(segment) / 3.0
			var b := float(segment + 1) / 3.0
			var lower := base + Vector3.UP * a + lean * a * a
			var upper := base + Vector3.UP * b + lean * b * b
			var half_a := sideways * (1.0 - a) * 0.065
			var half_b := sideways * (1.0 - b) * 0.065
			var points := [lower - half_a, lower + half_a, upper - half_b,
				upper - half_b, lower + half_a, upper + half_b]
			var uvs := [Vector2(0,a), Vector2(1,a), Vector2(0,b), Vector2(0,b), Vector2(1,a), Vector2(1,b)]
			for i in range(6):
				builder.set_uv(uvs[i])
				builder.add_vertex(points[i])
	builder.generate_normals()
	return builder.commit()

func update_cell(cell: Vector2i, kind: int) -> void:
	if patches.has(cell):
		var old: Node3D = patches[cell]
		old.hide()
		old.queue_free()
		patches.erase(cell)
	if kind != garden.Terrain.GRASS and kind != garden.Terrain.LONG_GRASS:
		return
	var tall: bool = kind == garden.Terrain.LONG_GRASS
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = tuft
	instances.instance_count = 52 if tall else 36
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891 + cell.x * 7919 + cell.y * 104729
	var center: Vector3 = garden.cell_center(cell)
	for i in range(instances.instance_count):
		var height := rng.randf_range(0.26, 0.46) if tall else rng.randf_range(0.08, 0.16)
		var width := rng.randf_range(0.38, 0.65) if tall else rng.randf_range(0.25, 0.40)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
		var margin: float = garden.MICRO_SIZE * 0.44
		var point := center + Vector3(rng.randf_range(-margin, margin), 0.005, rng.randf_range(-margin, margin))
		instances.set_instance_transform(i, Transform3D(basis, point))
		instances.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 1))
	var patch := MultiMeshInstance3D.new()
	patch.name = "Grass_%d_%d" % [cell.x, cell.y]
	patch.multimesh = instances
	patch.material_override = material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.extra_cull_margin = 0.4
	add_child(patch)
	patches[cell] = patch

func _process(delta: float) -> void:
	if not is_instance_valid(garden) or garden.guide.visible:
		return
	wind_time += delta
	material.set_shader_parameter("wind_time", wind_time)
	material.set_shader_parameter("spirit_position", garden.cursor.global_position)
	material.set_shader_parameter("visitor_position", garden.visitor.global_position)
	material.set_shader_parameter("chicken_position", garden.chicken.global_position)
	material.set_shader_parameter("rain_strength", garden.valley_cycle.rain_strength)
	material.set_shader_parameter("wetness", garden.valley_cycle.wetness)
