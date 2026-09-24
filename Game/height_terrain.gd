extends Node3D

const RESOLUTION := 12
const WATER_LEVEL := 0.012
const BASE_LEVEL := -0.95
var garden: Node3D
signal sculpted
var original_heights: Image
var original_texture: ImageTexture
var edited: Dictionary={}
var seed_holes: Dictionary={}
var heights: Image
var height_texture: ImageTexture
var samples: Vector2i
var spacing := 2.0 / float(RESOLUTION)
var water_material: ShaderMaterial

func build(owner_garden: Node3D) -> void:
 garden = owner_garden
 samples = garden.chunk_count * RESOLUTION + Vector2i.ONE
 heights = Image.create(samples.x, samples.y, false, Image.FORMAT_RF)
 heights.fill(Color(0.0, 0.0, 0.0))
 _sculpt_meadow()
 _sculpt_pond()
 original_heights=heights.duplicate()
 original_texture=ImageTexture.create_from_image(original_heights)
 height_texture = ImageTexture.create_from_image(heights)
 for z in range(garden.chunk_count.y):
  for x in range(garden.chunk_count.x):
   _build_chunk(Vector2i(x, z))
 _build_water()
 _build_skirts()

func _sculpt_meadow() -> void:
 var noise := FastNoiseLite.new()
 noise.seed = 1891
 noise.frequency = 0.16
 noise.fractal_octaves = 3
 var half: Vector2 = Vector2(garden.chunk_count)
 for z in range(samples.y):
  for x in range(samples.x):
   var p: Vector2 = garden.grid_min + Vector2(x, z) * spacing
   # A smooth level join to the surrounding meadow, with gently rolling ground throughout.
   var edge := smoothstep(0.0, 2.0, minf(half.x-absf(p.x), half.y-absf(p.y)))
   var working_plot := lerpf(0.22, 1.0, smoothstep(2.0, 5.0, p.length()))
   var rolling := 0.32 + noise.get_noise_2dv(p)*0.65
   rolling += 0.07*sin(p.x*0.75)*cos(p.y*0.65)
   heights.set_pixel(x,z,Color(maxf(0.0,rolling)*edge*working_plot,0,0))

func _sculpt_pond() -> void:
 var banks: Array[PackedVector2Array] = []
 for z in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   var cell := Vector2i(x, z)
   if not _is_water(cell):
    continue
   var corner: Vector2 = garden.grid_min + Vector2(cell) * garden.MICRO_SIZE
   var size: float = garden.MICRO_SIZE
   for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
    if _is_water(cell + side):
     continue
    var a := corner
    var b := corner
    if side.x != 0:
     a.x += size if side.x > 0 else 0.0
     b = a + Vector2(0, size)
    else:
     a.y += size if side.y > 0 else 0.0
     b = a + Vector2(size, 0)
    banks.append(PackedVector2Array([a, b]))
 for z in range(samples.y):
  for x in range(samples.x):
   var point: Vector2 = garden.grid_min + Vector2(x, z) * spacing
   if not _is_water(garden.local_to_cell(Vector3(point.x, 0, point.y))):
    continue
   var distance_to_bank := INF
   for bank in banks:
    distance_to_bank = minf(distance_to_bank, point.distance_to(Geometry2D.get_closest_point_to_segment(point, bank[0], bank[1])))
   var depth := 0.9 * smoothstep(0.0, 1.1, distance_to_bank)
   heights.set_pixel(x, z, Color(-depth, 0, 0))

func _is_water(cell: Vector2i) -> bool:
 return garden.get_terrain(cell) in [garden.Terrain.WATER, garden.Terrain.DEEP_WATER]

func _h(x: int, z: int) -> float:
 return heights.get_pixel(clampi(x, 0, samples.x - 1), clampi(z, 0, samples.y - 1)).r

func height_at(p: Vector2) -> float:
 var q: Vector2 = ((p - garden.grid_min) / spacing).clamp(Vector2.ZERO, Vector2(samples - Vector2i.ONE))
 var x := mini(floori(q.x), samples.x - 2)
 var z := mini(floori(q.y), samples.y - 2)
 var f := q - Vector2(x, z)
 # Match the two actual mesh triangles, including their diagonal.
 if f.x + f.y <= 1.0:
  return _h(x, z) + f.x * (_h(x + 1, z) - _h(x, z)) + f.y * (_h(x, z + 1) - _h(x, z))
 return _h(x + 1, z + 1) + (1.0 - f.x) * (_h(x, z + 1) - _h(x + 1, z + 1)) + (1.0 - f.y) * (_h(x + 1, z) - _h(x + 1, z + 1))

func surface_at(p: Vector2) -> float:
 return maxf(WATER_LEVEL, height_at(p))

func _build_chunk(cell: Vector2i) -> void:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var uvs := PackedVector2Array()
 var indices := PackedInt32Array()
 for z in range(RESOLUTION + 1):
  for x in range(RESOLUTION + 1):
   var gx := cell.x * RESOLUTION + x
   var gz := cell.y * RESOLUTION + z
   var p: Vector2 = garden.grid_min + Vector2(gx, gz) * spacing
   vertices.append(Vector3(p.x, _h(gx, gz), p.y))
   normals.append(Vector3(_h(gx - 1, gz) - _h(gx + 1, gz),
    2.0 * spacing, _h(gx, gz - 1) - _h(gx, gz + 1)).normalized())
   uvs.append(p)
 for z in range(RESOLUTION):
  for x in range(RESOLUTION):
   var a := z * (RESOLUTION + 1) + x
   var b := a + 1
   var c := a + RESOLUTION + 1
   var d := c + 1
   indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 arrays[Mesh.ARRAY_INDEX] = indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 if garden.chunks.has(cell):
  var existing: MeshInstance3D=garden.chunks[cell]
  existing.mesh=mesh
  var collision: CollisionShape3D=existing.get_child(0).get_child(0)
  collision.set_deferred("shape",mesh.create_trimesh_shape())
  return
 var chunk := MeshInstance3D.new()
 chunk.name = "HeightChunk_%d_%d" % [cell.x, cell.y]
 chunk.mesh = mesh
 chunk.material_override = garden.terrain_material
 add_child(chunk)
 garden.chunks[cell] = chunk
 var body := StaticBody3D.new()
 body.collision_layer = 1
 body.collision_mask = 0
 var shape := CollisionShape3D.new()
 shape.shape = mesh.create_trimesh_shape()
 body.add_child(shape)
 chunk.add_child(body)

func _build_water() -> void:
 var plane := PlaneMesh.new()
 plane.size = Vector2(garden.chunk_count) * 2.0
 plane.subdivide_width = samples.x - 2
 plane.subdivide_depth = samples.y - 2
 var water := MeshInstance3D.new()
 water.name = "PondSurface"
 water.position.y = WATER_LEVEL
 water.mesh = plane
 water_material = ShaderMaterial.new()
 water_material.shader = preload("res://water.gdshader")
 for entry in [["water_color", "M_Water_BaseColor"], ["water_normal", "M_Water_Normal"], ["water_roughness", "M_Water_Roughness"], ["water_opacity", "M_Water_Opacity"], ["bottom_color", "M_RiverBottom_BaseColor"], ["bottom_ao", "M_RiverBottom_AO"]]:
  water_material.set_shader_parameter(entry[0], load("res://assets/textures/water/%s.tga" % entry[1]))
 water_material.set_shader_parameter("terrain_ids", garden.terrain_texture)
 water_material.set_shader_parameter("grid_size", Vector2(garden.grid_size))
 water_material.set_shader_parameter("micro_size", garden.MICRO_SIZE)
 water_material.set_shader_parameter("grid_min", garden.grid_min)
 water_material.set_shader_parameter("bed_heights", height_texture)
 water_material.set_shader_parameter("height_samples", Vector2(samples))
 water.material_override = water_material
 water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(water)

func _build_skirts() -> void:
 var vertices := PackedVector3Array()
 var perimeter: Array[Vector2i] = []
 for x in range(samples.x):
  perimeter.append(Vector2i(x, 0))
 for z in range(1, samples.y):
  perimeter.append(Vector2i(samples.x - 1, z))
 for x in range(samples.x - 2, -1, -1):
  perimeter.append(Vector2i(x, samples.y - 1))
 for z in range(samples.y - 2, 0, -1):
  perimeter.append(Vector2i(0, z))
 for i in range(perimeter.size()):
  var a := perimeter[i]
  var b := perimeter[(i + 1) % perimeter.size()]
  var pa: Vector2 = garden.grid_min + Vector2(a) * spacing
  var pb: Vector2 = garden.grid_min + Vector2(b) * spacing
  var top_a := Vector3(pa.x, _h(a.x, a.y), pa.y)
  var top_b := Vector3(pb.x, _h(b.x, b.y), pb.y)
  var low_a := Vector3(pa.x, BASE_LEVEL, pa.y)
  var low_b := Vector3(pb.x, BASE_LEVEL, pb.y)
  vertices.append_array(PackedVector3Array([top_a, low_a, top_b, top_b, low_a, low_b]))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var skirt := MeshInstance3D.new()
 skirt.mesh = mesh
 var earth := StandardMaterial3D.new()
 earth.albedo_color = Color("514331")
 earth.cull_mode = BaseMaterial3D.CULL_DISABLED
 skirt.material_override = earth
 add_child(skirt)

func _sample_rect(center: Vector2, radius: float) -> Rect2i:
 var low:=Vector2i(((center-Vector2.ONE*radius-garden.grid_min)/spacing).floor()).clamp(Vector2i.ONE,samples-Vector2i(2,2))
 var high:=Vector2i(((center+Vector2.ONE*radius-garden.grid_min)/spacing).ceil()).clamp(Vector2i.ONE,samples-Vector2i(2,2))
 return Rect2i(low,high-low+Vector2i.ONE)

func _rebuild_samples(rect: Rect2i) -> void:
 if rect.size==Vector2i.ZERO:return
 height_texture.update(heights)
 # Include a one-sample halo: neighbouring chunks share border vertices/normals.
 var low: Vector2i=Vector2i(Vector2(rect.position-Vector2i.ONE)/RESOLUTION).clamp(Vector2i.ZERO,garden.chunk_count-Vector2i.ONE)
 var high: Vector2i=Vector2i(Vector2(rect.end+Vector2i.ONE)/RESOLUTION).clamp(Vector2i.ZERO,garden.chunk_count-Vector2i.ONE)
 for z in range(low.y,high.y+1):
  for x in range(low.x,high.x+1):_build_chunk(Vector2i(x,z))
 sculpted.emit()

func _write_height(x: int, z: int, value: float) -> void:
 value=clampf(value,BASE_LEVEL+0.12,1.5)
 heights.set_pixel(x,z,Color(value,0,0))
 var index:=z*samples.x+x
 if absf(value-original_heights.get_pixel(x,z).r)<0.00001:edited.erase(index)
 else:edited[index]=value

func can_sculpt(cell: Vector2i, radius: float) -> bool:
 var point: Vector3=garden.cell_center(cell)
 for z in range(cell.y-2,cell.y+3):
  for x in range(cell.x-2,cell.x+3):
   var at:=Vector2i(x,z)
   if not garden.contains_cell(at):continue
   var p: Vector3=garden.cell_center(at)
   if Vector2(p.x-point.x,p.z-point.z).length()>radius+garden.MICRO_SIZE*0.72:continue
   if garden.blocked_cells.has(at) or garden.crops.has(at):return false
 for npc in get_tree().get_nodes_in_group("garden_npcs"):
  if npc.garden!=garden:continue
  var next: Vector3=garden.cell_center(npc.next_cell)
  if Vector2(npc.position.x-point.x,npc.position.z-point.z).length()<radius+npc.collision_radius+0.12:return false
  if Vector2(next.x-point.x,next.z-point.z).length()<radius+npc.collision_radius+0.12:return false
 return true

func sculpt(cell: Vector2i, mode: int) -> bool:
 if not garden.contains_cell(cell) or mode<0 or mode>3:return false
 var radius:=0.28 if mode==1 else 0.85
 if not can_sculpt(cell,radius):return false
 var at: Vector3=garden.cell_center(cell)
 var center:=Vector2(at.x,at.z)
 var rect:=_sample_rect(center,radius)
 var sample: Vector2i=Vector2i(((center-garden.grid_min)/spacing).round()).clamp(Vector2i.ZERO,samples-Vector2i.ONE)
 var baseline: float=original_heights.get_pixel(sample.x,sample.y).r
 var bottom:=maxf(BASE_LEVEL+0.12,minf(-0.18,at.y-0.18))
 for z in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   var distance: float=(garden.grid_min+Vector2(x,z)*spacing).distance_to(center)
   if distance>radius:continue
   var weight:=1.0-smoothstep(radius*0.25,radius,distance)
   var old:=_h(x,z)
   var original: float=original_heights.get_pixel(x,z).r
   var value:=old
   match mode:
    0:value=minf(old,lerpf(original,bottom,weight))
    1:value=minf(old,original-0.11*weight)
    2:value=original
    3:value=lerpf(old,baseline,weight)
   _write_height(x,z,value)
 if mode==1:seed_holes[cell]=true
 else:
  for hole in seed_holes.keys():
   var p: Vector3=garden.cell_center(hole)
   if Vector2(p.x,p.z).distance_to(center)<radius:seed_holes.erase(hole)
 for z in range(cell.y-2,cell.y+3):
  for x in range(cell.x-2,cell.x+3):
   var tile:=Vector2i(x,z)
   if not garden.contains_cell(tile):continue
   var p: Vector3=garden.cell_center(tile)
   if Vector2(p.x,p.z).distance_to(center)>radius:continue
   var kind: int=garden.get_terrain(tile)
   if mode==0:kind=garden.Terrain.DEEP_WATER if p.y < -0.45 else (garden.Terrain.WATER if p.y<0.0 else garden.Terrain.DIRT)
   elif mode in [1,2]:kind=garden.Terrain.DIRT
   elif kind in [garden.Terrain.WATER,garden.Terrain.DEEP_WATER] and p.y>=0.0:kind=garden.Terrain.DIRT
   garden.set_terrain(tile,kind)
 _rebuild_samples(rect)
 return true

func plant_seed(cell: Vector2i) -> void:
 if not seed_holes.has(cell):return
 var p: Vector3=garden.cell_center(cell)
 var center:=Vector2(p.x,p.z)
 var rect:=_sample_rect(center,0.28)
 for z in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   if (garden.grid_min+Vector2(x,z)*spacing).distance_to(center)<=0.28:
    _write_height(x,z,original_heights.get_pixel(x,z).r)
 seed_holes.erase(cell)
 _rebuild_samples(rect)

func save_deformation() -> Dictionary:
 var values:=[]
 for index in edited:values.append([index,edited[index]])
 var holes:=[]
 for cell in seed_holes:holes.append([cell.x,cell.y])
 return {"samples":[samples.x,samples.y],"heights":values,"seed_holes":holes}

func restore_deformation(data: Dictionary) -> void:
 var dimensions=data.get("samples",[])
 if not dimensions is Array or dimensions.size()!=2:return
 if Vector2i(int(dimensions[0]),int(dimensions[1]))!=samples:return
 var changed:=Rect2i()
 for value in data.get("heights",[]):
  if not value is Array or value.size()!=2:continue
  var index:=int(value[0])
  var height:=float(value[1])
  if index<0 or index>=samples.x*samples.y or not is_finite(height):continue
  var cell:=Vector2i(index%samples.x,index/samples.x)
  if cell.x==0 or cell.y==0 or cell.x==samples.x-1 or cell.y==samples.y-1:continue
  _write_height(cell.x,cell.y,height)
  var area:=Rect2i(cell,Vector2i.ONE)
  changed=area if changed.size==Vector2i.ZERO else changed.merge(area)
 for value in data.get("seed_holes",[]):
  if value is Array and value.size()==2:
   var cell:=Vector2i(int(value[0]),int(value[1]))
   if garden.contains_cell(cell):seed_holes[cell]=true
 _rebuild_samples(changed)
