extends "res://wandering_npc.gd"

const CHICKEN = preload("res://assets/chicken_rig.glb")
var skeleton: Skeleton3D
var legs: Array[Dictionary] = []
var stride := 0.0

func _create_visual() -> void:
	collision_radius = 0.18
	collision_height = 0.46
	cell = Vector2i(3, 6)
	next_cell = cell
	move_speed = 0.30
	visual = CHICKEN.instantiate()
	visual.name = "ChickenModel"
	add_child(visual)
	# Imported height is approximately 46 cm; preserve its natural size.
	animation_player = visual.find_child("AnimationPlayer", true, false)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var idle := animation_player.get_animation("Idle").duplicate() as Animation
	idle.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation("idle", idle)
	animation_player.add_animation_library("chicken", library)
	animation_player.play("chicken/idle")
	animation_player.advance(0.0)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	for bone_name in ["Hip_L_032", "Hip_R_03", "Knee_L_033", "Knee_R_04"]:
		var index := skeleton.find_bone(bone_name)
		var basis := skeleton.get_bone_global_rest(index).basis
		legs.append({"index": index, "rest": skeleton.get_bone_pose_rotation(index),
			"axis": (basis.inverse() * Vector3.RIGHT).normalized(),
			"phase": 0.0 if "_L_" in bone_name else PI, "knee": bone_name.begins_with("Knee")})

func advance(delta: float) -> void:
	super.advance(delta)
	if garden.guide.visible:
		return
	animation_player.speed_scale = 1.0
	animation_player.advance(delta)
	if walking:
		stride += delta * 10.0
	for leg in legs:
		var swing := sin(stride + float(leg.phase)) if walking else 0.0
		var angle := maxf(0.0, -swing) * 0.55 if leg.knee else swing * 0.38
		skeleton.set_bone_pose_rotation(leg.index, leg.rest * Quaternion(leg.axis, angle))
