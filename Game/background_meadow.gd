extends Node3D
## Continuous surface-brush weights outside the editable grid.
const WIDTH := 512.0
var material: ShaderMaterial
var garden: Node3D
var contours := FastNoiseLite.new()

func build(world: Node3D) -> void:
	garden = world
	contours.seed = 1891
	contours.frequency = 0.14
	name = "BackgroundMeadow"
	material = garden.terrain_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("background_surface", true)
	material.set_shader_parameter("background_width", WIDTH)
	material.set_shader_parameter("brush_weights", _paint_surface())
	var half: Vector2 = Vector2(garden.chunk_count) * garden.CHUNK_SIZE * 0.5
	var outside := WIDTH * 0.5
	# Four adjacent surfaces meet exactly at the grid boundary, without overlap.
	_add_surface(Vector2(WIDTH, outside - half.y), Vector2(0, -(outside + half.y) * 0.5))
	_add_surface(Vector2(WIDTH, outside - half.y), Vector2(0, (outside + half.y) * 0.5))
	_add_surface(Vector2(outside - half.x, half.y * 2), Vector2(-(outside + half.x) * 0.5, 0))
	_add_surface(Vector2(outside - half.x, half.y * 2), Vector2((outside + half.x) * 0.5, 0))

func _add_surface(size: Vector2, center: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(1,ceili(size.x/2.0)-1)
	plane.subdivide_depth = maxi(1,ceili(size.y/2.0)-1)
	var mesh := MeshInstance3D.new()
	var arrays := plane.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		vertices[i].y = height_at(Vector2(vertices[i].x,vertices[i].z)+center)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var surface := SurfaceTool.new()
	var sculpted := ArrayMesh.new()
	sculpted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	surface.create_from(sculpted,0)
	surface.generate_normals()
	mesh.mesh = surface.commit()
	mesh.position = Vector3(center.x, 0, center.y)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _paint_surface() -> ImageTexture:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1891
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var half: Vector2 = Vector2(garden.chunk_count) * garden.CHUNK_SIZE * 0.5
	for y in range(512):
		for x in range(512):
			var point := (Vector2(x, y) / 511.0 - Vector2.ONE * 0.5) * WIDTH
			var beyond := (point.abs() - half).max(Vector2.ZERO).length()
			var edge := smoothstep(1.0, 7.0, beyond)
			# Broad soft brush strokes, not individual background cells.
			var damp := smoothstep(-0.15, 0.55, noise.get_noise_2dv(point)) * 0.7 * edge
			var soil := smoothstep(0.25, 0.7, noise.get_noise_2dv(point + Vector2(81, 23))) * 0.5 * edge
			var rock := smoothstep(0.4, 0.8, noise.get_noise_2dv(point * 1.8 + Vector2(12, 48))) * 0.45 * edge
			image.set_pixel(x, y, Color(maxf(0.0, 1.0 - damp - soil - rock), damp, soil, rock))
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	if is_instance_valid(garden):
		material.set_shader_parameter("wetness", garden.valley_cycle.wetness)
		material.set_shader_parameter("world_to_grid", garden.global_transform.affine_inverse())

func height_at(point: Vector2) -> float:
	var half: Vector2 = Vector2(garden.chunk_count)
	var outside := (point.abs()-half).max(Vector2.ZERO).length()
	var fade := smoothstep(0.0,3.0,outside)*(1.0-smoothstep(20.0,24.0,point.length()))
	return maxf(0.0,0.3+contours.get_noise_2dv(point)*0.55)*fade
