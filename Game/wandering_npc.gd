extends CharacterBody3D
## A walking visitor. The imported animation is an in-place walk cycle.
const MODEL = preload("res://assets/arthur.glb")
const WALK_SOURCE = preload("res://assets/Meshy_AI_Subject_15561_biped_Animation_Walking_withSkin.glb")
const SPEED := 0.48
const TURN_SPEED := 1.8
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var garden: Node3D
var visual: Node3D
var animation_player: AnimationPlayer
var cell := Vector2i(4, 4)
var next_cell := Vector2i(4, 4)
var previous_cell := Vector2i(-1, -1)
var destination := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var walking := false
var move_speed := SPEED
var collision_radius := 0.26
var collision_height := 1.5
var motion_ratio := 0.0
var travel_speed := 0.0
var blocked_time := 0.0

func setup(world: Node3D) -> void:
	garden = world
	rng.randomize()
	_create_visual()
	# Imported root tracks must not overwrite the steering transform.
	var model := visual
	visual = Node3D.new()
	visual.name = "FacingPivot"
	add_child(visual)
	model.reparent(visual)
	collision_layer = 8
	collision_mask = 8 | 4
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = collision_radius
	shape.height = collision_height
	collider.shape = shape
	collider.position.y = collision_height * 0.5
	add_child(collider)
	add_to_group("garden_npcs")
	cell += (garden.grid_size - Vector2i(9, 9)) / 2
	if not _can_reserve(cell):
		for y in range(garden.grid_size.y):
			var found := false
			for x in range(garden.grid_size.x):
				if _can_reserve(Vector2i(x,y)):
					cell = Vector2i(x,y)
					found = true
					break
			if found: break
	next_cell = cell
	position = garden.cell_center(cell)
	destination = position

func _create_visual() -> void:
	visual = MODEL.instantiate()
	visual.name = "ArthurModel"
	# Arthur's source mesh is 0.977356 m tall, with feet at zero.
	visual.scale = Vector3.ONE * (1.5 / 0.977356)
	add_child(visual)
	_restore_arthur_rest()
	animation_player = AnimationPlayer.new()
	visual.add_child(animation_player)
	var walk := _retarget_walk()
	var library := AnimationLibrary.new()
	library.add_animation("walk", walk)
	animation_player.add_animation_library("visitor", library)
	animation_player.play("visitor/walk")
	animation_player.speed_scale = 0.85

func _restore_arthur_rest() -> void:
	# Arthur's export has missing joint transforms and invalid inverse binds.
	# Rebuild a compatible Mixamo rest rig, keeping Arthur's mesh and weights.
	var skeleton: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0]
	var donor := WALK_SOURCE.instantiate()
	var reference: Skeleton3D = donor.find_children("*", "Skeleton3D", true, false)[0]
	var globals: Dictionary = {}
	for bone in range(skeleton.get_bone_count()):
		var match_index := reference.find_bone(skeleton.get_bone_name(bone))
		var parent := skeleton.get_bone_parent(bone)
		var rest := Transform3D.IDENTITY
		if match_index >= 0:
			rest = reference.get_bone_global_rest(match_index)
			rest.basis = rest.basis.orthonormalized()
			# Donor bone translations are centimetres; Arthur's mesh uses metres.
			rest.origin *= 0.01 * (0.977356 / 1.7)
		else:
			var ancestor := parent
			while ancestor >= 0:
				var donor_index := reference.find_bone(skeleton.get_bone_name(ancestor))
				if donor_index >= 0:
					rest = reference.get_bone_global_rest(donor_index)
					rest.basis = rest.basis.orthonormalized()
					rest.origin *= 0.01 * (0.977356 / 1.7)
					break
				ancestor = skeleton.get_bone_parent(ancestor)
		globals[bone] = rest
	for bone in range(skeleton.get_bone_count()):
		var parent := skeleton.get_bone_parent(bone)
		var rest: Transform3D = globals[bone]
		var local := rest
		if globals.has(parent):
			local = globals[parent].affine_inverse() * rest
		skeleton.set_bone_rest(bone, local)
	var original_skin := mesh.skin
	var repaired_skin := Skin.new()
	for i in range(original_skin.get_bind_count()):
		var bone := skeleton.find_bone(original_skin.get_bind_name(i))
		if bone < 0:
			bone = original_skin.get_bind_bone(i)
		if bone >= 0:
			while reference.find_bone(skeleton.get_bone_name(bone)) < 0 and skeleton.get_bone_parent(bone) >= 0:
				bone = skeleton.get_bone_parent(bone)
			repaired_skin.add_bind(bone, globals[bone].affine_inverse())
		else:
			repaired_skin.add_bind(0, Transform3D.IDENTITY)
	mesh.skin = repaired_skin
	skeleton.reset_bone_poses()
	donor.free()

func _retarget_walk() -> Animation:
	# Transfer rotations in rest-bone space; source centimetre translations are
	# deliberately excluded because Arthur uses a different skeleton scale.
	var source := WALK_SOURCE.instantiate()
	var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	var target: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var original := source_player.get_animation("Walking")
	var walk := Animation.new()
	walk.length = original.length
	walk.loop_mode = Animation.LOOP_LINEAR
	for track in range(original.get_track_count()):
		if original.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := original.track_get_path(track)
		var bone_name := str(path.get_subname(0))
		var source_index := source_skeleton.find_bone(bone_name)
		var target_index := target.find_bone(bone_name)
		if source_index < 0 or target_index < 0:
			continue
		var source_rest := source_skeleton.get_bone_rest(source_index).basis.get_rotation_quaternion()
		var target_rest := target.get_bone_rest(target_index).basis.get_rotation_quaternion()
		var source_global := source_skeleton.get_bone_global_rest(source_index).basis.orthonormalized().get_rotation_quaternion()
		var target_global := target.get_bone_global_rest(target_index).basis.orthonormalized().get_rotation_quaternion()
		var correction := target_global.inverse() * source_global
		var new_track := walk.add_track(Animation.TYPE_ROTATION_3D)
		walk.track_set_path(new_track, NodePath(str(visual.get_path_to(target)) + ":" + bone_name))
		for key in range(original.track_get_key_count(track)):
			var pose: Quaternion = original.track_get_key_value(track, key)
			var rotation := target_rest * correction * (source_rest.inverse() * pose) * correction.inverse()
			walk.rotation_track_insert_key(new_track, original.track_get_key_time(track, key), rotation.normalized())
	source.free()
	return walk

func _physics_process(delta: float) -> void:
	if not is_instance_valid(garden):
		return
	advance(delta)

func advance(delta: float) -> void:
	if garden.guide.visible:
		animation_player.speed_scale = 0.0
		return
	if position.distance_to(destination) < 0.001:
		cell = next_cell
		_choose_destination()
	# A newly planted tile stops the visitor before it crosses that tile.
	if walking and not _walkable(next_cell):
		next_cell = cell
		destination = garden.cell_center(cell)
	var offset := destination - position
	walking = offset.length() > 0.001
	animation_player.speed_scale = 0.85 if walking else 0.0
	if not walking:
		motion_ratio = 0.0
		travel_speed = 0.0
		return
	# Ease into turns, slowing before a large direction change.
	var heading := atan2(offset.x, offset.z)
	var turn := wrapf(heading-visual.rotation.y,-PI,PI)
	visual.rotation.y += clampf(turn*(1.0-exp(-3.5*delta)),-TURN_SPEED*delta,TURN_SPEED*delta)
	var alignment := smoothstep(0.1,0.95,cos(turn))
	travel_speed = move_toward(travel_speed,move_speed*alignment,delta*move_speed*2.5)
	var before := position
	var motion := offset.normalized()*minf(offset.length(),travel_speed*delta)
	var collision := move_and_collide(motion)
	position.y = garden.heightfield.height_at(Vector2(position.x,position.z))
	motion_ratio = clampf(position.distance_to(before)/maxf(delta*move_speed,0.0001),0,1)
	animation_player.speed_scale = 0.85*motion_ratio
	blocked_time = blocked_time+delta if collision else 0.0
	if blocked_time > 0.8:
		# Back out gently, then reserve another free neighbouring tile.
		next_cell = cell
		destination = garden.cell_center(cell)
		blocked_time = 0.0
		travel_speed = 0.0

func _can_reserve(candidate: Vector2i) -> bool:
	if not _walkable(candidate): return false
	var point: Vector3 = garden.cell_center(candidate)
	for other in get_tree().get_nodes_in_group("garden_npcs"):
		if other == self or other.garden != garden: continue
		var margin: float = collision_radius + other.collision_radius + 0.08
		var target: Vector3 = garden.cell_center(other.next_cell)
		if Vector2(point.x-other.position.x,point.z-other.position.z).length() < margin: return false
		if Vector2(point.x-target.x,point.z-target.z).length() < margin: return false
	return true

func _walkable(candidate: Vector2i) -> bool:
	if not garden.contains_cell(candidate) or garden.crops.has(candidate) or garden.blocked_cells.has(candidate):
		return false
	var center: Vector3 = garden.cell_center(candidate)
	var minimum: Vector2 = garden.grid_min + Vector2.ONE*collision_radius
	var maximum: Vector2 = -garden.grid_min - Vector2.ONE*collision_radius
	if center.x < minimum.x or center.x > maximum.x or center.z < minimum.y or center.z > maximum.y: return false
	var terrain: int = garden.get_terrain(candidate)
	return terrain != garden.Terrain.WATER and terrain != garden.Terrain.DEEP_WATER

func _choose_destination() -> void:
	var options: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if _can_reserve(candidate):
			options.append(candidate)
	if options.is_empty():
		walking = false
		return
	# Prefer exploring to immediately retracing the last step.
	if options.size() > 1:
		options.erase(previous_cell)
	previous_cell = cell
	next_cell = options[rng.randi_range(0, options.size() - 1)]
	destination = garden.cell_center(next_cell)
	walking = true
