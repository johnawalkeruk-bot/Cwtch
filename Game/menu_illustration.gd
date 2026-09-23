extends Node3D
## Layered native meshes give the title scene an illustrated, cut-paper finish.
var material: ShaderMaterial
var birds: Array[Node3D] = []
var sparkles: Array[MeshInstance3D] = []

func _polygon(points: Array, color: String, parent: Node3D, depth: float = 0.0) -> MeshInstance3D:
	var outline := PackedVector2Array()
	for point in points: outline.append(Vector2(point[0],point[1]))
	var indices := Geometry2D.triangulate_polygon(outline)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		builder.set_color(Color(color))
		builder.set_normal(Vector3.FORWARD)
		builder.add_vertex(Vector3((outline[index].x-290)*0.18,(440-outline[index].y)*0.18,depth))
	var instance := MeshInstance3D.new()
	instance.mesh = builder.commit()
	instance.material_override = material
	parent.add_child(instance)
	return instance

func build() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://menu_illustration.gdshader")
	var mountain := Node3D.new()
	mountain.name = "IllustratedMountain"
	add_child(mountain)
	_polygon([[58,420],[108,372],[137,346],[165,295],[185,253],[216,234],[239,199],[257,189],[285,147],[310,162],[327,189],[336,196],[351,227],[368,256],[391,289],[408,322],[454,371],[489,402],[526,422],[415,434],[272,438],[121,430]],"477d89",mountain)
	var facets := [
		["315d6b",[[58,420],[108,372],[158,356],[196,279],[214,265],[182,349],[151,397],[122,430]]],
		["284f5e",[[121,430],[180,363],[207,296],[237,255],[219,320],[213,354],[177,391],[157,431]]],
		["386979",[[157,431],[214,364],[225,300],[263,231],[282,212],[266,291],[247,330],[248,390],[274,436]]],
		["28535e",[[238,244],[270,213],[288,191],[296,240],[286,266],[302,285],[295,334],[273,316],[260,356],[239,372],[251,298]]],
		["6197a2",[[300,211],[324,226],[350,260],[373,279],[345,270],[329,257],[318,263],[308,243]]],
		["365f6a",[[301,281],[325,268],[337,287],[365,313],[385,344],[351,326],[331,308],[320,341],[316,321]]],
		["5c8f9a",[[329,310],[367,335],[400,372],[438,409],[408,395],[385,373],[391,397],[363,379]]],
		["315a67",[[235,382],[273,354],[300,365],[322,351],[347,391],[337,420],[364,433],[274,436],[246,421]]],
		["548792",[[306,383],[323,363],[349,394],[375,404],[402,428],[354,414],[342,404],[323,418]]],
		["41717c",[[186,382],[216,346],[207,386],[219,415],[196,431],[168,428]]],
		["386673",[[407,335],[457,375],[489,402],[526,422],[476,429],[460,415],[429,386]]],
		["d9ecf5",[[216,234],[239,199],[257,189],[285,147],[310,162],[327,189],[335,196],[350,227],[369,258],[376,272],[357,263],[345,245],[337,252],[323,232],[311,258],[299,248],[285,219],[270,231],[258,220],[243,239],[237,225],[223,250]]],
		["add2e5",[[216,234],[239,199],[257,189],[285,147],[274,181],[258,207],[243,215],[237,225],[223,250]]],
		["c1deed",[[285,147],[310,162],[327,189],[314,183],[303,171],[300,199],[315,218],[306,226],[286,203],[272,213],[280,186]]],
		["ffffff",[[307,191],[314,200],[321,215],[334,228],[326,231],[317,218],[312,212]]],
		["f6fbfc",[[338,224],[351,241],[363,259],[358,256],[346,240],[342,241]]],
		["81b4ca",[[271,169],[278,180],[275,188],[263,187],[267,180]]]
	]
	for i in range(facets.size()): _polygon(facets[i][1],facets[i][0],mountain,0.02*(i+1))
	for point in [[223,199],[332,156],[406,275]]:
		var x: float = point[0]
		var y: float = point[1]
		var sparkle := _polygon([[x,y-9],[x+2,y-2],[x+7,y],[x+2,y+2],[x,y+10],[x-2,y+2],[x-7,y],[x-2,y-2]],"e2f1f7",self,1)
		sparkles.append(sparkle)
	for i in range(7):
		var bird := Node3D.new()
		bird.name = "Swallow%d" % i
		add_child(bird)
		# Local silhouettes have tapered, forked wings and a pointed tail.
		for side in [-1,1]:
			var pivot := Node3D.new()
			bird.add_child(pivot)
			_polygon([[290,440],[290+side*8,433],[290+side*23,429],[290+side*37,413],[290+side*30,435],[290+side*15,444],[290,447]],"424d50",pivot,1)
		_polygon([[287,439],[289,432],[292,430],[295,434],[294,442],[300,453],[292,450],[288,454],[289,444]],"424d50",bird,1.1)
		birds.append(bird)

func animate(time: float, daylight: float, rain: float) -> void:
	material.set_shader_parameter("daylight",daylight)
	material.set_shader_parameter("rain_strength",rain)
	for i in range(birds.size()):
		var bird := birds[i]
		var phase := time*0.10+i*0.9
		bird.position = Vector3(sin(phase)*22,39+cos(phase*0.7+i)*12,3+i*0.05)
		bird.scale = Vector3.ONE*(0.32+float(i%3)*0.14)
		bird.rotation.z = sin(phase+0.6)*0.45
		for wing in range(2):
			bird.get_child(wing).rotation.y = sin(time*3.4+i)*0.55*(-1 if wing==0 else 1)
	for i in range(sparkles.size()):
		sparkles[i].visible = sin(time*0.7+i*1.8)>-0.15 and rain<0.4
