extends Area3D
## Attach to a model root. Layer 2 is selection-only, never player collision.
var subject: Node3D
var label := "Object"
var footprint := Vector2.ONE
var crop_cell := Vector2i(-1, -1)

static func attach(parent: Node3D, title: String, size: Vector3, cell := Vector2i(-1, -1)) -> Area3D:
	var script = load("res://selection_target.gd")
	var target = script.new()
	target.subject = parent
	target.label = title
	target.footprint = Vector2(size.x, size.z)
	target.crop_cell = cell
	target.collision_layer = 2
	target.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = size.y * 0.5
	target.add_child(collider)
	parent.add_child(target)
	return target

func selection_size() -> Vector2:
	var world_scale := subject.global_basis.get_scale()
	return footprint * Vector2(absf(world_scale.x), absf(world_scale.z)) + Vector2.ONE * 0.16
