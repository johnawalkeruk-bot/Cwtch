extends Node3D
## Perspective landscape: a closed mountain mesh, rolling ground and forest.
var material: ShaderMaterial
var birds: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func _plain(color: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.9
	return result

func ground_height(x: float, z: float) -> float:
	var channel := 14.0+sin(z*0.045)*7.0
	var distance_to_stream := absf(x-channel)
	return (1.2+sin(x*0.036+z*0.016)*1.1+cos(z*0.04)*0.7)*smoothstep(2.0,18.0,distance_to_stream)

func build() -> void:
	rng.seed = 1941
	material = ShaderMaterial.new()
	material.shader = preload("res://landscape_surface.gdshader")
	material.set_shader_parameter("color_maps",load("res://assets/textures/terrain_colors.res"))
	_build_mountain()
	_build_ground()
	_build_stream()
	_build_forest()
	_build_meadow_details()
	_build_birds()

func _triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.y < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a,c,b]:
		builder.set_normal(normal)
		builder.set_color(color.srgb_to_linear())
		builder.add_vertex(point)

func _finish(builder: SurfaceTool, label: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = builder.commit()
	instance.material_override = material
	add_child(instance)
	return instance

func _build_mountain() -> void:
	const SEGMENTS := 72
	const RINGS := 24
	var points: Array[Vector3] = []
	for ring in range(RINGS+1):
		var t := float(ring)/RINGS
		for segment in range(SEGMENTS):
			var angle := float(segment)/SEGMENTS*TAU
			var ridge := 1.0+0.13*sin(angle*5.0+0.7)+0.055*cos(angle*9.0)
			var radius := t*79*ridge
			var height := 76.0*pow(1.0-t,1.42)
			height += sin(PI*t)*(sin(angle*5+0.5)*6.5+cos(angle*8)*2.0)
			# The peak leans toward the left; ridges run down all sides.
			points.append(Vector3(-5+cos(angle)*radius-8*(1-t),maxf(0,height),-87+sin(angle)*radius*0.82-3*(1-t)))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS):
		for segment in range(SEGMENTS):
			var a := ring*SEGMENTS+segment
			var b := ring*SEGMENTS+(segment+1)%SEGMENTS
			var c := a+SEGMENTS
			var d := b+SEGMENTS
			for tri in [[a,c,d],[a,d,b]]:
				var p: Vector3 = (points[tri[0]]+points[tri[1]]+points[tri[2]])/3.0
				var snowline := 43.0+sin(p.x*0.28+p.z*0.12)*4.5+cos(p.z*0.3)*2.0
				var color := Color("356c75").lerp(Color("648b94"),clampf(p.y/72.0,0,1))
				if p.y > snowline:
					color = Color("b9dce9").lerp(Color("f0f7f8"),smoothstep(45,73,p.y))
				color *= rng.randf_range(0.94,1.05)
				_triangle(builder,points[tri[0]],points[tri[1]],points[tri[2]],color)
	# Seal the underside so this is a model with volume, not a camera-facing card.
	for segment in range(SEGMENTS):
		var a: Vector3 = points[RINGS*SEGMENTS+segment]
		var b: Vector3 = points[RINGS*SEGMENTS+(segment+1)%SEGMENTS]
		for point in [Vector3(-5,-0.1,-87),b,a]:
			builder.set_normal(Vector3.DOWN)
			builder.set_color(Color("31555c"))
			builder.add_vertex(point)
	_finish(builder,"SnowcapMountain3D")

func _build_ground() -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-220,181,8):
		for x in range(-260,261,8):
			var a := Vector3(x,ground_height(x,z)-0.05,z)
			var b := Vector3(x+8,ground_height(x+8,z)-0.05,z)
			var c := Vector3(x,ground_height(x,z+8)-0.05,z+8)
			var d := Vector3(x+8,ground_height(x+8,z+8)-0.05,z+8)
			var color := Color("426951").lerp(Color("708569"),rng.randf()*0.6)
			_triangle(builder,a,c,b,color)
			_triangle(builder,b,c,d,color)
	_finish(builder,"RollingValleyGround")

func _build_stream() -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-40,181,2):
		var x := 14+sin(z*0.045)*7
		var nx := 14+sin((z+2)*0.045)*7
		var width := 1.7
		var a := Vector3(x-width,0.10,z)
		var b := Vector3(x+width,0.10,z)
		var c := Vector3(nx-width,0.10,z+2)
		var d := Vector3(nx+width,0.10,z+2)
		_triangle(builder,a,c,b,Color.WHITE)
		_triangle(builder,b,c,d,Color.WHITE)
	var river := _finish(builder,"ValleyStream")
	var water := ShaderMaterial.new()
	water.shader = preload("res://menu_stream.gdshader")
	river.material_override = water

func _build_forest() -> void:
	for kind in ["ash","birch"]:
		var placements: Array[Transform3D] = []
		for i in range(180):
			var x := rng.randf_range(-150,150)
			var z := rng.randf_range(-45,100)
			if absf(x-(14+sin(z*0.045)*7))<6: continue
			if absf(x)<12 and z>20: continue
			if Vector2((x+5)/87,(z+87)/73).length()<1: continue
			var size := rng.randf_range(0.75,1.6)
			var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size)
			placements.append(Transform3D(basis,Vector3(x,ground_height(x,z),z)))
		preload("res://imported_trees.gd").plant(self,placements,kind)
	# Rocks anchor the stream bank in the foreground.
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 3
	for i in range(36):
		var z := rng.randf_range(-35,90)
		var x := 14+sin(z*0.045)*7+(-3 if i%2==0 else 3)
		var mesh := MeshInstance3D.new()
		mesh.mesh = rock
		mesh.material_override = _plain("687d78")
		mesh.position = Vector3(x,ground_height(x,z),z)
		mesh.scale = Vector3(rng.randf_range(0.8,2),rng.randf_range(0.5,1.2),rng.randf_range(1,2))
		add_child(mesh)

func _build_birds() -> void:
	var dark := _plain("28363e")
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(7):
		var bird := Node3D.new()
		add_child(bird)
		for side in [-1,1]:
			var wing := MeshInstance3D.new()
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			_triangle(builder,Vector3(0,0,-0.4),Vector3(side*1.9,0,0.3),Vector3(side*0.35,0,0.55),Color.WHITE)
			wing.mesh = builder.commit()
			wing.material_override = dark
			bird.add_child(wing)
		var body := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.22
		shape.height = 0.44
		shape.radial_segments = 8
		shape.rings = 4
		body.mesh = shape
		body.scale = Vector3(1,0.7,3)
		body.material_override = dark
		bird.add_child(body)
		birds.append(bird)

func animate(time: float, daylight: float, rain: float) -> void:
	material.set_shader_parameter("rain_strength",rain)
	for i in range(birds.size()):
		var phase := time*0.075+i*0.86
		var bird := birds[i]
		bird.position = Vector3(-5+cos(phase)*39,42+sin(phase*1.4+i)*11,-77+sin(phase)*34)
		bird.rotation.y = -phase
		for wing in range(2):
			bird.get_child(wing).rotation.z = sin(time*4+i)*0.5*(-1 if wing==0 else 1)

func _build_meadow_details() -> void:
	var source := preload("res://valley_landscape.gd").new()
	var grass_source := preload("res://meadow_grass.gd").new()
	for kind in ["grass","fern","heather","gorse"]:
		var prototype: ArrayMesh = grass_source._tuft() if kind=="grass" else source._prototype(kind)
		var positions: Array[Transform3D] = []
		for i in range(14000 if kind=="grass" else 300):
			var x := rng.randf_range(-90,95)
			var z := rng.randf_range(8,110)
			var river_distance := absf(x-(14+sin(z*0.045)*7))
			if river_distance<3.3: continue
			if kind!="grass" and sin(x*0.13+z*0.16)<0.0: continue
			var scale_factor := rng.randf_range(1.5,3.0) if kind=="grass" else rng.randf_range(0.8,1.9)
			positions.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_factor),Vector3(x,ground_height(x,z),z)))
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = prototype
		batch.instance_count = positions.size()
		for i in range(positions.size()): batch.set_instance_transform(i,positions[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Menu"+kind.capitalize()
		node.multimesh = batch
		var foliage := StandardMaterial3D.new()
		foliage.roughness = 1.0
		foliage.metallic_specular = 0.1
		foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
		foliage.vertex_color_use_as_albedo = kind!="grass"
		foliage.albedo_color = Color("6b7a3a") if kind=="grass" else Color.WHITE
		node.material_override = foliage
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	source.free()
	grass_source.free()
