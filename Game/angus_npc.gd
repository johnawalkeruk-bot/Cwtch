extends "res://cycling_npc.gd"
## Angus performs his supplied long clip in place, rather than sliding to a walk.
func _create_visual() -> void:
	visual=preload("res://assets/npcs/angus.glb").instantiate()
	visual.name="AngusModel"
	visual.scale=Vector3.ONE*(1.5/0.999512)
	add_child(visual)
	collision_radius=0.35
	animation_player=visual.find_child("AnimationPlayer",true,false)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for library_name in animation_player.get_animation_library_list():
		var source:=animation_player.get_animation_library(library_name)
		var library:=AnimationLibrary.new()
		for clip_name in source.get_animation_list():
			var clip:=source.get_animation(clip_name).duplicate() as Animation
			_remove_root_motion(clip)
			clip.loop_mode=Animation.LOOP_LINEAR
			library.add_animation(clip_name,clip)
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name,library)
	for clip_name in animation_player.get_animation_list():
		if clip_name!="RESET":
			current_clip=clip_name
			animation_player.play(current_clip)
			break
	animation_player.advance(0.0)

func advance(delta: float) -> void:
	if garden.guide.visible: return
	animation_player.advance(delta)
