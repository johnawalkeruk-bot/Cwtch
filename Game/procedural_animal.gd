extends "res://wandering_npc.gd"
## Repaired animal rigs with procedural gait, breathing and idle motions.
var species := "badger"
var body: Node3D
var rig: Skeleton3D
var drives: Array[Dictionary] = []
var phase := 0.0
var rest_time := 0.0
var roam_time := 7.0
var body_scale := 1.0

func _create_visual() -> void:
	var dragon := species == "dragon"
	move_speed = 0.28 if dragon else 0.32
	collision_radius = 0.52 if dragon else 0.34
	collision_height = 0.65 if dragon else 0.42
	body_scale = 1.05 / 0.981384 if dragon else 0.65 / 0.978394
	visual = Node3D.new()
	add_child(visual)
	body = load("res://assets/%s.glb" % species).instantiate()
	body.scale = Vector3.ONE*body_scale
	visual.add_child(body)
	var mesh: MeshInstance3D = body.find_children("*","MeshInstance3D",true,false)[0]
	rig = mesh.get_node(mesh.skeleton)
	if dragon:
		_restore_dragon(mesh)
	else:
		_rebuild_badger(mesh)
	animation_player = AnimationPlayer.new()
	add_child(animation_player)
	_prepare_drives(mesh)
	phase = rng.randf()*TAU
	roam_time = rng.randf_range(5,9)

func _restore_dragon(mesh: MeshInstance3D) -> void:
	# The exporter omitted node rest transforms; inverse binds retain them.
	var globals: Dictionary = {}
	for i in range(mesh.skin.get_bind_count()):
		var index := rig.find_bone(mesh.skin.get_bind_name(i))
		if index >= 0: globals[index] = mesh.skin.get_bind_pose(i).affine_inverse()
	for index in range(rig.get_bone_count()):
		if not globals.has(index):
			var parent := rig.get_bone_parent(index)
			globals[index] = globals.get(parent,Transform3D.IDENTITY)
	for index in range(rig.get_bone_count()):
		var parent := rig.get_bone_parent(index)
		var local: Transform3D = globals[index]
		if parent >= 0: local = globals[parent].affine_inverse()*local
		rig.set_bone_rest(index,local)
	rig.reset_bone_poses()

func _rebuild_badger(mesh: MeshInstance3D) -> void:
	# The source's inverse binds are corrupt and most limb influences are empty.
	# Reconstruct a small quadruped rig and feather weights at the limb roots.
	var repaired := Skeleton3D.new()
	body.add_child(repaired)
	var labels := ["body","head","front_left","front_right","rear_left","rear_right","tail"]
	var pivots := [Vector3(0,0.28,0),Vector3(0,0.30,0.22),Vector3(0.11,0.17,0.19),
		Vector3(-0.11,0.17,0.19),Vector3(0.11,0.17,-0.22),Vector3(-0.11,0.17,-0.22),Vector3(0,0.27,-0.34)]
	var skin := Skin.new()
	for i in range(labels.size()):
		repaired.add_bone(labels[i])
		var origin: Vector3 = pivots[i]
		if i>0:
			repaired.set_bone_parent(i,0)
			origin -= pivots[0]
		repaired.set_bone_rest(i,Transform3D(Basis.IDENTITY,origin))
		skin.add_named_bind(labels[i],Transform3D(Basis.IDENTITY,pivots[i]).affine_inverse())
	var rebuilt := ArrayMesh.new()
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vertices.size()*4)
		weights.resize(vertices.size()*4)
		for v in range(vertices.size()):
			var point := vertices[v]
			var bone := 0
			var weight := 0.0
			if point.y<0.23:
				bone = (2 if point.x>0 else 3) if point.z>0 else (4 if point.x>0 else 5)
				weight = 1.0-smoothstep(0.10,0.23,point.y)
			elif point.z>0.18:
				bone = 1
				weight = smoothstep(0.18,0.34,point.z)
			elif point.z < -0.32:
				bone = 6
				weight = 0.7*(1.0-smoothstep(-0.46,-0.32,point.z))
			bones[v*4] = bone
			weights[v*4] = weight
			bones[v*4+1] = 0
			weights[v*4+1] = 1.0-weight
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		rebuilt.surface_set_material(surface,mesh.mesh.surface_get_material(surface))
	mesh.mesh = rebuilt
	mesh.skin = skin
	mesh.skeleton = mesh.get_path_to(repaired)
	rig = repaired
	rig.reset_bone_poses()

func _drive(label: String, axis: Vector3, amplitude: float, rate: float, offset: float, gait_only: bool) -> void:
	var index := rig.find_bone(label)
	if index < 0: return
	var local_axis := (rig.get_bone_global_rest(index).basis.inverse()*axis).normalized()
	drives.append({"bone":index,"rest":rig.get_bone_pose_rotation(index),"axis":local_axis,
		"amplitude":amplitude,"rate":rate,"phase":offset,"gait":gait_only})

func _prepare_drives(_mesh: MeshInstance3D) -> void:
	if species == "dragon":
		_drive("bone_27",Vector3.FORWARD,0.16,2.2,0,false)
		_drive("bone_37",Vector3.FORWARD,0.16,2.2,PI,false)
		_drive("bone_3",Vector3.RIGHT,0.045,1.4,0,false)
		_drive("bone_69",Vector3.UP,0.10,1.8,0,false)
		_drive("bone_70",Vector3.UP,0.08,1.8,0.5,false)
		for label in ["bone_15","bone_24","bone_53","bone_63"]:
			var i := rig.find_bone(label)
			var p := rig.get_bone_global_rest(i).origin
			_drive(label,Vector3.RIGHT,0.18,7.0,0 if (p.x>0)==(p.z>0.1) else PI,true)
	else:
		_drive("head",Vector3.RIGHT,0.06,2.0,0,false)
		_drive("tail",Vector3.UP,0.10,2.6,0,false)
		_drive("front_left",Vector3.RIGHT,0.28,8.0,0,true)
		_drive("front_right",Vector3.RIGHT,0.28,8.0,PI,true)
		_drive("rear_left",Vector3.RIGHT,0.28,8.0,PI,true)
		_drive("rear_right",Vector3.RIGHT,0.28,8.0,0,true)

func advance(delta: float) -> void:
	if garden.guide.visible: return
	phase += delta
	if rest_time > 0:
		rest_time = maxf(0,rest_time-delta)
		walking = false
		motion_ratio = 0
	else:
		super.advance(delta)
		roam_time -= delta
		if roam_time <= 0 and position.distance_to(destination)<0.02:
			rest_time = rng.randf_range(2,5)
			roam_time = rng.randf_range(5,10)
	for drive in drives:
		var strength: float = motion_ratio if drive.gait else 1.0
		var angle: float = sin(phase*drive.rate+drive.phase)*drive.amplitude*strength
		rig.set_bone_pose_rotation(drive.bone,drive.rest*Quaternion(drive.axis,angle))
	body.position.y = absf(sin(phase*7))*0.012*motion_ratio
	body.rotation.z = sin(phase*7)*0.018*motion_ratio
	body.scale = Vector3(1,1+sin(phase*2)*0.007,1)*body_scale
