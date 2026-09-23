extends RefCounted
## Shared textured ash/birch models, batched in small groups for efficient drawing.
static var prototypes: Dictionary = {}

static func _collect(node: Node, transform: Transform3D, parts: Array) -> void:
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D and node.mesh:
		parts.append({"mesh":node.mesh,"transform":transform,"material":node.material_override})
	for child in node.get_children(): _collect(child,transform,parts)

static func _prototype(kind: String) -> Dictionary:
	if prototypes.has(kind): return prototypes[kind]
	var scene: PackedScene = load("res://assets/trees/%s_forest.glb" % kind)
	var root := scene.instantiate()
	var parts: Array = []
	_collect(root,Transform3D.IDENTITY,parts)
	var bounds: AABB = parts[0].transform * parts[0].mesh.get_aabb()
	for part in parts: bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	var scale := 5.5 / bounds.size.y
	var origin := Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*scale
	var normalise := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),origin)
	for part in parts: part.transform = normalise * part.transform
	root.free()
	prototypes[kind] = {"parts":parts}
	return prototypes[kind]

static func plant(parent: Node3D, placements: Array[Transform3D], kind: String) -> void:
	var prototype := _prototype(kind)
	for start in range(0,placements.size(),32):
		for part in prototype.parts:
			var batch := MultiMeshInstance3D.new()
			batch.name = kind.capitalize()+"Trees%d" % start
			batch.set_meta("tree_asset",kind)
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = part.mesh
			batch.material_override = part.material
			batch.multimesh.instance_count = mini(32,placements.size()-start)
			for i in range(batch.multimesh.instance_count):
				batch.multimesh.set_instance_transform(i,placements[start+i]*part.transform)
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(batch)
