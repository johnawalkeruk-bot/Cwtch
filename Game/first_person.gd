extends Node3D

const HOVER_HEIGHT := 0.10
const SPEED := 0.48
const SENSITIVITY := 0.0022
var view: Camera3D
var garden: Node3D
var cell := Vector2i(2, 5)
var target_cell := Vector2i(2, 5)
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var travel := 1.0
var travel_duration := 1.0
var elapsed := 0.0
var yaw_target := 0.0
var pitch := deg_to_rad(-12.0)
var pitch_target := deg_to_rad(-12.0)

func setup(camera: Camera3D, owner_garden: Node3D) -> void:
	garden = owner_garden
	cell = cell.clamp(Vector2i.ZERO, garden.grid_size - Vector2i.ONE)
	target_cell = cell
	position = garden.cell_center(cell)
	position.y = garden.heightfield.height_at(Vector2(position.x, position.z)) + HOVER_HEIGHT
	view = camera
	view.reparent(self, false)
	view.position = Vector3.ZERO
	view.rotation = Vector3(pitch, 0.0, 0.0)
	view.projection = Camera3D.PROJECTION_PERSPECTIVE
	view.fov = 80.0
	view.near = 0.012
	view.far = 120.0

func look(relative: Vector2) -> void:
	yaw_target -= relative.x * SENSITIVITY
	pitch_target = clampf(pitch_target - relative.y * SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(80.0))

func advance(delta: float, direction: Vector2) -> void:
	rotation.y = lerp_angle(rotation.y, yaw_target, 1.0 - exp(-12.0 * delta))
	pitch = lerpf(pitch, pitch_target, 1.0 - exp(-12.0 * delta))
	view.rotation.x = pitch
	elapsed += delta
	if is_settled() and direction.length() > 0.1:
		var world := basis * Vector3(direction.x, 0.0, direction.y).normalized()
		var step := Vector2i.ZERO
		if absf(world.x) > 0.4:
			step.x = 1 if world.x > 0.0 else -1
		if absf(world.z) > 0.4:
			step.y = 1 if world.z > 0.0 else -1
		begin_step(cell + step)
	if not is_settled():
		travel = minf(1.0, travel + delta / travel_duration)
		# Quintic easing: zero speed and acceleration at both cell centers.
		var t := travel * travel * travel * (travel * (travel * 6.0 - 15.0) + 10.0)
		position.x = lerpf(start_position.x, end_position.x, t)
		position.z = lerpf(start_position.z, end_position.z, t)
		if travel >= 1.0:
			cell = target_cell
	var surface: float = garden.heightfield.height_at(Vector2(position.x, position.z))
	position.y = surface + HOVER_HEIGHT + sin(elapsed * 1.5) * 0.006

func begin_step(next: Vector2i) -> void:
	if not is_settled() or not garden.contains_cell(next) or next == cell:
		return
	var offset := next - cell
	if absi(offset.x) > 1 or absi(offset.y) > 1:
		return
	start_position = position
	end_position = garden.cell_center(next)
	travel_duration = Vector2(end_position.x - position.x, end_position.z - position.z).length() / SPEED
	target_cell = next
	travel = 0.0

func is_settled() -> bool:
	return travel >= 1.0
