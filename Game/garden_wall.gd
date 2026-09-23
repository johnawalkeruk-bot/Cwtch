extends Node3D
## A continuous physical perimeter, with staggered dry-stone courses.
const HEIGHT := 0.72
const THICKNESS := 0.28

func build(garden: Node3D) -> void:
	name = "GardenStoneWall"
	var width: float = garden.chunk_count.x * garden.CHUNK_SIZE
	var depth: float = garden.chunk_count.y * garden.CHUNK_SIZE
	var material := ShaderMaterial.new()
	material.shader = preload("res://stone_wall.gdshader")
	for entry in [["stone_color", "Color"], ["stone_normal", "NormalGL"], ["stone_roughness", "Roughness"], ["stone_ao", "AmbientOcclusion"]]:
		material.set_shader_parameter(entry[0], load("res://assets/textures/stone/Rock062_1K-JPG_%s.jpg" % entry[1]))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 8
	rock.rings = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891
	for side in range(4):
		var along_x := side < 2
		var length := width + THICKNESS * 2.0 if along_x else depth
		var middle := Vector3(0, 0, (-1.0 if side == 0 else 1.0) * (depth + THICKNESS) * 0.5) if along_x else Vector3((-1.0 if side == 2 else 1.0) * (width + THICKNESS) * 0.5, 0, 0)
		var body := StaticBody3D.new()
		body.name = "Boundary%d" % side
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = middle + Vector3.UP * HEIGHT * 0.5
		add_child(body)
		var box := BoxShape3D.new()
		box.size = Vector3(length, HEIGHT, THICKNESS) if along_x else Vector3(THICKNESS, HEIGHT, length)
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		# Odd courses use half blocks at both ends, so corners stay closed.
		var count := ceili(length / 0.48)
		var step := length / count
		for row in range(3):
			for column in range(count + (row % 2)):
				var start := maxf(0.0, (column - 0.5 * (row % 2)) * step)
				var end := minf(length, (column + 1.0 - 0.5 * (row % 2)) * step)
				var mesh := MeshInstance3D.new()
				mesh.mesh = rock
				mesh.material_override = material
				# Per-stone tone without allocating hundreds of materials.
				var coloured := rock.duplicate() as SphereMesh
				var arrays := coloured.get_mesh_arrays()
				var colors := PackedColorArray()
				colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
				colors.fill(Color(rng.randf_range(0.1, 0.9), 1, 1))
				arrays[Mesh.ARRAY_COLOR] = colors
				var stone := ArrayMesh.new()
				stone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.mesh = stone
				var offset := (start + end) * 0.5 - length * 0.5
				mesh.position = middle + Vector3(0, row * 0.225 + 0.12, 0)
				mesh.position += Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
				mesh.scale = Vector3((end - start) * 1.07, rng.randf_range(0.25, 0.28), THICKNESS * 1.22)
				mesh.rotation.y = (0.0 if along_x else PI / 2.0) + rng.randf_range(-0.07, 0.07)
				add_child(mesh)
