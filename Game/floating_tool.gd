extends Node3D
signal effect_applied(cell: Vector2i, tool: int)
const KEYS := ["hoe","seeds","water"]
const DURATION := [0.95,1.45,1.55]
var garden: Node3D
var pivot: Node3D
var models: Array[Node3D] = []
var particles: CPUParticles3D
var selected := 0
var busy := false
var elapsed := 0.0
var idle_time := 0.0
var applied := false
var target_cell := Vector2i.ZERO
var target_point := Vector3.ZERO
var outlet := Vector3.ZERO

static func bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	transform *= node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh: result = transform*node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := bounds(child,transform)
			if child_bounds.size.length()>0: result = child_bounds if result.size.length()==0 else result.merge(child_bounds)
	return result

static func make_model(index: int) -> Node3D:
	var wrapper := Node3D.new()
	var model: Node3D = load("res://assets/tools/%s.glb" % KEYS[index]).instantiate()
	var box := bounds(model)
	var size := 0.82 if index==0 else (0.43 if index==1 else 0.58)
	var factor := size/maxf(box.size.x,maxf(box.size.y,box.size.z))
	model.scale *= factor
	model.position -= box.get_center()*factor
	wrapper.add_child(model)
	if index==2: wrapper.rotation.y=PI/4.0
	return wrapper

func setup(world: Node3D) -> void:
	garden = world
	pivot = Node3D.new()
	add_child(pivot)
	for i in range(3):
		var model := make_model(i)
		pivot.add_child(model)
		models.append(model)
	particles = CPUParticles3D.new()
	particles.top_level = true
	particles.local_coords = false
	particles.amount = 55
	particles.lifetime = 0.55
	particles.direction = Vector3.DOWN
	particles.spread = 13
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.7
	particles.gravity = Vector3(0,-3,0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.016
	drop.height = 0.032
	drop.radial_segments = 6
	drop.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	drop.material = material
	particles.mesh = drop
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	add_child(particles)
	equip(0)

func equip(index: int) -> void:
	selected = clampi(index,0,2)
	for i in range(models.size()): models[i].visible = i==selected
	pivot.rotation = Vector3.ZERO
	particles.emitting = false
	particles.color = Color("84e45a") if selected==1 else Color("58bbed")

func use_at(cell: Vector2i) -> bool:
	if busy: return false
	target_cell = cell
	target_point = garden.cell_center(cell)
	busy = true
	elapsed = 0
	applied = false
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(garden): return
	var paused: bool = garden.guide.visible or garden.tool_wheel.visible
	particles.speed_scale = 0 if paused else 1
	visible = not garden.guide.visible
	if paused: return
	idle_time += delta
	var anchor: Vector3 = target_point+Vector3.UP*0.1 if busy else garden.cursor.position
	position = anchor+Vector3.UP*(0.55+sin(idle_time*2)*0.022)
	rotation.y = garden.camera_yaw
	pivot.position = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	if not busy: return
	elapsed += delta
	var t := clampf(elapsed/DURATION[selected],0,1)
	var tilt := smoothstep(0,0.25,t)*(1.0-smoothstep(0.78,1.0,t))
	if selected==0:
		pivot.position.y = -0.24*pow(absf(sin(t*PI*2)),2)
		pivot.rotation.z = -0.18+sin(t*TAU*2)*0.10
	elif selected==1:
		pivot.rotation.z = PI*tilt
		pivot.position.y = absf(sin(t*TAU*3))*0.055*tilt
		outlet = Vector3(0,0.20,0)
	else:
		pivot.rotation.z = -1.9*tilt
		outlet = Basis(Vector3.UP,PI/4.0)*Vector3(0.2553,0.0726,0.2359)
	particles.global_position = pivot.to_global(outlet)
	particles.emitting = selected>0 and t>0.28 and t<0.8
	if not applied and t>=(0.25 if selected==0 else 0.58):
		applied = true
		effect_applied.emit(target_cell,selected)
	if t>=1:
		busy = false
		particles.emitting = false
		pivot.rotation = Vector3.ZERO
