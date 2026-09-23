extends "res://wandering_npc.gd"
const HEDGEHOG = preload("res://assets/hedgehog.glb")
var body: Node3D
var gait := 0.0
var sniff_time := 0.0
var walk_time := 5.0

func _create_visual() -> void:
 collision_radius = 0.18
 collision_height = 0.28
 cell = Vector2i(1,6)
 next_cell = cell
 move_speed = 0.23
 visual = Node3D.new()
 add_child(visual)
 body = HEDGEHOG.instantiate()
 body.scale = Vector3.ONE * (0.35 / 0.976685)
 visual.add_child(body)
 # The file has unnamed zero-rest bones and no clips. Use its undeformed mesh
 # with whole-body procedural animation, rather than relying on that rig.
 for part in body.find_children("*","MeshInstance3D",true,false):
  var source: Mesh = part.mesh
  var mesh := ArrayMesh.new()
  for surface in range(source.get_surface_count()):
   var arrays := source.surface_get_arrays(surface)
   arrays[Mesh.ARRAY_BONES] = null
   arrays[Mesh.ARRAY_WEIGHTS] = null
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   mesh.surface_set_material(surface,source.surface_get_material(surface))
  part.mesh = mesh
  part.skin = null
  part.skeleton = NodePath("")
 animation_player = AnimationPlayer.new()
 add_child(animation_player)
 walk_time = rng.randf_range(4,8)

func advance(delta: float) -> void:
 if garden.guide.visible: return
 gait += delta
 if sniff_time > 0:
  sniff_time = maxf(0,sniff_time-delta)
  walking = false
  body.rotation.x = sin(gait*5.0)*0.10
  body.rotation.z = sin(gait*2.0)*0.025
  body.position.y = 0.003+sin(gait*3.0)*0.002
 else:
  super.advance(delta)
  walk_time -= delta
  body.rotation.x = sin(gait*8.0)*0.025
  body.rotation.z = sin(gait*10.0)*0.07
  body.position.y = absf(sin(gait*10.0))*0.008
  if walk_time<=0 and position.distance_to(destination)<0.03:
   sniff_time = rng.randf_range(2,4)
   walk_time = rng.randf_range(4,9)
 var breathing := 1.0+sin(gait*2.5)*0.012
 body.scale = Vector3(1,breathing,1)*(0.35/0.976685)
