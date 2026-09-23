extends Node3D

const RESOLUTION := 12
const WATER_LEVEL := 0.012
const BASE_LEVEL := -0.95
var garden: Node3D
var heights: Image
var height_texture: ImageTexture
var samples: Vector2i
var spacing := 2.0 / float(RESOLUTION)
var water_material: ShaderMaterial

func build(owner_garden: Node3D) -> void:
	garden = owner_garden
	samples = garden.chunk_count * RESOLUTION + Vector2i.ONE
	heights = Image.create(samples.x, samples.y, false, Image.FORMAT_RF)
	heights.fill(Color(0.0, 0.0, 0.0))
	_sculpt_pond()
	height_texture = ImageTexture.create_from_image(heights)
	for z in range(garden.chunk_count.y):
		for x in range(garden.chunk_count.x):
			_build_chunk(Vector2i(x, z))
	_build_water()
	_build_skirts()

func _sculpt_pond() -> void:
	var banks: Array[PackedVector2Array] = []
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x):
			var cell := Vector2i(x, z)
			if not _is_water(cell):
				continue
			var corner: Vector2 = garden.grid_min + Vector2(cell) * garden.MICRO_SIZE
			var size: float = garden.MICRO_SIZE
			for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _is_water(cell + side):
					continue
				var a := corner
				var b := corner
				if side.x != 0:
					a.x += size if side.x > 0 else 0.0
					b = a + Vector2(0, size)
				else:
					a.y += size if side.y > 0 else 0.0
					b = a + Vector2(size, 0)
				banks.append(PackedVector2Array([a, b]))
	for z in range(samples.y):
		for x in range(samples.x):
			var point: Vector2 = garden.grid_min + Vector2(x, z) * spacing
			if not _is_water(garden.local_to_cell(Vector3(point.x, 0, point.y))):
				continue
			var distance_to_bank := INF
			for bank in banks:
				distance_to_bank = minf(distance_to_bank, point.distance_to(Geometry2D.get_closest_point_to_segment(point, bank[0], bank[1])))
			var depth := 0.9 * smoothstep(0.0, 1.1, distance_to_bank)
			heights.set_pixel(x, z, Color(-depth, 0, 0))

func _is_water(cell: Vector2i) -> bool:
	return garden.get_terrain(cell) in [garden.Terrain.WATER, garden.Terrain.DEEP_WATER]

func _h(x: int, z: int) -> float:
	return heights.get_pixel(clampi(x, 0, samples.x - 1), clampi(z, 0, samples.y - 1)).r

func height_at(p: Vector2) -> float:
	var q: Vector2 = ((p - garden.grid_min) / spacing).clamp(Vector2.ZERO, Vector2(samples - Vector2i.ONE))
	var x := mini(floori(q.x), samples.x - 2)
	var z := mini(floori(q.y), samples.y - 2)
	var f := q - Vector2(x, z)
	# Match the two actual mesh triangles, including their diagonal.
	if f.x + f.y <= 1.0:
		return _h(x, z) + f.x * (_h(x + 1, z) - _h(x, z)) + f.y * (_h(x, z + 1) - _h(x, z))
	return _h(x + 1, z + 1) + (1.0 - f.x) * (_h(x, z + 1) - _h(x + 1, z + 1)) + (1.0 - f.y) * (_h(x + 1, z) - _h(x + 1, z + 1))

func surface_at(p: Vector2) -> float:
	return maxf(WATER_LEVEL, height_at(p))

func _build_chunk(cell: Vector2i) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z in range(RESOLUTION + 1):
		for x in range(RESOLUTION + 1):
			var gx := cell.x * RESOLUTION + x
			var gz := cell.y * RESOLUTION + z
			var p: Vector2 = garden.grid_min + Vector2(gx, gz) * spacing
			vertices.append(Vector3(p.x, _h(gx, gz), p.y))
			normals.append(Vector3(_h(gx - 1, gz) - _h(gx + 1, gz),
				2.0 * spacing, _h(gx, gz - 1) - _h(gx, gz + 1)).normalized())
			uvs.append(p)
	for z in range(RESOLUTION):
		for x in range(RESOLUTION):
			var a := z * (RESOLUTION + 1) + x
			var b := a + 1
			var c := a + RESOLUTION + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var chunk := MeshInstance3D.new()
	chunk.name = "HeightChunk_%d_%d" % [cell.x, cell.y]
	chunk.mesh = mesh
	chunk.material_override = garden.terrain_material
	add_child(chunk)
	garden.chunks[cell] = chunk
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	chunk.add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(garden.chunk_count) * 2.0
	var water := MeshInstance3D.new()
	water.name = "PondSurface"
	water.position.y = WATER_LEVEL
	water.mesh = plane
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://water.gdshader")
	for entry in [["water_color", "M_Water_BaseColor"], ["water_normal", "M_Water_Normal"], ["water_roughness", "M_Water_Roughness"], ["water_opacity", "M_Water_Opacity"], ["bottom_color", "M_RiverBottom_BaseColor"], ["bottom_ao", "M_RiverBottom_AO"]]:
		water_material.set_shader_parameter(entry[0], load("res://assets/textures/water/%s.tga" % entry[1]))
	water_material.set_shader_parameter("terrain_ids", garden.terrain_texture)
	water_material.set_shader_parameter("grid_size", Vector2(garden.grid_size))
	water_material.set_shader_parameter("micro_size", garden.MICRO_SIZE)
	water_material.set_shader_parameter("grid_min", garden.grid_min)
	water_material.set_shader_parameter("bed_heights", height_texture)
	water_material.set_shader_parameter("height_samples", Vector2(samples))
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_skirts() -> void:
	var vertices := PackedVector3Array()
	var perimeter: Array[Vector2i] = []
	for x in range(samples.x):
		perimeter.append(Vector2i(x, 0))
	for z in range(1, samples.y):
		perimeter.append(Vector2i(samples.x - 1, z))
	for x in range(samples.x - 2, -1, -1):
		perimeter.append(Vector2i(x, samples.y - 1))
	for z in range(samples.y - 2, 0, -1):
		perimeter.append(Vector2i(0, z))
	for i in range(perimeter.size()):
		var a := perimeter[i]
		var b := perimeter[(i + 1) % perimeter.size()]
		var pa: Vector2 = garden.grid_min + Vector2(a) * spacing
		var pb: Vector2 = garden.grid_min + Vector2(b) * spacing
		var top_a := Vector3(pa.x, _h(a.x, a.y), pa.y)
		var top_b := Vector3(pb.x, _h(b.x, b.y), pb.y)
		var low_a := Vector3(pa.x, BASE_LEVEL, pa.y)
		var low_b := Vector3(pb.x, BASE_LEVEL, pb.y)
		vertices.append_array(PackedVector3Array([top_a, low_a, top_b, top_b, low_a, low_b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var skirt := MeshInstance3D.new()
	skirt.mesh = mesh
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("514331")
	earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	skirt.material_override = earth
	add_child(skirt)
