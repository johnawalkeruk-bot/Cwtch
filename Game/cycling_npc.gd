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
	steps_until_rest = rng.randi_range(4, 8)
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

func _choose_destination() -> void:
	steps_until_rest -= 1
	if steps_until_rest <= 0:
		steps_until_rest = rng.randi_range(4, 8)
		idle_remaining = rng.randf_range(2.0, 4.0)
		walking = false
		travel_speed = 0.0
		if animation_player.has_animation("Happy_Idle"):
			_play("Happy_Idle")
		else:
			_play("Start_Walk")
			animation_player.seek(0.0, true)
		return
	super._choose_destination()
	if not walking: return
	var offset := destination - position
	var turn := wrapf(atan2(offset.x, offset.z) - visual.rotation.y, -PI, PI)
	if absf(turn) > 0.65:
		_play("Left_Turn" if turn > 0.0 else "Right_Turn")
	elif current_clip != "Walking":
		_play("Start_Walk")

func advance(delta: float) -> void:
	if garden.guide.visible: return
	animation_player.speed_scale = 1.0
	if idle_remaining > 0.0:
		idle_remaining = maxf(0.0, idle_remaining-delta)
		if current_clip == "Happy_Idle": animation_player.advance(delta)
		if idle_remaining == 0.0: _play("Start_Walk")
		return
	super.advance(delta)
	if idle_remaining > 0.0: return
	animation_player.speed_scale = 1.0
	clip_remaining -= delta
	if clip_remaining <= 0.0: _play("Walking")
	# Footwork must continue during steering even while forward speed is low.
	var rate := maxf(0.12, motion_ratio*move_speed/stride_speed) if current_clip == "Walking" else 1.0
	animation_player.advance(delta * rate)
