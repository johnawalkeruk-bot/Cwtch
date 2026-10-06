extends Node3D
## The keeper greets arrivals, discusses the selected stock, then waits attentively.
var visual: Node3D
var animation_player: AnimationPlayer
var state:="waiting"
var seconds:=0.0
var selected_item:=""
var angus:=false
var shop: Node
var rig: Skeleton3D
var arm_pairs: Array[Vector2i]=[]
func setup(owner_shop: Node, is_angus: bool) -> void:
 shop=owner_shop;angus=is_angus
 name="Angus" if angus else "ShopKeeper"
 visual=load("res://assets/npcs/angus.glb" if angus else "res://assets/npcs/arthur.glb").instantiate()
 visual.scale=Vector3.ONE*(1.5/0.999512);add_child(visual)
 animation_player=visual.find_child("AnimationPlayer",true,false)
 animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var cleaner:=preload("res://cycling_npc.gd").new()
 for library_name in animation_player.get_animation_library_list():
  var original:=animation_player.get_animation_library(library_name)
  var copy:=AnimationLibrary.new()
  for clip_name in original.get_animation_list():
   var clip:=original.get_animation(clip_name).duplicate() as Animation
   cleaner._remove_root_motion(clip)
   clip.loop_mode=Animation.LOOP_LINEAR
   copy.add_animation(clip_name,clip)
  animation_player.remove_animation_library(library_name);animation_player.add_animation_library(library_name,copy)
 cleaner.free()
 if angus:
  rig=visual.find_children("*","Skeleton3D",true,false)[0]
  for side in ["Left","Right"]:
   var upper:=-1;var lower:=-1
   for bone in rig.get_bone_count():
    var bone_name:=str(rig.get_bone_name(bone))
    if bone_name.ends_with(side+"Arm"):upper=bone
    if bone_name.ends_with(side+"ForeArm"):lower=bone
   if upper>=0 and lower>=0:arm_pairs.append(Vector2i(upper,lower))
 change("waiting")
func change(next: String) -> void:
 state=next;seconds=0.0
 var clip: String="Angus_Performance" if angus else ("Talking_1" if next=="greeting" else ("Talking_2" if next=="explaining" else "Happy_Idle"))
 animation_player.play(clip,0.0 if angus else 0.3);animation_player.speed_scale=1.0;animation_player.advance(0.0)
 if angus:animation_player.seek(1.0,true)
func greet() -> void:
 selected_item="";change("greeting")
func browse(id: String) -> void:
 if id==selected_item:return
 selected_item=id
 if state!="greeting":change("explaining")
func _process(delta: float) -> void:
 if not is_visible_in_tree() or not is_instance_valid(shop) or shop.paused:return
 seconds+=delta
 if state=="greeting" and seconds>3.5:change("explaining" if not selected_item.is_empty() else "waiting")
 elif state=="explaining" and seconds>5.0:change("waiting")
 # Angus has one supplied performance, so hold its settled pose after the opening reference frame when idle.
 if angus and state=="waiting":
  animation_player.seek(1.0,true)
  _rest_arms()
 else:animation_player.advance(delta)
 var offset: Vector3=shop.camera.global_position-global_position
 var heading:=atan2(offset.x,offset.z)
 rotation.y=lerp_angle(rotation.y,heading,1.0-exp(-2.2*delta))

func _rest_arms() -> void:
 # The supplied performance has no idle clip. Relax the upper arms into an
 # attentive counter-side stance, without editing or replacing the source rig.
 for pair in arm_pairs:
  var upper:=rig.get_bone_global_pose(pair.x)
  var lower:=rig.get_bone_global_pose(pair.y)
  var direction: Vector3=(lower.origin-upper.origin).normalized()
  var target:=Vector3(signf(direction.x)*0.18,-1.0,0.08).normalized()
  var correction:=Basis(Quaternion(direction,target))
  var parent_basis:=rig.get_bone_global_pose(rig.get_bone_parent(pair.x)).basis.orthonormalized()
  var local_basis:=parent_basis.inverse()*correction*upper.basis.orthonormalized()
  rig.set_bone_pose_rotation(pair.x,local_basis.get_rotation_quaternion())
