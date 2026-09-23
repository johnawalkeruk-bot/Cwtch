extends "res://wandering_npc.gd"
var stride := 0.0
func _create_visual() -> void:
 collision_radius=0.27
 collision_height=0.85
 move_speed=0.34
 visual=load("res://assets/animals/Peacock/Peacock.fbx").instantiate()
 var box: AABB=preload("res://floating_tool.gd").bounds(visual)
 var scale_factor:=0.85/box.size.y
 visual.scale*=scale_factor
 visual.position-=Vector3(box.get_center().x,box.position.y,box.get_center().z)*scale_factor
 add_child(visual)
 animation_player=AnimationPlayer.new()
 add_child(animation_player)
 set_meta("animal_id","peacock")
func advance(delta: float) -> void:
 super.advance(delta)
 if garden.guide.visible:return
 stride+=delta
 visual.rotation.z=sin(stride*8)*0.025*motion_ratio
