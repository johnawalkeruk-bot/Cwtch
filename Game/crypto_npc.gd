extends "res://wandering_npc.gd"
## Crypto uses the shared navigation/collision brain and his original rigged clips.
const CRYPTO_MODEL = preload("res://assets/npcs/crypto.glb")
var current_clip: StringName = &""

func _create_visual() -> void:
 visual = CRYPTO_MODEL.instantiate()
 visual.name = "CryptoModel"
 # The converted rig faces +Z with feet at ground level, matching shared steering.
 add_child(visual)
 collision_height = 1.35
 collision_radius = 0.29
 move_speed = 0.58
 animation_player = visual.find_child("AnimationPlayer", true, false)
 animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for library_name in animation_player.get_animation_library_list():
  var original := animation_player.get_animation_library(library_name)
  var library := AnimationLibrary.new()
  for animation_name in original.get_animation_list():
   var clip := original.get_animation(animation_name).duplicate() as Animation
   if animation_name in [&"Idle", &"Walk"]:clip.loop_mode = Animation.LOOP_LINEAR
   library.add_animation(animation_name, clip)
  animation_player.remove_animation_library(library_name)
  animation_player.add_animation_library(library_name, library)
 _play(&"Idle")
 animation_player.advance(0.0)

func _play(clip: StringName) -> void:
 if current_clip == clip:return
 current_clip = clip
 animation_player.play(clip, 0.22)

func advance(delta: float) -> void:
 if garden.guide.visible:return
 super.advance(delta)
 var moving := walking and motion_ratio > 0.03
 _play(&"Walk" if moving else &"Idle")
 animation_player.speed_scale = 1.0
 # In-place footwork follows actual travel; collisions cannot leave him marching.
 animation_player.advance(delta * maxf(motion_ratio, 0.08) if moving else delta)
