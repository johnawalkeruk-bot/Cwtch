extends CharacterBody3D
## Continuous spirit movement; cells are only used to choose the soil being worked.
const SPEED := 3.0
const RADIUS := 0.16
var garden: Node3D
var cell := Vector2i(2,5)
var target_cell := Vector2i(2,5)

func setup(world: Node3D) -> void:
 garden=world
 collision_layer=0
 collision_mask=4
 var shape:=CollisionShape3D.new()
 var capsule:=CapsuleShape3D.new()
 capsule.radius=RADIUS
 capsule.height=0.5
 shape.shape=capsule
 shape.position.y=0.35
 add_child(shape)
 cell+=(garden.grid_size-Vector2i(9,9))/2
 cell=cell.clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 target_cell=cell
 position=garden.cell_center(cell)

func _allowed(point: Vector3) -> bool:
 for offset in [Vector2(-RADIUS,-RADIUS),Vector2(RADIUS,-RADIUS),Vector2(-RADIUS,RADIUS),Vector2(RADIUS,RADIUS)]:
  var candidate: Vector2i=garden.local_to_cell(point+Vector3(offset.x,0,offset.y))
  if not garden.contains_cell(candidate) or garden.blocked_cells.has(candidate):return false
 return true

func restore_position(point: Vector3) -> void:
 if not point.is_finite() or not _allowed(point):return
 position=point
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z))
 velocity=Vector3.ZERO
 cell=garden.local_to_cell(position)
 target_cell=cell

func advance(delta: float, input: Vector2, camera_yaw: float) -> void:
 var wanted:=Basis(Vector3.UP,camera_yaw)*Vector3(input.x,0,input.y).limit_length()*SPEED
 velocity=velocity.lerp(wanted,1.0-exp(-12.0*delta))
 if wanted.length_squared()<0.001 and velocity.length()<0.01:velocity=Vector3.ZERO
 var motion:=velocity*delta
 # Axis sliding also respects reserved shop-building footprints without grid snapping.
 for step in [Vector3(motion.x,0,0),Vector3(0,0,motion.z)]:
  if _allowed(position+step):move_and_collide(step)
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z))
 cell=garden.local_to_cell(position)
 target_cell=cell

func is_settled() -> bool:
 return velocity.length()<0.05
