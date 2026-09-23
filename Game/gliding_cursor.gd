extends Node3D

const FOLLOW_RATE := 12.0
const SIZE_RATE := 10.0
const FLOOR_OFFSET := 0.10
var ring: MeshInstance3D
var spin := 0.0
var target_position := Vector3.ZERO
var target_size := Vector2.ONE
var current_size := Vector2.ONE
var velocity := Vector3.ZERO
var bounds := Rect2i()
var initialized := false

func _ready() -> void:
	ring = MeshInstance3D.new()
	ring.name = "RedGoldSpirit"
	ring.mesh = _arrow_ring()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material
	add_child(ring)
	visible = false

func _arrow_ring() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(12):
		var turn := Basis(Vector3.UP, float(i) * TAU / 12.0)
		var top: Array[Vector3] = [Vector3(-0.09, 0.025, 0.48),
			Vector3(0.09, 0.025, 0.48), Vector3(0.0, 0.025, 0.30)]
		for p in top:
			vertices.append(turn * p)
			colors.append(Color("fff02b"))
		for edge in range(3):
			var a := top[edge]
			var b := top[(edge + 1) % 3]
			var c := a - Vector3.UP * 0.065
			var d := b - Vector3.UP * 0.065
			for p in [a, c, b, b, c, d]:
				vertices.append(turn * p)
				colors.append(Color("ef181b"))
		for p in top:
			vertices.append(turn * (p - Vector3.UP * 0.065))
			colors.append(Color("c90f16"))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	if visible:
		spin += delta * 0.35
		ring.rotation.y = spin
		ring.position.y = sin(spin * 4.0) * 0.006

func select_bounds(selection: Rect2i, grid_min: Vector2, cell_size: float) -> void:
	if not selection.has_area():
		clear()
		return
	bounds = selection
	var center := grid_min + (Vector2(selection.position) + Vector2(selection.size) * 0.5) * cell_size
	target_position = Vector3(center.x, FLOOR_OFFSET, center.y)
	target_size = Vector2(selection.size) * cell_size
	if not initialized:
		position = target_position
		current_size = target_size
		velocity = Vector3.ZERO
		initialized = true
	_apply_size()
	visible = true

func advance(delta: float) -> void:
	if not visible or not initialized:
		return
	# Analytic critically damped spring: weighted motion independent of frame rate.
	var offset := position - target_position
	var impulse := velocity + offset * FOLLOW_RATE
	var decay := exp(-FOLLOW_RATE * delta)
	position = target_position + (offset + impulse * delta) * decay
	velocity = (velocity - impulse * FOLLOW_RATE * delta) * decay
	current_size = current_size.lerp(target_size, 1.0 - exp(-SIZE_RATE * delta))
	if position.distance_to(target_position) < 0.001 and velocity.length() < 0.01:
		position = target_position
		velocity = Vector3.ZERO
	if current_size.distance_to(target_size) < 0.001:
		current_size = target_size
	_apply_size()

func _apply_size() -> void:
	ring.scale = Vector3(current_size.x, 1.0, current_size.y)

func follow_feet(feet: Vector3, size: Vector2, delta: float) -> void:
	# Player movement provides the glide; keep the spirit directly beneath the player.
	position = feet + Vector3.UP * FLOOR_OFFSET
	target_position = position
	target_size = size
	if not initialized:
		current_size = size
		initialized = true
	current_size = current_size.lerp(size, 1.0 - exp(-SIZE_RATE * delta))
	if current_size.distance_to(size) < 0.001:
		current_size = size
	velocity = Vector3.ZERO
	_apply_size()
	visible = true

func is_settled() -> bool:
	return initialized and visible and position == target_position and current_size == target_size

func follow_object(feet: Vector3, size: Vector2, delta: float) -> void:
	target_position = feet + Vector3.UP * FLOOR_OFFSET
	target_size = size
	if not initialized:
		position = target_position
		current_size = size
		initialized = true
	visible = true
	advance(delta)

func clear() -> void:
	visible = false
	initialized = false
	velocity = Vector3.ZERO
	bounds = Rect2i()
