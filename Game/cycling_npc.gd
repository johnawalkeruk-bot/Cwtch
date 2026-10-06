extends "res://wandering_npc.gd"
## Supplied FBX clips follow locomotion; the collision body owns world motion.
var model_scene: PackedScene
var model_height := 1.0
var display_name := "Visitor"
var current_clip: StringName
var idle_remaining := 0.0
var clip_remaining := 0.0
var steps_until_rest := 5
var stride_speed := 1.4

func _create_visual() -> void:
	visual = model_scene.instantiate()
	visual.name = display_name + "Model"
	visual.scale = Vector3.ONE * (1.5 / model_height)
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for library_name in animation_player.get_animation_library_list():
		var original := animation_player.get_animation_library(library_name)
		var library := AnimationLibrary.new()
		for animation_name in original.get_animation_list():
			var clip := original.get_animation(animation_name).duplicate() as Animation
			clip.loop_mode = Animation.LOOP_LINEAR if animation_name in ["Walking", "Happy_Idle"] else Animation.LOOP_NONE
			if animation_name == "Walking":
				for track in range(clip.get_track_count()):
					if str(clip.track_get_path(track)) == "Armature" and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
						var start: Vector3 = clip.track_get_key_value(track, 0)
						var end: Vector3 = clip.track_get_key_value(track, clip.track_get_key_count(track)-1)
						stride_speed = maxf(Vector2(end.x-start.x,end.z-start.z).length()*visual.scale.x/clip.length, 0.1)
			_remove_root_motion(clip)
			library.add_animation(animation_name, clip)
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	move_speed = 0.48
	steps_until_rest = 5
	_play("Start_Walk")
	animation_player.advance(0.0)

func _remove_root_motion(clip: Animation) -> void:
	for track in range(clip.get_track_count()):
		if str(clip.track_get_path(track)) != "Armature": continue
		if clip.track_get_key_count(track) == 0: continue
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			for key in range(clip.track_get_key_count(track)):
				var value: Vector3 = clip.track_get_key_value(track, key)
				# Preserve vertical footwork, remove horizontal travel from the rig.
				value.x = 0.0
				value.z = 0.0
				clip.track_set_key_value(track, key, value)
		elif clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			# Turn clips contain root yaw. Steering supplies that yaw continuously,
			# so remove only its twist while keeping the body's lean and footwork.
			for key in range(clip.track_get_key_count(track)):
				var q: Quaternion = clip.track_get_key_value(track, key)
				var twist := Quaternion(0, q.y, 0, q.w).normalized()
				clip.track_set_key_value(track, key, (twist.inverse() * q).normalized())

func _play(clip: StringName) -> void:
	if current_clip == clip: return
	if not animation_player.has_animation(clip): return
	current_clip = clip
	animation_player.play(clip, 0.25)
	clip_remaining = animation_player.get_animation(clip).length

func advance(delta: float) -> void:
	if garden.guide.visible:return
	if has_meta("arrival_waiting"):
		_play("Happy_Idle");animation_player.speed_scale=1.0;animation_player.advance(delta);return
	super.advance(delta)
	animation_player.speed_scale=1.0
	var desired: StringName="Walking" if walking and motion_ratio>0.03 else "Happy_Idle"
	if brain.state=="shelter" and not walking and animation_player.has_animation("Shivering"):desired="Shivering"
	if not animation_player.has_animation(desired):
		_play("Start_Walk");animation_player.seek(0.0,true);return
	_play(desired)
	var rate:=maxf(0.12,motion_ratio*move_speed/stride_speed) if desired=="Walking" else 1.0
	animation_player.advance(delta*rate)
