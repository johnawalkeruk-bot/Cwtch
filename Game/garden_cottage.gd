extends Node3D
const COTTAGE = preload("res://assets/cottage.glb")
const SelectionTarget = preload("res://selection_target.gd")
var footprint := Vector3(6.0,4.3308,5.6)
func build(garden: Node3D) -> void:
 name = "Cottage"
 position = Vector3(-6,0,-5)
 var model := COTTAGE.instantiate()
 model.scale = Vector3.ONE*(6.0/0.982788)
 add_child(model)
 set_meta("inspection_text","A quiet cottage beside the garden.")
 SelectionTarget.attach(self,"Cottage",footprint)
 var body := StaticBody3D.new()
 body.collision_layer=4
 body.collision_mask=0
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size=footprint
 collider.shape=shape
 collider.position.y=footprint.y*0.5
 body.add_child(collider)
 add_child(body)
 # Reserve every intersecting microtile, including a small clearance margin.
 for z in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   var cell := Vector2i(x,z)
   var point: Vector3 = garden.cell_center(cell)
   if absf(point.x-position.x)<footprint.x*0.5+garden.MICRO_SIZE*0.5 and absf(point.z-position.z)<footprint.z*0.5+garden.MICRO_SIZE*0.5:
    garden.blocked_cells[cell]=true
