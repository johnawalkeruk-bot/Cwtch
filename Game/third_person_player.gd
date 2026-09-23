extends Node3D

# Invisible movement controller; the spirit ring is the only player visual.
const SPEED := 1.1
var garden: Node3D
var cell := Vector2i(2, 5)
var target_cell := Vector2i(2, 5)
var start := Vector3.ZERO
var goal := Vector3.ZERO
var progress := 1.0
var duration := 1.0

func setup(owner_garden: Node3D) -> void:
	garden = owner_garden
	cell += (garden.grid_size - Vector2i(9, 9)) / 2
	cell = cell.clamp(Vector2i.ZERO, garden.grid_size - Vector2i.ONE)
	target_cell = cell
	position = garden.cell_center(cell)

func advance(delta: float, input: Vector2, camera_yaw: float) -> void:
	if is_settled() and input.length() > 0.1:
		var movement := Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y).normalized()
		var offset := Vector2i.ZERO
		if absf(movement.x) > 0.4:
			offset.x = 1 if movement.x > 0.0 else -1
		if absf(movement.z) > 0.4:
			offset.y = 1 if movement.z > 0.0 else -1
		var next := cell + offset
		var corner_blocked := false
		if offset.x != 0 and offset.y != 0:
			corner_blocked = garden.blocked_cells.has(cell + Vector2i(offset.x, 0)) or garden.blocked_cells.has(cell + Vector2i(0, offset.y))
		if garden.contains_cell(next) and next != cell and not garden.blocked_cells.has(next) and not corner_blocked:
			target_cell = next
			start = position
			goal = garden.cell_center(next)
			duration = start.distance_to(goal) / SPEED
			progress = 0.0
	if not is_settled():
		progress = minf(1.0, progress + delta / duration)
		var t := progress * progress * (3.0 - 2.0 * progress)
		position = start.lerp(goal, t)
		position.y = garden.heightfield.height_at(Vector2(position.x, position.z))
		if is_settled():
			cell = target_cell
func is_settled() -> bool:
	return progress >= 1.0
