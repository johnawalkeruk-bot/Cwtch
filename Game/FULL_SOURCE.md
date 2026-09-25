# CWTCH — full game source

## angus_npc.gd

```gd
extends "res://cycling_npc.gd"
## Angus performs his supplied long clip in place, rather than sliding to a walk.
func _create_visual() -> void:
	visual=preload("res://assets/npcs/angus.glb").instantiate()
	visual.name="AngusModel"
	visual.scale=Vector3.ONE*(1.5/0.999512)
	add_child(visual)
	collision_radius=0.35
	animation_player=visual.find_child("AnimationPlayer",true,false)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for library_name in animation_player.get_animation_library_list():
		var source:=animation_player.get_animation_library(library_name)
		var library:=AnimationLibrary.new()
		for clip_name in source.get_animation_list():
			var clip:=source.get_animation(clip_name).duplicate() as Animation
			_remove_root_motion(clip)
			clip.loop_mode=Animation.LOOP_LINEAR
			library.add_animation(clip_name,clip)
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name,library)
	for clip_name in animation_player.get_animation_list():
		if clip_name!="RESET":
			current_clip=clip_name
			animation_player.play(current_clip)
			break
	animation_player.advance(0.0)

func advance(delta: float) -> void:
	if garden.guide.visible: return
	animation_player.advance(delta)

```

## animal_notices.gd

```gd
extends CanvasLayer
## FIFO notices ensure an arrival and residency on the same frame are both seen.
const DURATION := 6.0
const TITLES := {"visit":"New visitor", "resident":"New resident", "birth":"A new arrival", "death":"A life remembered"}
var garden: Node3D
var queue: Array[Dictionary]=[]
var current: Dictionary={}
var elapsed := 0.0
var panel: PanelContainer
var heading: Label
var detail: Label
var date_label: Label

func setup(world: Node3D) -> void:
 garden=world
 layer=8
 panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.offset_left=28
 panel.offset_right=408
 panel.offset_top=-160
 panel.offset_bottom=-28
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_theme_stylebox_override("panel",garden._panel_style(Color("233b32")))
 var stack:=VBoxContainer.new()
 stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
 stack.add_theme_constant_override("separation",5)
 panel.add_child(stack)
 heading=garden._label("",19,Color("ebce8b"))
 detail=garden._label("",16,Color("f0eadb"))
 detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 date_label=garden._label("",13,Color("afc5b4"))
 for label in [heading,detail,date_label]:
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  stack.add_child(label)
 panel.hide()
 garden.wildlife.animal_event.connect(enqueue)

func enqueue(kind: String, species: String, event_day: int) -> void:
 if not TITLES.has(kind):return
 queue.append({"kind":kind,"species":species,"day":event_day})

func _process(delta: float) -> void:
 if garden.guide.visible:
  panel.hide()
  return
 if current.is_empty():
  if queue.is_empty():
   panel.hide()
   return
  current=queue.pop_front()
  elapsed=0.0
  heading.text=TITLES[current.kind]
  var animal: String=str(current.species).capitalize()
  match current.kind:
   "visit":detail.text=animal+" visited your garden."
   "resident":detail.text=animal+" became a resident."
   "birth":detail.text="A "+animal.to_lower()+" was born."
   "death":detail.text=animal+" has died."
  date_label.text="Day %d"%int(current.day)
 panel.show()
 elapsed+=delta
 panel.modulate.a=minf(smoothstep(0.0,0.3,elapsed),1.0-smoothstep(DURATION-0.5,DURATION,elapsed))
 panel.offset_left=28.0-12.0*(1.0-smoothstep(0.0,0.3,elapsed))
 panel.offset_right=panel.offset_left+380.0
 if elapsed>=DURATION:
  current={}
  panel.hide()

```

## animated_visitor.gd

```gd
extends "res://wandering_npc.gd"
## Uses the model's native rig and clips; no Arthur rig repair or retargeting.
const VISITOR_MODEL = preload("res://assets/test.glb")
const NORMAL_CLIPS := ["Walk_Female", "Idle_A", "Idle_Subtle", "Idle_FoldArms",
	"Idle_Listening", "Idle_Talking", "Greeting", "Reject", "Fixing_Kneeling"]
const VOICE_PATHS := [
	"res://audio/voice/ElevenLabs_2026-09-18T09_36_19__s100_v3.mp3",
	"res://audio/voice/ElevenLabs_2026-09-18T09_36_49__s100_v3.mp3",
	"res://audio/voice/ElevenLabs_2026-09-18T09_37_27__s100_v3.mp3"]
var voice: AudioStreamPlayer3D
var voice_clips: Array[AudioStream] = []
var last_voice := -1
var current_clip := ""
var remaining := 0.0
var choices: Array[String] = []
var rain_override := false
var voice_pending := false

func _create_visual() -> void:
	visual = VISITOR_MODEL.instantiate()
	visual.name = "AnimatedVisitorModel"
	visual.scale = Vector3.ONE * (1.5 / 1.823843)
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Private copies keep loop settings local to this visitor.
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name)
		for clip_name in library.get_animation_list():
			var clip := library.get_animation(clip_name).duplicate() as Animation
			clip.loop_mode = Animation.LOOP_LINEAR if clip_name in ["Walk_Female", "Shivering", "Idle_Talking", "Idle_A", "Idle_Subtle", "Idle_FoldArms", "Idle_Listening"] else Animation.LOOP_NONE
			library.remove_animation(clip_name)
			library.add_animation(clip_name, clip)
	voice = AudioStreamPlayer3D.new()
	voice.name = "VisitorVoice"
	voice.position.y = 1.3
	voice.volume_db = -5.0
	voice.unit_size = 3.0
	voice.max_distance = 12.0
	add_child(voice)
	for path in VOICE_PATHS:
		var stream := load(path) as AudioStream
		if stream is AudioStreamMP3:
			stream.loop = false
		voice_clips.append(stream)
	_choose_behavior()
	animation_player.advance(0.0)

func _choose_behavior() -> void:
	if choices.is_empty():
		choices.assign(NORMAL_CLIPS)
		# Fisher–Yates using the visitor's own random generator.
		for i in range(choices.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var saved := choices[i]
			choices[i] = choices[j]
			choices[j] = saved
		if choices.back() == current_clip:
			var saved := choices[0]
			choices[0] = choices[-1]
			choices[-1] = saved
	_start_behavior(choices.pop_back())

func _start_behavior(clip: String) -> void:
	voice.stop()
	voice_pending = false
	current_clip = clip
	walking = false
	animation_player.play(clip, 0.25)
	animation_player.speed_scale = 1.0
	remaining = animation_player.get_animation(clip).length
	if clip == "Walk_Female":
		remaining = rng.randf_range(7.0, 12.0)
	elif clip.begins_with("Idle_") and clip != "Idle_Talking":
		remaining *= rng.randi_range(2, 3)
	elif clip == "Idle_Talking":
		var next_voice := rng.randi_range(0, voice_clips.size() - 1)
		if next_voice == last_voice and voice_clips.size() > 1:
			next_voice = (next_voice + rng.randi_range(1, voice_clips.size() - 1)) % voice_clips.size()
		last_voice = next_voice
		voice.stream = voice_clips[next_voice]
		remaining = maxf(remaining, voice.stream.get_length())
		voice_pending = garden.guide.visible
		if not voice_pending:
			voice.play()
	voice.stream_paused = garden.guide.visible

func advance(delta: float) -> void:
	voice.stream_paused = garden.guide.visible
	if garden.guide.visible:
		return
	if voice_pending:
		voice_pending = false
		voice.play()
	var raining: bool = is_instance_valid(garden.valley_cycle) and garden.valley_cycle.rain_strength > 0.15
	if raining:
		if not rain_override:
			rain_override = true
			_start_behavior("Shivering")
	elif rain_override:
		rain_override = false
		_choose_behavior()
	if not rain_override:
		remaining -= delta
		if remaining <= 0.0:
			_choose_behavior()
	if current_clip == "Walk_Female":
		super.advance(delta)
	else:
		walking = false
	animation_player.speed_scale = 1.0
	animation_player.advance(delta * (motion_ratio if current_clip == "Walk_Female" else 1.0))

```

## arthur_hedgehog_subtitles.gd

```gd
extends RefCounted
## Generated locally from Arthur_Hedgehogs.mp3 with Whisper small.en word timestamps.
const CUES = [
 {
  "start": 0.0,
  "end": 3.59,
  "text": "Ho ho ho, look who's pottering about!"
 },
 {
  "start": 4.62,
  "end": 7.83,
  "text": "Must have wandered right down from the old tree line, I expect."
 },
 {
  "start": 9.12,
 "end": 11.15,
 "text": "Absolute creatures of habit, hedgehogs are,"
 },
 {
 "start": 11.48,
 "end": 13.17,
 "text": "snuffling about in the twilight,"
 },
 {
 "start": 13.58,
 "end": 17.03,
 "text": "always on a mission, and never in a rush for anyone."
 },
 {
 "start": 18.68,
  "end": 21.63,
  "text": "Marvellous little things to have about the place, truth be told."
 },
 {
  "start": 22.34,
  "end": 25.54775,
  "text": "Makes anywhere feel proper lived-in, don't they?"
 }
]

```

## arthur_speech_bubble.gd

```gd
extends PanelContainer
## Parchment speech bubble; the tail points back toward Arthur's portrait.
func _draw() -> void:
 var fill:=Color("f4ead2")
 var edge:=Color("b69755")
 var points:=PackedVector2Array([Vector2(2,42),Vector2(-23,63),Vector2(2,69)])
 draw_colored_polygon(points,fill)
 draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),edge,2.0,true)

```

## background_meadow.gd

```gd
extends Node3D
## Continuous surface-brush weights outside the editable grid.
const WIDTH := 512.0
var material: ShaderMaterial
var garden: Node3D
var contours := FastNoiseLite.new()

func build(world: Node3D) -> void:
	garden = world
	contours.seed = 1891
	contours.frequency = 0.14
	name = "BackgroundMeadow"
	material = garden.terrain_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("background_surface", true)
	material.set_shader_parameter("background_width", WIDTH)
	material.set_shader_parameter("brush_weights", _paint_surface())
	var half: Vector2 = Vector2(garden.chunk_count) * garden.CHUNK_SIZE * 0.5
	var outside := WIDTH * 0.5
	# Four adjacent surfaces meet exactly at the grid boundary, without overlap.
	_add_surface(Vector2(WIDTH, outside - half.y), Vector2(0, -(outside + half.y) * 0.5))
	_add_surface(Vector2(WIDTH, outside - half.y), Vector2(0, (outside + half.y) * 0.5))
	_add_surface(Vector2(outside - half.x, half.y * 2), Vector2(-(outside + half.x) * 0.5, 0))
	_add_surface(Vector2(outside - half.x, half.y * 2), Vector2((outside + half.x) * 0.5, 0))

func _add_surface(size: Vector2, center: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(1,ceili(size.x/2.0)-1)
	plane.subdivide_depth = maxi(1,ceili(size.y/2.0)-1)
	var mesh := MeshInstance3D.new()
	var arrays := plane.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		vertices[i].y = height_at(Vector2(vertices[i].x,vertices[i].z)+center)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var surface := SurfaceTool.new()
	var sculpted := ArrayMesh.new()
	sculpted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	surface.create_from(sculpted,0)
	surface.generate_normals()
	mesh.mesh = surface.commit()
	mesh.position = Vector3(center.x, 0, center.y)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _paint_surface() -> ImageTexture:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1891
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var half: Vector2 = Vector2(garden.chunk_count) * garden.CHUNK_SIZE * 0.5
	for y in range(512):
		for x in range(512):
			var point := (Vector2(x, y) / 511.0 - Vector2.ONE * 0.5) * WIDTH
			var beyond := (point.abs() - half).max(Vector2.ZERO).length()
			var edge := smoothstep(1.0, 7.0, beyond)
			# Broad soft brush strokes, not individual background cells.
			var damp := smoothstep(-0.15, 0.55, noise.get_noise_2dv(point)) * 0.7 * edge
			var soil := smoothstep(0.25, 0.7, noise.get_noise_2dv(point + Vector2(81, 23))) * 0.5 * edge
			var rock := smoothstep(0.4, 0.8, noise.get_noise_2dv(point * 1.8 + Vector2(12, 48))) * 0.45 * edge
			image.set_pixel(x, y, Color(maxf(0.0, 1.0 - damp - soil - rock), damp, soil, rock))
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	if is_instance_valid(garden):
		material.set_shader_parameter("wetness", garden.valley_cycle.wetness)
		material.set_shader_parameter("world_to_grid", garden.global_transform.affine_inverse())

func height_at(point: Vector2) -> float:
	var half: Vector2 = Vector2(garden.chunk_count)
	var outside := (point.abs()-half).max(Vector2.ZERO).length()
	var fade := smoothstep(0.0,3.0,outside)*(1.0-smoothstep(20.0,24.0,point.length()))
	return maxf(0.0,0.3+contours.get_noise_2dv(point)*0.55)*fade

```

## bake_desktop_textures.gd

```gd
extends SceneTree
## Run once with Godot --path . --script bake_desktop_textures.gd.
## A graphics renderer is required to save Texture2DArray image data.
## Arrays share dimensions and wrap identically, preserving terrain transitions.
const SETS := ["dirt/Ground106", "grass/Grass002", "stone/Rock062", "gravel/Gravel040", "wet grass/Grass003"]
const SIZE := 512

func source_image(prefix: String, suffix: String) -> Image:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://assets/textures/%s_1K-JPG_%s.jpg" % [prefix, suffix])
	assert(image.load_jpg_from_buffer(bytes) == OK)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this bake with a graphics renderer, without --headless.")
		quit(1)
		return
	var colors: Array[Image] = []
	var normals: Array[Image] = []
	var details: Array[Image] = []
	for prefix in SETS:
		var color := source_image(prefix, "Color")
		var normal := source_image(prefix, "NormalGL")
		var height := source_image(prefix, "Displacement")
		var roughness := source_image(prefix, "Roughness")
		var ao := source_image(prefix, "AmbientOcclusion")
		var data := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		for y in range(SIZE):
			for x in range(SIZE):
				data.set_pixel(x, y, Color(height.get_pixel(x, y).r, roughness.get_pixel(x, y).r, ao.get_pixel(x, y).r, 1.0))
		color.generate_mipmaps()
		normal.generate_mipmaps()
		data.generate_mipmaps()
		colors.append(color)
		normals.append(normal)
		details.append(data)
	for entry in [["colors", colors], ["normals", normals], ["details", details]]:
		var array := Texture2DArray.new()
		assert(array.create_from_images(entry[1]) == OK)
		assert(ResourceSaver.save(array, "res://assets/textures/terrain_%s.res" % entry[0]) == OK)
	print("Baked five aligned terrain layers: color, OpenGL normal, height/roughness/AO.")
	quit()

```

## bake_tool_icons.gd

```gd
extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(1.3,0.8,2.6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 1.2
	scene.add_child(light)
	for i in range(4):
		var model := preload("res://floating_tool.gd").make_model(i)
		scene.add_child(model)
		camera.size = 1.1 if i==3 else (0.95 if i==0 else 0.72)
		print("TOOL BOUNDS ",i," ",preload("res://floating_tool.gd").bounds(model))
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/tools/%s_icon.png" % ["hoe","seeds","water","shovel"][i])
		model.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	quit()

```

## blender_tile.py

```py
import bpy
from pathlib import Path

# Save the .blend first to choose the export folder; otherwise use Blender's temp.
folder = Path(bpy.path.abspath("//")) if bpy.data.filepath else Path(bpy.app.tempdir)
target = folder / "ground_tile.glb"
name = "AberglenGroundTile"
old = bpy.data.objects.get(name)
if old:
    bpy.data.objects.remove(old, do_unlink=True)

bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
# Blender XY ground becomes Godot XZ ground through glTF's Y-up conversion.
# Sixteen vertices, nine quads; origin at the center of the surface.
vertices = [(x * 2.0 / 3.0 - 1.0, y * 2.0 / 3.0 - 1.0, 0.0)
            for y in range(4) for x in range(4)]
faces = []
for y in range(3):
    for x in range(3):
        i = y * 4 + x
        faces.append((i, i + 1, i + 5, i + 4))
mesh = bpy.data.meshes.new(name + "Mesh")
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name="UVMap")
for polygon in mesh.polygons:
    polygon.use_smooth = False
    for loop_index in polygon.loop_indices:
        co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uv.data[loop_index].uv = ((co.x + 1.0) / 2.0, (co.y + 1.0) / 2.0)
tile = bpy.data.objects.new(name, mesh)
bpy.context.collection.objects.link(tile)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
tile.select_set(True)
bpy.context.view_layer.objects.active = tile
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
                          use_selection=True, export_yup=True,
                          export_animations=False)
print(f"Exported 2m x 2m ground tile: {target}")

```

## book_opening.gd

```gd
extends Control
## Perspective-like hinged leaves, drawn in the same coordinates as the spread.
signal finished
var elapsed := 0.0
var active := false
var font: SystemFont
const HOLD := 0.65
const DURATION := 3.15

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Segoe Print","Ink Free","Segoe Script"])
	hide()

func start() -> void:
	elapsed=0.0
	active=true
	show()
	queue_redraw()

func stop() -> void:
	active=false
	hide()

func _process(delta: float) -> void:
	if not active: return
	elapsed=minf(DURATION,elapsed+delta)
	queue_redraw()
	if elapsed>=DURATION:
		stop()
		finished.emit()

func _ease(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _box(color: Color, radius: int=8) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(radius)
	return box

func _draw() -> void:
	var reveal:=_ease((elapsed-HOLD)/1.75)
	# A closed book begins at screen centre, then settles into the open spread.
	var shift:=-270.0*(1.0-reveal)
	draw_set_transform(Vector2(shift,0))
	draw_style_box(_box(Color(0,0,0,0.4),16),Rect2(548,14,540,590))
	draw_style_box(_box(Color("4b2c1d"),14),Rect2(538,0,542,600))
	for i in range(6):
		draw_style_box(_box(Color("b49b72").lerp(Color("ecd9b1"),i/6.0),4),Rect2(545,17-i,519+i,570))
	draw_style_box(_box(Color("f0dfbb"),4),Rect2(544,24,504,552))
	# Cover turns first, followed by two overlapping flyleaves.
	_leaf(_ease((elapsed-HOLD)/1.55),true,shift)
	for i in range(2):
		var progress:=_ease((elapsed-HOLD-0.65-i*0.30)/1.25)
		if progress>0.0: _leaf(progress,false,shift)
	draw_set_transform(Vector2.ZERO)

func _leaf(progress: float, leather: bool, shift: float) -> void:
	var angle:=progress*PI
	var width:=(540.0 if leather else 505.0)*cos(angle)
	var lift:=sin(angle)*32.0
	var top:=0.0 if leather else 24.0
	var bottom:=600.0 if leather else 576.0
	var edge:=540.0+width
	draw_set_transform(Vector2(shift,0))
	var polygon:=PackedVector2Array([Vector2(540,top),Vector2(edge,top-lift),Vector2(edge,bottom+lift),Vector2(540,bottom)])
	var color:=Color("593721") if leather and progress<0.5 else Color("e9d5ab")
	color=color.darkened(sin(angle)*0.22)
	draw_colored_polygon(polygon,color)
	draw_polyline(PackedVector2Array([polygon[0],polygon[1],polygon[2],polygon[3],polygon[0]]),Color("997347"),2,true)
	if leather and progress<0.5 and width>5:
		# Decorations squash with the front cover as it swings around the spine.
		draw_set_transform(Vector2(540+shift,0),0,Vector2(width/540.0,1))
		var random:=RandomNumberGenerator.new()
		random.seed=1891
		for i in range(1700):
			draw_circle(Vector2(random.randf_range(12,528),random.randf_range(12,588)),random.randf_range(.4,1.4),Color(0.8,0.61,0.35,0.11))
		draw_rect(Rect2(26,26,488,548),Color("b18b51"),false,2)
		draw_rect(Rect2(34,34,472,532),Color("82613d"),false,1)
		for y in range(46,557,10):
			draw_line(Vector2(17,y),Vector2(17,y+4),Color("b69260"))
			draw_line(Vector2(523,y),Vector2(523,y+4),Color("b69260"))
		_gold("C W T C H",198,39)
		_gold("FIELD GUIDE",254,27)
		_gold("Your slice of the valley",430,18)
		draw_arc(Vector2(270,330),42,0,TAU,60,Color("c5a363"),2,true)
		draw_polyline(PackedVector2Array([Vector2(236,345),Vector2(262,314),Vector2(276,330),Vector2(290,305),Vector2(307,345)]),Color("c5a363"),2,true)
	elif not leather:
		for i in range(12):
			var x:=540+width*(i/12.0)
			draw_line(Vector2(x,top),Vector2(x,bottom),Color(0.35,0.22,0.09,0.05*sin(angle)),2)
	draw_set_transform(Vector2(shift,0))

func _gold(text: String, y: float, font_size: int) -> void:
	var x:=(540-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)*0.5
	draw_string(font,Vector2(x+1,y+2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("28170f"))
	draw_string(font,Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d8b879"))

```

## chicken_npc.gd

```gd
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

```

## controller_input.gd

```gd
extends Node
## Common mapped controllers: left stick moves, right stick aims.
signal mode_changed
signal disconnected
var using_pad := false
var device := -1

func _ready() -> void:
	for entry in [["pad_left",JOY_AXIS_LEFT_X,-1.0],["pad_right",JOY_AXIS_LEFT_X,1.0],["pad_up",JOY_AXIS_LEFT_Y,-1.0],["pad_down",JOY_AXIS_LEFT_Y,1.0],["look_left",JOY_AXIS_RIGHT_X,-1.0],["look_right",JOY_AXIS_RIGHT_X,1.0],["look_up",JOY_AXIS_RIGHT_Y,-1.0],["look_down",JOY_AXIS_RIGHT_Y,1.0],["pad_use",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		InputMap.add_action(entry[0],0.22)
		var event := InputEventJoypadMotion.new()
		event.axis=entry[1]
		event.axis_value=entry[2]
		InputMap.action_add_event(entry[0],event)
	for entry in [["pad_guide",JOY_BUTTON_START],["pad_tardis",JOY_BUTTON_RIGHT_STICK]]:
		InputMap.add_action(entry[0])
		var event := InputEventJoypadButton.new()
		event.button_index=entry[1]
		InputMap.action_add_event(entry[0],event)
	for entry in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.button_index=entry[1]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	for entry in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis=entry[1]
		event.axis_value=entry[2]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	Input.joy_connection_changed.connect(_connection)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>0.25:
		device=event.device
		_set_mode(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion and event.relative.length()>2.0:
		_set_mode(false)

func _set_mode(pad: bool) -> void:
	if using_pad==pad: return
	using_pad=pad
	mode_changed.emit()

func _connection(id: int, connected: bool) -> void:
	if not connected and id==device:
		device=-1
		_set_mode(false)
		disconnected.emit()

func movement() -> Vector2:
	return Input.get_vector("pad_left","pad_right","pad_up","pad_down",0.22)

func look() -> Vector2:
	return Input.get_vector("look_left","look_right","look_up","look_down",0.22)

func focus_first(parent) -> void:
	if not using_pad or not is_instance_valid(parent): return
	for control in parent.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and control.focus_mode==Control.FOCUS_ALL:
			control.grab_focus()
			return

```

## cosy_sky.gdshader

```gdshader
shader_type sky;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.25);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.15;
uniform float cycle_time = 0.0;
uniform float lightning = 0.0;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float clouds(vec3 p) {
 float value=0.0,weight=0.55;
 for(int i=0;i<5;i++){value+=noise(p)*weight;p=p*2.03+vec3(17.1,9.2,4.7);weight*=0.48;}
 return value;
}
void sky() {
 vec3 direction=normalize(EYEDIR),sun_dir=normalize(sun_direction);
 float elevation=direction.y;
 float twilight=(1.0-smoothstep(0.02,0.38,abs(sun_dir.y)))*smoothstep(-0.22,0.02,sun_dir.y);
 vec3 horizon=mix(vec3(0.72,0.76,0.76),vec3(0.92,0.58,0.43),twilight*0.75);
 vec3 zenith=mix(vec3(0.29,0.43,0.55),vec3(0.40,0.34,0.53),twilight*0.65);
 vec3 sky_color=mix(horizon,zenith,smoothstep(0.0,0.85,elevation));
 sky_color=mix(vec3(0.007,0.014,0.035)+sky_color*0.025,sky_color,daylight);
 // Smooth 3D density has no panorama seam or pinched poles.
 vec3 p=direction*vec3(5.5,3.0,5.5)+vec3(cycle_time*0.0018,0.0,cycle_time*0.0006);
 float density=clouds(p);
 float threshold=mix(0.62,0.23,cloud_cover);
 float cover=smoothstep(threshold,threshold+0.17,density)*smoothstep(-0.04,0.15,elevation);
 float wisps=smoothstep(0.57,0.73,clouds(p*1.8+vec3(40.0)))*0.24;
 cover=clamp(cover+wisps*smoothstep(0.0,0.3,elevation),0.0,1.0);
 // Fine, softly filtered star points with warmer and cooler individual colours.
 vec2 star_grid=vec2(atan(direction.z,direction.x)/6.2831853+0.5,acos(clamp(elevation,-1.0,1.0))/3.14159265)*vec2(800.0,400.0);
 vec2 cell=floor(star_grid);
 float seed=hash(vec3(mod(cell.x,800.0),cell.y,11.0));
 vec2 centre=vec2(hash(vec3(cell,23.0)),hash(vec3(cell,49.0)))*0.5+0.25;
 vec2 offset=fract(star_grid)-centre;
 float star=exp(-dot(offset,offset)*160.0)*step(0.995,seed);
 star*=0.8+0.2*sin(cycle_time*1.2+seed*900.0);
 vec3 star_color=mix(vec3(0.64,0.77,1.0),vec3(1.0,0.88,0.67),hash(vec3(cell,8.0)));
 sky_color+=star_color*star*pow(1.0-daylight,3.0)*smoothstep(0.02,0.3,elevation)*1.7;
 float sun=smoothstep(0.9993,0.9998,dot(direction,sun_dir));
 float halo=pow(max(dot(direction,sun_dir),0.0),60.0);
 float moon=smoothstep(0.9994,0.9998,dot(direction,-sun_dir));
 sky_color+=vec3(1.0,0.76,0.47)*(sun*1.3+halo*0.15)*daylight;
 sky_color+=vec3(0.53,0.65,0.85)*moon*(1.0-daylight);
 float lit=clamp(0.45+(density-clouds(p+sun_dir*0.18))*3.0,0.0,1.0);
 vec3 cloud_day=mix(vec3(0.39,0.46,0.49),vec3(0.89,0.89,0.82),lit);
 cloud_day=mix(cloud_day,vec3(0.81,0.58,0.50),twilight*0.32);
 vec3 cloud_color=mix(vec3(0.023,0.033,0.055),cloud_day,daylight);
 sky_color=mix(sky_color,cloud_color,cover*0.97);
 COLOR=mix(sky_color,vec3(0.80,0.87,0.98),clamp(lightning,0.0,1.0)*0.4);
}

```

## cursor.gdshader

```gdshader
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 highlight : source_color = vec4(1.0, 0.85, 0.45, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ring = smoothstep(0.83, 0.89, radius) * (1.0 - smoothstep(0.96, 1.0, radius));
	float swirl = pow(0.5 + 0.5 * sin(angle * 3.0 - TIME * 2.0 + radius * 7.0), 3.0);
	ALBEDO = mix(vec3(0.21,0.62,0.92), highlight.rgb, swirl);
	ALPHA = ring * (0.35 + 0.65 * swirl) * highlight.a;
}

```

## cwtch_theme.gd

```gd
extends RefCounted
const INK := Color("172d2a")
const GOLD := Color("e5c17c")
const CREAM := Color("f3ead4")
const MUTED := Color("b2c6bb")

static func panel(color: Color = Color(0.06,0.13,0.12,0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.76,0.65,0.42,0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0,0.025,0.02,0.22)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0,4)
	return style

static func make() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Arial"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_color("font_color","Label",CREAM)
	theme.set_stylebox("panel","PanelContainer",panel())
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,panel(Color("213c35")))
		theme.set_stylebox("hover",type,panel(Color("355347")))
		theme.set_stylebox("pressed",type,panel(Color("132b26")))
		var focus := panel(Color(0,0,0,0))
		focus.border_color = GOLD
		focus.set_border_width_all(2)
		theme.set_stylebox("focus",type,focus)
		theme.set_color("font_color",type,CREAM)
		theme.set_color("font_hover_color",type,GOLD)
		theme.set_color("font_pressed_color",type,GOLD)
	theme.set_stylebox("panel","PopupMenu",panel())
	theme.set_color("font_color","PopupMenu",CREAM)
	return theme

```

## cycling_npc.gd

```gd
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

```

## developer_console.gd

```gd
extends CanvasLayer
var garden: Node3D
var backdrop: ColorRect
var panel: PanelContainer
var output: RichTextLabel
var command: LineEdit
var history: Array[String]=[]
var history_index := 0
var opened := false

func setup(world: Node3D) -> void:
 garden=world
 layer=100
 backdrop=ColorRect.new()
 add_child(backdrop)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color=Color(0,0,0,0.22)
 backdrop.hide()
 panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 panel.offset_left=32
 panel.offset_right=-32
 panel.offset_top=96
 panel.offset_bottom=390
 panel.add_theme_stylebox_override("panel",garden._panel_style(Color(0.06,0.11,0.10,0.97)))
 var stack:=VBoxContainer.new()
 panel.add_child(stack)
 stack.add_child(garden._label("DEVELOPER CONSOLE   ·   ` / ESC to close",18,Color("ebce8b")))
 output=RichTextLabel.new()
 output.custom_minimum_size.y=170
 output.size_flags_vertical=Control.SIZE_EXPAND_FILL
 output.scroll_following=true
 output.selection_enabled=true
 output.add_theme_font_size_override("normal_font_size",16)
 stack.add_child(output)
 command=LineEdit.new()
 command.placeholder_text="help • time 18:30 • weather heavy rain • tardis land"
 command.add_theme_font_size_override("font_size",18)
 command.text_submitted.connect(_submit)
 stack.add_child(command)
 panel.hide()
 _write("Time, weather and the TARDIS. Type help for commands. ↑ / ↓ recalls commands.")

func toggle(value: bool) -> void:
 opened=value
 panel.visible=value
 backdrop.visible=value
 garden._clear_use()
 garden.player.velocity=Vector3.ZERO
 if value:
  if garden.tool_wheel.visible:garden._set_wheel(false)
  garden.aiming=false
  garden.aim_dot.hide()
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  command.grab_focus()
 else:
  command.release_focus()
  garden.aiming=not garden.guide.visible
  garden.aim_dot.visible=garden.aiming
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if garden.aiming else Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
 if is_instance_valid(garden.hedgehog_intro) and garden.hedgehog_intro.active:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_QUOTELEFT or event.keycode==KEY_QUOTELEFT:
   if not garden.field_book.visible:toggle(not opened)
   get_viewport().set_input_as_handled()
   return
  if opened and event.keycode==KEY_ESCAPE:
   toggle(false)
   get_viewport().set_input_as_handled()
   return
  if opened and event.keycode in [KEY_UP,KEY_DOWN]:
   history_index=clampi(history_index+(-1 if event.keycode==KEY_UP else 1),0,history.size())
   command.text=history[history_index] if history_index<history.size() else ""
   command.caret_column=command.text.length()
   get_viewport().set_input_as_handled()
 if opened and (event is InputEventMouseMotion or event is InputEventJoypadButton or event is InputEventJoypadMotion):
  get_viewport().set_input_as_handled()

func _write(text: String) -> void:
 output.add_text(text+"\n")
 if output.get_line_count()>180:output.clear()

func _submit(text: String) -> void:
 var clean:=text.strip_edges()
 if clean.is_empty():return
 history.append(clean)
 if history.size()>50:history.pop_front()
 history_index=history.size()
 _write("> "+clean)
 _write(execute(clean))
 command.clear()

func execute(text: String) -> String:
 var words:=text.strip_edges().to_lower().split(" ",false)
 if words.is_empty():return "Type help."
 var args: String=" ".join(words.slice(1))
 match words[0]:
  "help":return "time HH:MM | weather fair / cloudy / light rain / rain / heavy rain / thunderstorm / clearing\ntardis land | tardis takeoff | tardis visit | tardis status\nVisit lands, stays for 20 seconds, then takes off. Time and weather continue cycling."
  "time":
   var parts:=args.split(":")
   if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():return "Use time HH:MM (24-hour clock)."
   var hour:=int(parts[0])
   var minute:=int(parts[1])
   if hour<0 or hour>23 or minute<0 or minute>59:return "Use an hour from 00–23 and minutes from 00–59."
   var cycle: Node3D=garden.valley_cycle
   cycle.elapsed=floor(cycle.elapsed/cycle.FULL_CYCLE)*cycle.FULL_CYCLE+fposmod(float(hour*60+minute-360),1440.0)/1440.0*cycle.FULL_CYCLE
   cycle._update_visuals()
   return "Time set to %02d:%02d."%[hour,minute]
  "weather":
   var cycle: Node3D=garden.valley_cycle
   var index: int=-1
   for i in cycle.WEATHER_NAMES.size():
    if cycle.WEATHER_NAMES[i].to_lower()==args.replace("_"," "):index=i
   if index<0:return "Weather: fair, cloudy, light rain, rain, heavy rain, thunderstorm, clearing."
   cycle.weather_index=index
   cycle.weather_elapsed=0.0
   cycle.rain_strength=cycle.RAIN_LEVELS[index]
   cycle.cloud_cover=cycle.CLOUD_LEVELS[index]
   cycle.lightning_energy=0.0
   cycle.thunder_delay=-1.0
   cycle.storm_wait=3.0
   cycle._update_visuals()
   return "Weather set to "+cycle.WEATHER_NAMES[index]+"."
  "tardis":
   match args:
    "land":return garden.tardis.land(false)
    "visit":return garden.tardis.land(true)
    "takeoff", "take off":return garden.tardis.takeoff()
    "status":return "TARDIS: "+garden.tardis.state+"."
   return "Use tardis land, tardis takeoff, tardis visit or tardis status."
 return "Unknown command. Type help."

```

## diorama_camera.gd

```gd
extends RefCounted

const CAMERA_HEIGHT := 1.5
const SPIRIT_HEIGHT := 0.10

static func configure(camera: Camera3D, feet: Vector3 = Vector3.ZERO) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	# Frame the spirit and nearby ground with a natural perspective.
	camera.fov = 75.0
	camera.near = 0.03
	camera.far = 250.0
	camera.current = true
	follow(camera, feet, 0.0)

static func follow(camera: Camera3D, feet: Vector3, yaw: float, pitch: float = PI / 4.0) -> void:
	# Follow behind the spirit, but let the mouse freely aim the lens.
	# Fixed follow distance avoids the old pitch-dependent camera zoom/lock.
	var distance := CAMERA_HEIGHT - SPIRIT_HEIGHT
	camera.position = feet + Vector3(sin(yaw) * distance, CAMERA_HEIGHT, cos(yaw) * distance)
	camera.rotation = Vector3(-pitch, yaw, 0.0)

```

## export_presets.cfg

```cfg
[preset.0]
name="Windows Portable"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="audio/ambience/*.wav"
exclude_filter="runtime/*,*-preview.png,preview.png,assets/tools/*_source.glb,assets/trees/ash.glb,assets/trees/birch.glb"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false

```

## field_book.gd

```gd
extends Control
## A separate lit 3D world keeps book previews independent of the paused garden.
signal closed
const INK := Color("483322")
const ENTRIES := [
 ["People","Arthur","Arthur brings a steady pace to the garden. Between quiet walks he pauses to enjoy the valley, content to let the day unfold.","Arthur"],
 ["People","Meera","A familiar face among the garden paths. Meera wanders between the plots and the wild edge, taking in the changing light.","Meera"],
 ["People","Angus McDoogal","There is always a little movement where Angus stands. His lively gestures bring a welcome touch of company to a quiet afternoon.","Angus"],
 ["People","The visitor","A traveller passing through the valley. Stop for a moment and watch: even an unhurried garden has its small conversations.","WanderingVisitor"],
 ["Animals","Peacock","A colourful garden companion, with an iridescent neck and a magnificent tail.","Peacock"],
 ["Animals","Chicken","A small, busy companion on the garden paths. Watch those quick steps and curious pauses as it explores the ground.","WanderingChicken"],
 ["Animals","Hedgehog","Low to the ground and never in a hurry. The hedgehog noses around the garden, stopping now and then before continuing its little journey.","Hedgehog"],
 ["Animals","Badger","A sturdy visitor with a distinctive striped face. The badger takes slow turns around the plots and shares the paths with its neighbours.","Badger"],
 ["Animals","Dragon","A little valley wonder. Folded wings, a restless tail and gentle movements make this unusual garden guest hard to overlook.","Dragon"],
 ["Plants","Ash","Tall woodland shapes frame the valley beyond the garden. Turn this specimen to see the branching crown and the texture of its trunk.","res://assets/trees/ash_forest.glb"],
 ["Plants","Birch","Pale trunks catch the changing light at the wild edge. Birch trees soften the transition from tended ground to the woodland beyond.","res://assets/trees/birch_forest.glb"]
]
var garden: Node3D
var page := 0
var category := "People"
var entries: Array[int] = []
var spread: Control
var title: Label
var description: Label
var visit_notes: Label
var folio: Label
var section: Label
var land_page: Control
var preview_holder: SubViewportContainer
var viewport: SubViewport
var turntable: Node3D
var preview: Node3D
var previous: Button
var tabs: Array[Button] = []
var navigation_hint: Label
const CATEGORIES := ["People","Animals","Plants","Land area"]
var serif: SystemFont
var opening: Control
var reveal_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	serif=SystemFont.new()
	serif.font_names=PackedStringArray(["Segoe Print","Ink Free","Segoe Script"])
	spread=Control.new()
	add_child(spread)
	spread.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	spread.offset_left=-540
	spread.offset_right=540
	spread.offset_top=-300
	spread.offset_bottom=300
	spread.draw.connect(_draw_book)
	_text("C W T C H   /   F I E L D   N O T E S",Vector2(76,48),Vector2(470,28),17)
	for i in CATEGORIES.size():
		var label: String=CATEGORIES[i]
		var tab:=_button(label,Vector2(-82,154+i*70),Vector2(128,54),func(): _category(label))
		tabs.append(tab)
	navigation_hint=_text("LB / RB  ·  category\nArrows  ·  entries     B / Esc  ·  close",Vector2(580,48),Vector2(425,76),15)
	section=_text("",Vector2(84,98),Vector2(410,28),14)
	title=_text("",Vector2(580,139),Vector2(405,65),35)
	description=_text("",Vector2(580,232),Vector2(395,210),21)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	visit_notes=_text("",Vector2(580,446),Vector2(410,76),16)
	folio=_text("",Vector2(450,542),Vector2(160,28),15)
	folio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	previous=_button("‹  Previous",Vector2(80,533),Vector2(150,38),func(): _turn(-1))
	_button("Next  ›",Vector2(240,533),Vector2(130,38),func(): _turn(1))
	_button("Close book",Vector2(823,533),Vector2(175,38),close)
	var holder:=SubViewportContainer.new()
	preview_holder=holder
	holder.position=Vector2(80,138)
	holder.size=Vector2(420,365)
	holder.stretch=true
	holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spread.add_child(holder)
	viewport=SubViewport.new()
	viewport.size=Vector2i(420,365)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	holder.add_child(viewport)
	turntable=Node3D.new()
	viewport.add_child(turntable)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.7
	camera.position=Vector3(0,0.3,4)
	camera.look_at(Vector3.ZERO)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("fff0d8")
	environment.environment.ambient_light_energy=0.75
	viewport.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	light.light_energy=1.2
	viewport.add_child(light)
	land_page=preload("res://land_area_page.gd").new()
	spread.add_child(land_page)
	land_page.hide()
	opening=preload("res://book_opening.gd").new()
	add_child(opening)
	opening.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	opening.offset_left=-540
	opening.offset_right=540
	opening.offset_top=-300
	opening.offset_bottom=300
	opening.finished.connect(_finish_opening)
	hide()

func _finish_opening() -> void:
	spread.show()
	spread.modulate.a=0.0
	reveal_tween=create_tween()
	reveal_tween.tween_property(spread,"modulate:a",1.0,0.25)
	var focused:=get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func _text(value: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label:=Label.new()
	label.text=value
	label.position=at
	label.size=dimensions
	label.add_theme_font_override("font",serif)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spread.add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button:=Button.new()
	button.text=value
	button.focus_mode=Control.FOCUS_NONE
	button.position=at
	button.size=dimensions
	button.add_theme_font_override("font",serif)
	button.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("d9bc85") if state in ["hover","pressed"] else Color("e6d0a1")
		style.border_color=Color("866037")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_"+state+"_color",INK)
	button.add_theme_color_override("font_color",INK)
	button.pressed.connect(action)
	spread.add_child(button)
	return button

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.012,0.008,0.78))

func _draw_book() -> void:
	spread.draw_style_box(_panel(Color(0,0,0,0.4),18),Rect2(9,14,1080,600))
	spread.draw_style_box(_panel(Color("4b2c1d"),16),Rect2(0,0,1080,600))
	# Deterministic leather grain and rubbed edges, drawn without bitmap assets.
	var random:=RandomNumberGenerator.new()
	random.seed=1891
	for i in range(2800):
		spread.draw_circle(Vector2(random.randf_range(8,1072),random.randf_range(8,592)),random.randf_range(.3,1.2),Color(0.76,0.55,0.31,0.12))
	for x in range(24,1060,9):
		spread.draw_line(Vector2(x,14),Vector2(x+4,14),Color("a07b4b"))
		spread.draw_line(Vector2(x,586),Vector2(x+4,586),Color("a07b4b"))
	spread.draw_style_box(_panel(Color("bea275"),5),Rect2(28,29,1024,548))
	spread.draw_style_box(_panel(Color("eddbb2"),5),Rect2(32,24,505,552))
	spread.draw_style_box(_panel(Color("f0dfbb"),5),Rect2(543,24,505,552))
	for x in range(515,566):
		spread.draw_line(Vector2(x,25),Vector2(x,575),Color(0.22,0.12,0.04,0.24*(1.0-absf(x-540)/26.0)),1)
	for i in range(700):
		spread.draw_circle(Vector2(random.randf_range(42,1038),random.randf_range(30,570)),random.randf_range(.3,1.1),Color(0.35,0.2,0.08,0.055))
	spread.draw_line(Vector2(580,214),Vector2(986,214),Color("aa8954"),1)
	spread.draw_line(Vector2(82,512),Vector2(498,512),Color("aa8954"),1)

func _panel(color: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	return style

func open(world: Node3D) -> void:
	garden=world
	show()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_category(category)
	if reveal_tween: reveal_tween.kill()
	spread.hide()
	spread.modulate.a=1.0
	opening.start()

func close() -> void:
	opening.stop()
	if reveal_tween: reveal_tween.kill()
	hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(preview):
		preview.free()
		preview=null
	closed.emit()

func _category(value: String) -> void:
	category=value
	for tab in tabs:
		tab.modulate=Color("ffe5ae") if tab.text==category else Color("b9aa8c")
	entries.clear()
	for i in ENTRIES.size():
		if ENTRIES[i][0]==category:
			if category!="Animals" or garden.wildlife.records.has(str(ENTRIES[i][1]).to_lower()): entries.append(i)
	page=0
	_show_entry()

func _turn(direction: int) -> void:
	if category=="Land area":
		land_page.turn(direction)
		return
	if entries.is_empty():return
	page=posmod(page+direction,entries.size())
	_show_entry()

func _show_entry() -> void:
	visit_notes.text=""
	var land: bool=category=="Land area"
	land_page.visible=land
	preview_holder.visible=not land
	description.visible=not land
	if land:
		if is_instance_valid(preview):preview.free();preview=null
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		land_page.setup(garden,serif)
		title.text="Land area"
		section.text="LAND AREA   /   GARDEN SURVEY"
		navigation_hint.text="LB / RB  ·  category\nArrows / hover  ·  inspect tiles"
		folio.text="Garden survey"
		return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	navigation_hint.text="LB / RB  ·  category\nArrows  ·  entries     B / Esc  ·  close"
	if entries.is_empty():
		title.text="No animal visits yet"
		description.text="Make a little grass and watch the wild edge. Your first visitor will appear here after entering the garden."
		section.text=category.to_upper()
		folio.text="-"
		if is_instance_valid(preview):preview.free();preview=null
		return
	var entry: Array=ENTRIES[entries[page]]
	title.text=entry[1]
	description.text=entry[2]
	if category=="Animals":
		var record: Dictionary=garden.wildlife.records[str(entry[1]).to_lower()]
		visit_notes.text="First visit: Day %d\n"%int(record.visit_day)
		visit_notes.text+=("Resident since: Day %d"%int(record.resident_day)) if int(record.resident_day)>0 else ("Resident requirement: 5% grass" if entry[1]=="Hedgehog" else "Not yet resident")
	section.text=category.to_upper()+"   /   OBSERVATIONS FROM THE VALLEY"
	folio.text="%02d   /   %02d" % [page+1,entries.size()]
	if is_instance_valid(preview): preview.free()
	preview=Node3D.new()
	turntable.add_child(preview)
	var model: Node3D
	if str(entry[3]).begins_with("res://"):
		model=load(entry[3]).instantiate()
	else:
		var actor: Node3D=garden.wildlife.actor_for(str(entry[1]).to_lower()) if category=="Animals" else garden.get_node_or_null(entry[3])
		if not is_instance_valid(actor):return
		model=actor.visual.duplicate(0)
		model.rotation=Vector3.ZERO
	preview.add_child(model)
	for animation in model.find_children("*","AnimationPlayer",true,false): animation.stop(true)
	var bounds: AABB=preload("res://floating_tool.gd").bounds(model)
	var factor:=2.15/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	preview.scale=Vector3.ONE*factor
	preview.position=-bounds.get_center()*factor
	turntable.rotation.y=-0.25

func _process(delta: float) -> void:
	if visible and category!="Land area": turntable.rotation.y+=delta*0.22

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide") or event is InputEventKey and event.pressed and event.keycode in [KEY_F,KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
	elif opening.active:
		if event is InputEventJoypadButton or event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		_category(CATEGORIES[posmod(CATEGORIES.find(category)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),CATEGORIES.size())])
		get_viewport().set_input_as_handled()
	elif category=="Land area" and _land_navigation(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_DOWN]:
		_turn(-1 if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_UP] else 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]:
		_turn(-1 if event.keycode in [KEY_LEFT,KEY_UP] else 1)
		get_viewport().set_input_as_handled()

func _land_navigation(event: InputEvent) -> bool:
	var direction:=Vector2i.ZERO
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:direction=Vector2i.LEFT
			KEY_RIGHT:direction=Vector2i.RIGHT
			KEY_UP:direction=Vector2i.UP
			KEY_DOWN:direction=Vector2i.DOWN
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT:direction=Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT:direction=Vector2i.RIGHT
			JOY_BUTTON_DPAD_UP:direction=Vector2i.UP
			JOY_BUTTON_DPAD_DOWN:direction=Vector2i.DOWN
	if direction==Vector2i.ZERO:return false
	land_page.move_selection(direction)
	return true

```

## first_person.gd

```gd
extends Node3D

const HOVER_HEIGHT := 0.10
const SPEED := 0.48
const SENSITIVITY := 0.0022
var view: Camera3D
var garden: Node3D
var cell := Vector2i(2, 5)
var target_cell := Vector2i(2, 5)
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var travel := 1.0
var travel_duration := 1.0
var elapsed := 0.0
var yaw_target := 0.0
var pitch := deg_to_rad(-12.0)
var pitch_target := deg_to_rad(-12.0)

func setup(camera: Camera3D, owner_garden: Node3D) -> void:
	garden = owner_garden
	cell = cell.clamp(Vector2i.ZERO, garden.grid_size - Vector2i.ONE)
	target_cell = cell
	position = garden.cell_center(cell)
	position.y = garden.heightfield.height_at(Vector2(position.x, position.z)) + HOVER_HEIGHT
	view = camera
	view.reparent(self, false)
	view.position = Vector3.ZERO
	view.rotation = Vector3(pitch, 0.0, 0.0)
	view.projection = Camera3D.PROJECTION_PERSPECTIVE
	view.fov = 80.0
	view.near = 0.012
	view.far = 120.0

func look(relative: Vector2) -> void:
	yaw_target -= relative.x * SENSITIVITY
	pitch_target = clampf(pitch_target - relative.y * SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(80.0))

func advance(delta: float, direction: Vector2) -> void:
	rotation.y = lerp_angle(rotation.y, yaw_target, 1.0 - exp(-12.0 * delta))
	pitch = lerpf(pitch, pitch_target, 1.0 - exp(-12.0 * delta))
	view.rotation.x = pitch
	elapsed += delta
	if is_settled() and direction.length() > 0.1:
		var world := basis * Vector3(direction.x, 0.0, direction.y).normalized()
		var step := Vector2i.ZERO
		if absf(world.x) > 0.4:
			step.x = 1 if world.x > 0.0 else -1
		if absf(world.z) > 0.4:
			step.y = 1 if world.z > 0.0 else -1
		begin_step(cell + step)
	if not is_settled():
		travel = minf(1.0, travel + delta / travel_duration)
		# Quintic easing: zero speed and acceleration at both cell centers.
		var t := travel * travel * travel * (travel * (travel * 6.0 - 15.0) + 10.0)
		position.x = lerpf(start_position.x, end_position.x, t)
		position.z = lerpf(start_position.z, end_position.z, t)
		if travel >= 1.0:
			cell = target_cell
	var surface: float = garden.heightfield.height_at(Vector2(position.x, position.z))
	position.y = surface + HOVER_HEIGHT + sin(elapsed * 1.5) * 0.006

func begin_step(next: Vector2i) -> void:
	if not is_settled() or not garden.contains_cell(next) or next == cell:
		return
	var offset := next - cell
	if absi(offset.x) > 1 or absi(offset.y) > 1:
		return
	start_position = position
	end_position = garden.cell_center(next)
	travel_duration = Vector2(end_position.x - position.x, end_position.z - position.z).length() / SPEED
	target_cell = next
	travel = 0.0

func is_settled() -> bool:
	return travel >= 1.0

```

## floating_tool.gd

```gd
extends Node3D
signal effect_applied(cell: Vector2i, tool: int, mode: int)
const KEYS := ["hoe","seeds","water","shovel"]
const MODES := ["Dig","Pick","Pour","Thump"]
const SOUNDS := ["Hoe","Grass Seeds","Watering Can"]
const SHOVEL_SOUNDS := ["Shovel_Dig","Shovel_Pick","Shovel_Fill","Shovel_Thump"]
var garden: Node3D
var pivot: Node3D
var models: Array[Node3D]=[]
var particles: CPUParticles3D
var audio: AudioStreamPlayer3D
var selected := 0
var shovel_mode := 0
var stroke_mode := 0
var stroke_duration := 1.0
var busy := false
var elapsed := 0.0
var idle_time := 0.0
var applied := false
var tracks_spirit := true
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
 var wrapper:=Node3D.new()
 var path: String="res://assets/tools/shovel/Shovel.fbx" if index==3 else "res://assets/tools/%s.glb"%KEYS[index]
 var model: Node3D=load(path).instantiate()
 var box:=bounds(model)
 var size: float=[0.82,0.43,0.58,0.95][index]
 var factor:=size/maxf(box.size.x,maxf(box.size.y,box.size.z))
 model.scale*=factor
 model.position-=box.get_center()*factor
 wrapper.add_child(model)
 for animation in model.find_children("*","AnimationPlayer",true,false):animation.stop();animation.active=false
 if index==2:wrapper.rotation.y=PI/4.0
 return wrapper

func setup(world: Node3D) -> void:
 garden=world
 pivot=Node3D.new()
 add_child(pivot)
 for i in 4:
  var model:=make_model(i)
  pivot.add_child(model)
  models.append(model)
 particles=CPUParticles3D.new()
 particles.top_level=true
 particles.local_coords=false
 particles.amount=55
 particles.lifetime=0.55
 particles.gravity=Vector3(0,-3,0)
 particles.scale_amount_min=0.6
 particles.scale_amount_max=1.0
 var drop:=SphereMesh.new()
 drop.radius=0.016
 drop.height=0.032
 drop.radial_segments=6
 drop.rings=3
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo=true
 drop.material=material
 particles.mesh=drop
 particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 particles.emitting=false
 add_child(particles)
 audio=AudioStreamPlayer3D.new()
 audio.volume_db=-10.0
 audio.unit_size=3.0
 audio.max_distance=20.0
 add_child(audio)
 equip(0)

func cancel_use() -> void:
 busy=false
 applied=false
 particles.emitting=false
 audio.stop()
 pivot.rotation=Vector3.ZERO
 pivot.position=Vector3.ZERO

func equip(index: int) -> void:
 cancel_use()
 selected=clampi(index,0,4)
 for i in models.size():models[i].visible=i==selected

func use_at(cell: Vector2i) -> bool:
 if busy or selected==4:return false
 target_cell=cell
 tracks_spirit=cell==garden.player.cell
 target_point=garden.player.position if tracks_spirit else garden.cell_center(cell)
 stroke_mode=shovel_mode
 var sound: String=SHOVEL_SOUNDS[stroke_mode] if selected==3 else SOUNDS[selected]
 audio.stream=load("res://assets/sounds/tools/"+sound+".mp3")
 stroke_duration=audio.stream.get_length()
 audio.play()
 particles.color=Color("97724c") if selected==3 else (Color("84e45a") if selected==1 else Color("58bbed"))
 var digging: bool=selected==3 and stroke_mode in [0,1]
 particles.direction=Vector3.UP if digging else Vector3.DOWN
 particles.spread=38.0 if digging else 13.0
 particles.initial_velocity_min=0.8 if digging else 0.3
 particles.initial_velocity_max=1.8 if digging else 0.7
 busy=true
 elapsed=0.0
 applied=false
 return true

func _process(delta: float) -> void:
 if not is_instance_valid(garden):return
 var paused: bool=garden.guide.visible or garden.tool_wheel.visible or (is_instance_valid(garden.dev_console) and garden.dev_console.opened)
 particles.speed_scale=0.0 if paused else 1.0
 audio.stream_paused=paused
 visible=not paused
 if paused:return
 idle_time+=delta
 if busy and tracks_spirit:
  target_cell=garden.player.cell
  target_point=garden.player.position
 var anchor: Vector3=target_point+Vector3.UP*0.1 if busy else garden.cursor.position
 position=anchor+Vector3.UP*(0.55+sin(idle_time*2)*0.022)
 rotation.y=garden.camera_yaw
 pivot.position=Vector3.ZERO
 pivot.rotation=Vector3.ZERO
 if not busy:return
 elapsed+=delta
 var t:=clampf(elapsed/stroke_duration,0,1)
 var tilt:=smoothstep(0,0.25,t)*(1.0-smoothstep(0.78,1.0,t))
 var impact:=0.44
 var emitting:=false
 if selected==0:
  pivot.position.y=-0.36*pow(sin(t*PI),4)
  pivot.rotation.z=-0.18+sin(t*TAU)*0.14
 elif selected==1:
  pivot.rotation.z=PI*tilt
  pivot.position.y=absf(sin(t*TAU*3))*0.055*tilt
  outlet=Vector3(0,0.20,0)
  emitting=t>0.28 and t<0.8
 elif selected==2:
  pivot.rotation.z=-1.9*tilt
  outlet=Basis(Vector3.UP,PI/4.0)*Vector3(0.2553,0.0726,0.2359)
  emitting=t>0.28 and t<0.8
 else:
  outlet=Vector3(0,-0.40,0)
  match stroke_mode:
   0:
    pivot.position.y=-0.32*pow(sin(t*PI),2)+0.1*sin(t*TAU)
    pivot.rotation.x=lerpf(-0.4,0.65,smoothstep(0.3,0.7,t))*tilt
    emitting=t>0.44 and t<0.73
   1:
    pivot.position.y=-0.18*pow(sin(t*PI),8)
    pivot.rotation.z=0.12*sin(t*TAU)*tilt
    emitting=t>0.44 and t<0.56
   2:
    pivot.rotation.z=2.4*tilt
    pivot.position.y=0.10*tilt
    emitting=t>0.3 and t<0.75
   3:
    pivot.rotation.x=-PI/2.0*tilt
    pivot.position.y=-0.42*pow(sin(t*PI),6)
 particles.global_position=pivot.to_global(outlet)
 particles.emitting=emitting
 if not applied and t>=impact:
  applied=true
  effect_applied.emit(target_cell,selected,stroke_mode)
 if t>=1.0:
  busy=false
  particles.emitting=false
  pivot.rotation=Vector3.ZERO

```

## garden.gd

```gd
extends "res://main.gd"

enum Tool { HOE, SEEDS, WATER, SHOVEL, NONE }
const TOOL_NAMES := ["Hoe", "Seed packet", "Watering can", "Shovel", "No tool equipped"]
const GROW_SECONDS := 12.0
const HARVEST_GOAL := 6
const REACH := 100.0
const DioramaCamera = preload("res://diorama_camera.gd")
const GlidingCursor = preload("res://gliding_cursor.gd")
const ThirdPersonPlayer = preload("res://third_person_player.gd")
const HeightTerrain = preload("res://height_terrain.gd")
const PomMaterial = preload("res://pom_material.gd")
const WelshSky = preload("res://welsh_sky.gd")
const WanderingNPC = preload("res://animated_visitor.gd")
const ChickenNPC = preload("res://chicken_npc.gd")
const SelectionTarget = preload("res://selection_target.gd")
const ValleyAmbience = preload("res://valley_ambience.gd")
const ValleyCycle = preload("res://valley_cycle.gd")
const BackgroundMeadow = preload("res://background_meadow.gd")
const ValleyLandscape = preload("res://valley_landscape.gd")
var valley_landscape: Node3D
const CyclingNPC = preload("res://cycling_npc.gd")
const ProceduralAnimal = preload("res://procedural_animal.gd")
const HedgehogNPC = preload("res://hedgehog_npc.gd")
var blocked_cells: Dictionary = {}
var compass_view: Control
var dev_console: CanvasLayer
var tardis: Node3D
var animal_notices: CanvasLayer
var wildlife: Node
var hedgehog_intro: Node3D
var additional_visitors: Array[Node3D] = []
var background_meadow: Node3D
var valley_cycle: Node3D

var visitor: Node3D
var chicken: Node3D
var selected_target: Area3D
var camera_pitch := PI / 4.0
var aiming := false
var aim_dot: Label

var tool: int = Tool.HOE
var tool_wheel: Control
var floating_tool: Node3D
var watered_cells: Dictionary = {}
var watered_image: Image
var watered_texture: ImageTexture
var toast_timer := 0.0
var last_message := ""
var crops: Dictionary = {}
var harvested := 0
var action_pending := false
var trigger_held := false
var mouse_held := false
var release_required := false
var repeat_wait := 0.0
var action_mouse := Vector2.ZERO
var pending_bounds := Rect2i()
var pending_tool := 0
var chunk_selection := false
var selection_button: Button
var player: Node3D
var camera_yaw := 0.0
var heightfield: Node3D
var ambience: Node
var ambience_button: Button
var ambience_muted := false
var message := "Welcome to your valley. Prepare a little ground."
var hud: Label
var hint: Label
var notice: Label
var field_book: Control
var guide: PanelContainer
var control_hint: Label
var guide_controls: Label
var tool_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	status.hide()
	_create_garden_ui()
	ControllerInput.mode_changed.connect(_controller_prompts)
	ControllerInput.disconnected.connect(func(): _set_guide(true))
	_controller_prompts()
	_set_guide(true)
	watered_image = Image.create(grid_size.x,grid_size.y,false,Image.FORMAT_R8)
	watered_image.fill(Color.BLACK)
	watered_texture = ImageTexture.create_from_image(watered_image)
	terrain_material.set_shader_parameter("watered_tiles",watered_texture)
	heightfield.water_material.set_shader_parameter("watered_tiles",watered_texture)
	floating_tool = preload("res://floating_tool.gd").new()
	add_child(floating_tool)
	floating_tool.setup(self)
	floating_tool.effect_applied.connect(_apply_tool)
	ambience = ValleyAmbience.new()
	add_child(ambience)
	visitor = WanderingNPC.new()
	visitor.name = "WanderingVisitor"
	add_child(visitor)
	visitor.setup(self)
	SelectionTarget.attach(visitor, "Valley visitor", Vector3(0.65, 1.5, 0.65))
	valley_cycle = ValleyCycle.new()
	valley_cycle.name = "DayNightWeather"
	add_child(valley_cycle)
	valley_cycle.setup(self)
	background_meadow = BackgroundMeadow.new()
	add_child(background_meadow)
	background_meadow.build(self)
	valley_landscape = ValleyLandscape.new()
	add_child(valley_landscape)
	valley_landscape.build(self)
	for entry in [["Arthur", "npcs/arthur", 0.999512, Vector2i(2, 3)], ["Meera", "npcs/meera", 0.999512, Vector2i(5, 5)]]:
		var npc := CyclingNPC.new()
		npc.name = entry[0]
		npc.display_name = entry[0]
		npc.model_scene = load("res://assets/%s.glb" % entry[1])
		npc.model_height = entry[2]
		npc.cell = entry[3]
		add_child(npc)
		npc.setup(self)
		SelectionTarget.attach(npc, entry[0], Vector3(0.65, 1.5, 0.65))
		additional_visitors.append(npc)
	var angus := preload("res://angus_npc.gd").new()
	angus.name="Angus"
	angus.cell=Vector2i(7,2)
	add_child(angus)
	angus.setup(self)
	SelectionTarget.attach(angus,"Angus McDoogal",Vector3(0.8,1.5,0.8))
	additional_visitors.append(angus)
	wildlife=preload("res://garden_wildlife.gd").new()
	add_child(wildlife)
	wildlife.setup(self)
	animal_notices=preload("res://animal_notices.gd").new()
	add_child(animal_notices)
	animal_notices.setup(self)
	var meadow_grass := preload("res://meadow_grass.gd").new()
	add_child(meadow_grass)
	meadow_grass.build(self)
	var model_weather := preload("res://model_weather.gd").new()
	add_child(model_weather)
	model_weather.setup(self)
	tardis=preload("res://tardis_event.gd").new()
	add_child(tardis)
	tardis.setup(self)
	var compass_layer:=CanvasLayer.new()
	add_child(compass_layer)
	var compass:=preload("res://garden_compass.gd").new()
	compass_layer.add_child(compass)
	compass.setup(camera)
	compass_view=compass
	compass_view.visible=not guide.visible
	dev_console=preload("res://developer_console.gd").new()
	add_child(dev_console)
	dev_console.setup(self)
	hedgehog_intro=preload("res://hedgehog_intro.gd").new()
	add_child(hedgehog_intro)
	hedgehog_intro.setup(self)
	_refresh_ui()

func _create_chunks() -> void:
	heightfield = HeightTerrain.new()
	add_child(heightfield)
	heightfield.build(self)

func cell_center(cell: Vector2i) -> Vector3:
	var point := super.cell_center(cell)
	if is_instance_valid(heightfield) and heightfield.heights != null:
		point.y = heightfield.height_at(Vector2(point.x, point.z))
	return point

func _create_cursor() -> void:
	cursor = GlidingCursor.new()
	cursor.name = "GlidingCursor"
	add_child(cursor)
	cursor.surface_height = func(point: Vector2) -> float: return heightfield.surface_at(point)

func _toggle_ambience() -> void:
	ambience_muted = not ambience_muted
	ambience.muted = ambience_muted
	ambience_button.text = "Ambience: off [M]" if ambience_muted else "Ambience: on [M]"

func _create_view() -> void:
	super._create_view()
	var world: WorldEnvironment
	var sun: DirectionalLight3D
	for child in get_children():
		if child is WorldEnvironment:
			world = child
		elif child is DirectionalLight3D:
			sun = child
	WelshSky.apply(world, sun)
	player = ThirdPersonPlayer.new()
	player.name = "SpiritController"
	add_child(player)
	player.setup(self)
	DioramaCamera.configure(camera, player.position)
	terrain_material.set_shader_parameter("orthographic_view", false)

func _create_terrain() -> void:
	super._create_terrain()
	terrain_image.fill(Color(float(Terrain.HARD_DIRT)/255.0,0,0))
	terrain_texture.update(terrain_image)
	terrain_material.set_shader_parameter("color_maps", load("res://assets/textures/terrain_colors.res"))
	terrain_material.set_shader_parameter("normal_maps", load("res://assets/textures/terrain_normals.res"))
	terrain_material.set_shader_parameter("detail_maps", load("res://assets/textures/terrain_details.res"))
	terrain_material.set_shader_parameter("riverbed_color", load("res://assets/textures/water/M_RiverBottom_BaseColor.tga"))

func _clear_use() -> void:
	action_pending=false
	mouse_held=false
	trigger_held=false
	release_required=true
	if is_instance_valid(floating_tool):floating_tool.cancel_use()

func _trigger_tardis() -> void:
	if tardis.state=="away":message=tardis.land()
	elif tardis.state=="landed":message=tardis.takeoff()
	else:message="The TARDIS is already "+tardis.state+"."
	_refresh_ui()

func _cycle_shovel(direction: int) -> void:
	floating_tool.shovel_mode=posmod(floating_tool.shovel_mode+direction,4)
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(hedgehog_intro) and hedgehog_intro.active:return
	if is_instance_valid(dev_console) and dev_console.opened:return
	if field_book.visible:return
	var modal: bool=guide.visible
	if event.is_action_pressed("pad_guide"):
		_toggle_guide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_B:
			if modal:_set_guide(false)
			else:_select_tool(Tool.NONE)
			get_viewport().set_input_as_handled()
			return
		if not modal:
			var tools_by_direction: Dictionary={JOY_BUTTON_DPAD_UP:Tool.HOE,JOY_BUTTON_DPAD_RIGHT:Tool.SEEDS,JOY_BUTTON_DPAD_DOWN:Tool.WATER,JOY_BUTTON_DPAD_LEFT:Tool.SHOVEL}
			if tools_by_direction.has(event.button_index):
				_select_tool(tools_by_direction[event.button_index])
				get_viewport().set_input_as_handled()
				return
			if event.button_index==JOY_BUTTON_X:
				if tool==Tool.SHOVEL:_cycle_shovel(1)
				get_viewport().set_input_as_handled()
				return
	if event.is_action("pad_use"):
		if event.is_action_released("pad_use"):
			trigger_held=false
			if floating_tool.busy:action_pending=false
		elif event.is_action_pressed("pad_use") and not modal and not release_required:
			if not trigger_held:action_pending=true
			trigger_held=true
		get_viewport().set_input_as_handled()
		return
	var tardis_key: bool=event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_T and event.ctrl_pressed
	if not modal and (event.is_action_pressed("pad_tardis") or tardis_key):
		_trigger_tardis()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F,KEY_ESCAPE]:
			_toggle_guide()
			return
		if event.keycode==KEY_M:
			_toggle_ambience()
			return
		if modal:return
		if event.keycode>=KEY_1 and event.keycode<=KEY_4:
			_select_tool(event.keycode-KEY_1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_T and not event.ctrl_pressed:
			_select_tool(Tool.NONE)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_X:
			if tool==Tool.SHOVEL:_cycle_shovel(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			mouse_held=false
			if floating_tool.busy:action_pending=false
		elif not modal and not release_required:
			mouse_held=true
			action_pending=true
	if modal:return
	if event is InputEventMouseMotion and aiming:
		camera_yaw-=event.relative.x*0.004
		camera_pitch=clampf(camera_pitch+event.relative.y*0.004,deg_to_rad(-80),deg_to_rad(80))

func _set_wheel(_open: bool) -> void:
	# Retained as a close hook for other modal interfaces; selection is direct now.
	tool_wheel.hide()
	_clear_use()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(guide):
		_set_guide(true)

func _physics_process(delta: float) -> void:
	if is_instance_valid(hedgehog_intro) and hedgehog_intro.active:return
	if release_required and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_action_pressed("pad_use"):release_required=false
	repeat_wait=maxf(0.0,repeat_wait-delta)
	if is_instance_valid(dev_console) and dev_console.opened:
		action_pending=false
		return
	if not is_instance_valid(guide) or guide.visible:
		cursor.clear()
		action_pending = false
		return
	if tool_wheel.visible: return
	terrain_material.set_shader_parameter("world_to_grid",global_transform.affine_inverse())
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	input = (input+ControllerInput.movement()).limit_length()
	var look := ControllerInput.look()
	camera_yaw -= look.x*1.8*delta
	camera_pitch = clampf(camera_pitch+look.y*1.5*delta,deg_to_rad(-80),deg_to_rad(80))
	player.advance(delta,input,camera_yaw)
	DioramaCamera.follow(camera,player.position,camera_yaw,camera_pitch)
	var target: Vector2i = player.cell
	selected_target = null if floating_tool.busy else _pick_object(get_viewport().get_visible_rect().size*0.5)
	if floating_tool.busy:
		cursor.follow_object(floating_tool.target_point,Vector2.ONE*MICRO_SIZE,delta)
	elif is_instance_valid(selected_target):
		cursor.follow_object(to_local(selected_target.subject.global_position),selected_target.selection_size(),delta)
	else:
		cursor.follow_feet(player.position,Vector2.ONE*MICRO_SIZE,delta)
	if (mouse_held or trigger_held) and not release_required and not floating_tool.busy and repeat_wait<=0.0:action_pending=true
	if action_pending and not floating_tool.busy:
		action_pending=false
		repeat_wait=0.2
		if is_instance_valid(selected_target) and not contains_cell(selected_target.crop_cell):
			message = selected_target.subject.get_meta("inspection_text",selected_target.label+" is enjoying the valley.")
		elif contains_cell(target):
			if is_instance_valid(selected_target): target=selected_target.crop_cell
			if blocked_cells.has(target): message="This ground is occupied."
			elif tool==Tool.NONE: message="Choose a tool from the wheel to tend the ground."
			else: floating_tool.use_at(target)
		else:
			message="Let the spirit settle, then tend this square."
	hovered_cell=target
	if not watered_cells.is_empty():
		for cell in watered_cells.keys():
			watered_cells[cell]=maxf(0.0,float(watered_cells[cell])-delta/70.0)
			watered_image.set_pixel(cell.x,cell.y,Color(watered_cells[cell],0,0))
			if watered_cells[cell]<=0: watered_cells.erase(cell)
		watered_texture.update(watered_image)
	toast_timer=maxf(0,toast_timer-delta)
	_refresh_ui()

func _pick_cell(mouse: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(mouse) * REACH, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INVALID_CELL
	var point := to_local(hit["position"])
	return local_to_cell(point)

func _pick_object(mouse: Vector2) -> Area3D:
	if not aiming and get_viewport().gui_get_hovered_control() != null:
		return null
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + camera.project_ray_normal(mouse) * REACH, FLOOR_MASK | 2)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is SelectionTarget:
		return hit.collider
	return null

func _act(cell: Vector2i) -> void:
	_apply_tool(cell,tool)

func _apply_tool(cell: Vector2i, active_tool: int, mode: int=-1) -> void:
	if not contains_cell(cell) or blocked_cells.has(cell): return
	var terrain := get_terrain(cell)
	match active_tool:
		Tool.HOE:
			if terrain in [Terrain.GRASS,Terrain.LONG_GRASS,Terrain.HARD_DIRT]:
				_clear_old_crop(cell)
				set_terrain(cell,Terrain.DIRT)
				message="Fresh earth, ready for a little green."
			else: message="Use the hoe on grass or hard earth."
		Tool.SEEDS:
			if terrain==Terrain.DIRT:
				_clear_old_crop(cell)
				heightfield.plant_seed(cell)
				set_terrain(cell,Terrain.GRASS)
				message="A fresh patch of grass."
			else: message="Scatter grass seed onto bare earth."
		Tool.SHOVEL:
			var chosen: int=floating_tool.shovel_mode if mode<0 else mode
			if heightfield.sculpt(cell,chosen):
				message=["A hollow fills with water.","A small hole, ready for grass seed.","The hollow is filled with dirt.","The ground settles level."][chosen]
			else:message="Leave a little room around people, plants and buildings."
		Tool.WATER:
			watered_cells[cell]=1.0
			watered_image.set_pixel(cell.x,cell.y,Color(1,0,0))
			watered_texture.update(watered_image)
			message="A gentle drink for the ground."
	_refresh_ui()

func _clear_old_crop(cell: Vector2i) -> void:
	if crops.has(cell):
		crops[cell].node.queue_free()
		crops.erase(cell)

func _mesh_part(parent: Node3D, mesh: Mesh, color: Color, position: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	part.material_override = material
	parent.add_child(part)
	return part

func _make_plant(cell: Vector2i) -> Node3D:
	var plant := Node3D.new()
	add_child(plant)
	plant.position = cell_center(cell)
	var bulb := SphereMesh.new()
	bulb.radius = 0.14
	bulb.height = 0.22
	bulb.radial_segments = 8
	bulb.rings = 4
	_mesh_part(plant, bulb, Color("e6d3ba"), Vector3(0.0, 0.08, 0.0))
	var crown := SphereMesh.new()
	crown.radius = 0.115
	crown.height = 0.10
	crown.radial_segments = 8
	crown.rings = 4
	_mesh_part(plant, crown, Color("a87397"), Vector3(0.0, 0.16, 0.0))
	for i in range(5):
		var leaf := PrismMesh.new()
		leaf.size = Vector3(0.085, 0.27, 0.035)
		var angle := float(i) * TAU / 5.0
		var part := _mesh_part(plant, leaf, Color("60894b"),
			Vector3(sin(angle) * 0.06, 0.28, cos(angle) * 0.06))
		part.rotation = Vector3(0.4, angle, 0.3)
	plant.scale = Vector3.ONE * 0.25
	SelectionTarget.attach(plant, "Turnip", Vector3(0.42, 0.48, 0.42), cell)
	return plant

func _add_water_ring(plant: Node3D) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.21
	ring.rings = 20
	ring.ring_segments = 6
	_mesh_part(plant, ring, Color("80bdc4"), Vector3(0.0, 0.025, 0.0))

func _panel_style(_color: Color) -> StyleBoxFlat:
	return preload("res://cwtch_theme.gd").panel()

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_garden_ui() -> void:
	get_tree().root.theme = preload("res://cwtch_theme.gd").make()
	var layer := CanvasLayer.new()
	layer.name="GardenInterface"
	add_child(layer)
	var root := Control.new()
	root.theme=preload("res://cwtch_theme.gd").make()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	aim_dot=_label("·",24,Color("ead29c"))
	root.add_child(aim_dot)
	aim_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim_dot.offset_left=-8
	aim_dot.offset_right=8
	aim_dot.offset_top=-16
	aim_dot.offset_bottom=16
	aim_dot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var top := PanelContainer.new()
	root.add_child(top)
	top.position=Vector2(28,24)
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",5)
	top.add_child(stack)
	stack.add_child(_label("C W T C H",20,Color("e5c17c")))
	hud=_label("",14,Color("d9e3d5"))
	stack.add_child(hud)
	control_hint=_label("",12,Color("9cb7a8"))
	stack.add_child(control_hint)
	notice=_label("",16,Color("f3ead4"))
	root.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left=-280
	notice.offset_right=280
	notice.offset_top=94
	notice.offset_bottom=134
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_shadow_color",Color("132b26"))
	notice.add_theme_constant_override("shadow_offset_y",2)
	guide=PanelContainer.new()
	root.add_child(guide)
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	guide.offset_left=-250
	guide.offset_right=250
	guide.offset_top=-310
	guide.offset_bottom=310
	var pages := VBoxContainer.new()
	pages.add_theme_constant_override("separation",6)
	guide.add_child(pages)
	pages.add_child(_label("A MOMENT OF REST",24,Color("e5c17c")))
	pages.add_child(_label("A little care goes a long way.",16,Color("b2c6bb")))
	guide_controls=_label("",16,Color("eee5d1"))
	pages.add_child(guide_controls)
	field_book=preload("res://field_book.gd").new()
	root.add_child(field_book)
	field_book.closed.connect(func():
		guide.modulate.a=1.0
		pages.show()
		ControllerInput.focus_first.call_deferred(guide))
	var book_button:=Button.new()
	book_button.text="Open the Field Guide"
	book_button.pressed.connect(func():
		guide.modulate.a=0.0
		pages.hide()
		field_book.open(self))
	pages.add_child(book_button)
	ambience_button=Button.new()
	ambience_button.text="Ambient sounds  ·  on [M]"
	ambience_button.pressed.connect(_toggle_ambience)
	pages.add_child(ambience_button)
	var close := Button.new()
	close.text="Return to the garden"
	close.pressed.connect(_toggle_guide)
	pages.add_child(close)
	if is_instance_valid(get_tree().current_scene) and get_tree().current_scene!=self and get_tree().current_scene.has_method("open_menu"):
		var village_button:=Button.new()
		village_button.text="Visit the village"
		village_button.pressed.connect(get_tree().current_scene.open_village)
		pages.add_child(village_button)
		var back := Button.new()
		back.text="Save & return to main menu"
		back.pressed.connect(get_tree().current_scene.open_menu)
		pages.add_child(back)
		var quit_button:=Button.new()
		quit_button.text="Save & Quit"
		quit_button.pressed.connect(get_tree().current_scene.save_and_quit)
		pages.add_child(quit_button)
	tool_wheel=Control.new()
	root.add_child(tool_wheel)
	tool_wheel.hide()
	tool_wheel.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _toggle_guide() -> void:
	_set_guide(not guide.visible)

func _set_guide(open: bool) -> void:
	if is_instance_valid(hedgehog_intro) and hedgehog_intro.active:
		hedgehog_intro.set_paused(open)
		return
	_clear_use()
	if is_instance_valid(dev_console) and dev_console.opened: dev_console.toggle(false)
	if is_instance_valid(field_book) and field_book.visible: field_book.close()
	guide.visible=open
	notice.visible=not open
	if is_instance_valid(compass_view):compass_view.visible=not open
	if open: ControllerInput.focus_first.call_deferred(guide)
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused: focused.release_focus()
	if is_instance_valid(tool_wheel): tool_wheel.hide()
	cursor.clear()
	action_pending=false
	pending_bounds=Rect2i()
	aiming=not open
	if is_instance_valid(aim_dot): aim_dot.visible=not open
	selected_target=null
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _select_tool(index: int) -> void:
	_clear_use()
	tool=clampi(index,0,4)
	action_pending=false
	if is_instance_valid(floating_tool): floating_tool.equip(tool)
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(hud): return
	control_hint.text=_tool_controls()
	hud.text=TOOL_NAMES[tool]
	if tool==Tool.SHOVEL and is_instance_valid(floating_tool):hud.text+=" · "+floating_tool.MODES[floating_tool.shovel_mode]
	if message!=last_message:
		last_message=message
		toast_timer=3.2
	notice.text=message
	notice.modulate.a=smoothstep(0,0.5,toast_timer)

func _controller_prompts() -> void:
	var pad := ControllerInput.using_pad
	control_hint.text = _tool_controls()
	guide_controls.text = ("Left stick  glide  /  Right stick  look\n\nD-pad: Up Hoe / Right Seeds\nDown Watering can / Left Shovel\nX / Square  change mode\nB / Circle  put tool away\nHold RT  use / Start  pause\nR3  TARDIS" if pad else "WASD  glide  /  Mouse  look\n\n1 Hoe / 2 Seeds / 3 Watering can / 4 Shovel\nX  change mode / T  put tool away\nHold left-click  use / Esc  pause\nCtrl+T  TARDIS") + "\n\nYour garden saves when you leave."
	if field_book.visible: ControllerInput.focus_first.call_deferred(field_book)
	elif guide.visible: ControllerInput.focus_first.call_deferred(guide)

func _tool_controls() -> String:
	var text: String="D-pad  tools / B  put away / Hold RT  use" if ControllerInput.using_pad else "1-4  tools / T  put away / Hold click  use"
	if tool==Tool.SHOVEL:text+="\nX / Square  change mode" if ControllerInput.using_pad else "\nX  change mode"
	return text

```

## garden_compass.gd

```gd
extends Control
## World north is -Z. Heading follows the camera, independently of movement.
var camera: Camera3D
var heading := 0.0
const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

func setup(view: Camera3D) -> void:
 camera=view
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 offset_left=-150
 offset_right=150
 offset_top=22
 offset_bottom=82

func bearing() -> float:
 var forward: Vector3=-camera.global_basis.z
 return fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)

func _process(_delta: float) -> void:
 if is_instance_valid(camera):
  heading=bearing()
  queue_redraw()

func _draw() -> void:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color(0.10,0.17,0.15,0.88)
 style.set_corner_radius_all(12)
 draw_style_box(style,Rect2(Vector2.ZERO,size))
 var font:=ThemeDB.fallback_font
 var gold:=Color("ebce8b")
 for i in range(-8,9):
  var degree: float=floor(heading/15.0)*15.0+i*15.0
  var x:=size.x*0.5+(degree-heading)*2.0
  if x<15 or x>size.x-15:continue
  draw_line(Vector2(x,34),Vector2(x,39),Color("91a99b"),1)
  if posmod(int(degree),45)==0:
   var label: String=DIRECTIONS[posmod(int(degree)/45,8)]
   draw_string(font,Vector2(x-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x/2,26),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,gold)
 draw_colored_polygon(PackedVector2Array([Vector2(146,3),Vector2(154,3),Vector2(150,9)]),gold)
 var text: String="%03d°"%posmod(roundi(heading),360)
 draw_string(font,Vector2(150-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,54),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,gold)

```

## garden_cottage.gd

```gd
extends Node3D
const COTTAGE = preload("res://assets/cottage.glb")
const SelectionTarget = preload("res://selection_target.gd")
var footprint := Vector3(6.0,4.3308,5.6)
func build(garden: Node3D) -> void:
 name = "Cottage"
 position = Vector3(-6,0,-5)
 var model := COTTAGE.instantiate()
 model.scale = Vector3.ONE*(6.0/0.982788)
 add_child(model)
 set_meta("inspection_text","A quiet cottage beside the garden.")
 SelectionTarget.attach(self,"Cottage",footprint)
 var body := StaticBody3D.new()
 body.collision_layer=4
 body.collision_mask=0
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size=footprint
 collider.shape=shape
 collider.position.y=footprint.y*0.5
 body.add_child(collider)
 add_child(body)
 # Reserve every intersecting microtile, including a small clearance margin.
 for z in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   var cell := Vector2i(x,z)
   var point: Vector3 = garden.cell_center(cell)
   if absf(point.x-position.x)<footprint.x*0.5+garden.MICRO_SIZE*0.5 and absf(point.z-position.z)<footprint.z*0.5+garden.MICRO_SIZE*0.5:
    garden.blocked_cells[cell]=true

```

## garden_wall.gd

```gd
extends Node3D
## A continuous physical perimeter, with staggered dry-stone courses.
const HEIGHT := 0.72
const THICKNESS := 0.28

func build(garden: Node3D) -> void:
	name = "GardenStoneWall"
	var width: float = garden.chunk_count.x * garden.CHUNK_SIZE
	var depth: float = garden.chunk_count.y * garden.CHUNK_SIZE
	var material := ShaderMaterial.new()
	material.shader = preload("res://stone_wall.gdshader")
	for entry in [["stone_color", "Color"], ["stone_normal", "NormalGL"], ["stone_roughness", "Roughness"], ["stone_ao", "AmbientOcclusion"]]:
		material.set_shader_parameter(entry[0], load("res://assets/textures/stone/Rock062_1K-JPG_%s.jpg" % entry[1]))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 8
	rock.rings = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891
	for side in range(4):
		var along_x := side < 2
		var length := width + THICKNESS * 2.0 if along_x else depth
		var middle := Vector3(0, 0, (-1.0 if side == 0 else 1.0) * (depth + THICKNESS) * 0.5) if along_x else Vector3((-1.0 if side == 2 else 1.0) * (width + THICKNESS) * 0.5, 0, 0)
		var body := StaticBody3D.new()
		body.name = "Boundary%d" % side
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = middle + Vector3.UP * HEIGHT * 0.5
		add_child(body)
		var box := BoxShape3D.new()
		box.size = Vector3(length, HEIGHT, THICKNESS) if along_x else Vector3(THICKNESS, HEIGHT, length)
		var collision := CollisionShape3D.new()
		collision.shape = box
		body.add_child(collision)
		# Odd courses use half blocks at both ends, so corners stay closed.
		var count := ceili(length / 0.48)
		var step := length / count
		for row in range(3):
			for column in range(count + (row % 2)):
				var start := maxf(0.0, (column - 0.5 * (row % 2)) * step)
				var end := minf(length, (column + 1.0 - 0.5 * (row % 2)) * step)
				var mesh := MeshInstance3D.new()
				mesh.mesh = rock
				mesh.material_override = material
				# Per-stone tone without allocating hundreds of materials.
				var coloured := rock.duplicate() as SphereMesh
				var arrays := coloured.get_mesh_arrays()
				var colors := PackedColorArray()
				colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
				colors.fill(Color(rng.randf_range(0.1, 0.9), 1, 1))
				arrays[Mesh.ARRAY_COLOR] = colors
				var stone := ArrayMesh.new()
				stone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.mesh = stone
				var offset := (start + end) * 0.5 - length * 0.5
				mesh.position = middle + Vector3(0, row * 0.225 + 0.12, 0)
				mesh.position += Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
				mesh.scale = Vector3((end - start) * 1.07, rng.randf_range(0.25, 0.28), THICKNESS * 1.22)
				mesh.rotation.y = (0.0 if along_x else PI / 2.0) + rng.randf_range(-0.07, 0.07)
				add_child(mesh)

```

## garden_wildlife.gd

```gd
extends Node
## First-visit and residency dates use the garden clock and survive save/load.
signal animal_event(kind: String, species: String, event_day: int)
var suppress_events := false
var life_events: Array[Dictionary]=[]
var garden: Node3D
var records: Dictionary={}
var hedgehog: Node3D
var wild_hedgehog_enabled := true
var grass_dirty := true
var cached_ratio := 0.0

func setup(world: Node3D) -> void:
 garden=world
 garden.terrain_changed.connect(func(_cell,_kind):grass_dirty=true)
 hedgehog=preload("res://visiting_hedgehog.gd").new()
 hedgehog.name="Hedgehog"
 garden.add_child(hedgehog)
 hedgehog.setup(garden)
 preload("res://selection_target.gd").attach(hedgehog,"Hedgehog",Vector3(0.35,0.30,0.4))

func grass_ratio() -> float:
 if not grass_dirty:return cached_ratio
 var total: int = garden.grid_size.x*garden.grid_size.y
 var grass:=0
 for y in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   if garden.get_terrain(Vector2i(x,y)) in [garden.Terrain.GRASS,garden.Terrain.LONG_GRASS]:grass+=1
 cached_ratio=float(grass)/float(total)
 grass_dirty=false
 return cached_ratio

func day() -> int:
 return floori((garden.valley_cycle.elapsed+600.0)/garden.valley_cycle.FULL_CYCLE)+1

func record_visit(id: String) -> void:
 if records.has(id):return
 records[id]={"visit_day":day(),"resident_day":0}
 _announce("visit",id)

func record_resident(id: String) -> void:
 record_visit(id)
 if int(records[id].resident_day)>0:return
 records[id].resident_day=day()
 _announce("resident",id)

func _announce(kind: String, species: String) -> void:
 if not suppress_events:animal_event.emit(kind,species,day())

# Called by future breeding/lifespan systems with a stable individual animal ID.
# These report real lifecycle events; they do not spawn or kill animals themselves.
func record_birth(species: String, individual_id: String) -> bool:
 return _record_life_event("birth",species,individual_id)

func record_death(species: String, individual_id: String) -> bool:
 return _record_life_event("death",species,individual_id)

func _record_life_event(kind: String, species: String, individual_id: String) -> bool:
 if individual_id.strip_edges().is_empty() or species.strip_edges().is_empty():return false
 for event in life_events:
  if event.kind==kind and event.individual_id==individual_id:return false
 life_events.append({"kind":kind,"species":species,"individual_id":individual_id,"day":day()})
 _announce(kind,species)
 return true

func purchased(id: String) -> void:
 # Each purchased animal gets notices, while the guide retains first-species dates.
 if records.has(id):_announce("visit",id)
 else:record_visit(id)
 if id!="hedgehog" or grass_ratio()>=0.05:
  if int(records[id].resident_day)>0:_announce("resident",id)
  else:record_resident(id)
 if id=="hedgehog":
  wild_hedgehog_enabled=false
  hedgehog.hide()
  hedgehog.process_mode=Node.PROCESS_MODE_DISABLED
  hedgehog.remove_from_group("garden_npcs")
  for shape in hedgehog.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",true)

func actor_for(id: String) -> Node3D:
 for node in garden.get_children():
  if node is Node3D and node.visible and str(node.get_meta("animal_id",""))==id:return node
 return null

func save_data() -> Dictionary:
 return {"life_events":life_events.duplicate(true),"wild_hedgehog_enabled":wild_hedgehog_enabled,"records":records.duplicate(true),"hedgehog_position":[hedgehog.position.x,hedgehog.position.z],"patrol_corner":hedgehog.patrol_corner}

func restore(data: Dictionary) -> void:
 records.clear()
 life_events.clear()
 var saved_events=data.get("life_events",[])
 if saved_events is Array:
  for event in saved_events:
   if event is Dictionary and event.get("kind","") in ["birth","death"] and event.has_all(["species","individual_id","day"]):
    life_events.append({"kind":str(event.kind),"species":str(event.species),"individual_id":str(event.individual_id),"day":maxi(1,int(event.day))})
 var saved=data.get("records",{})
 if saved is Dictionary:
  for id in ["hedgehog","chicken","badger","dragon","peacock"]:
   var entry=saved.get(id,{})
   if entry is Dictionary and int(entry.get("visit_day",0))>0:
    records[id]={"visit_day":maxi(1,int(entry.visit_day)),"resident_day":maxi(0,int(entry.get("resident_day",0)))}
 hedgehog.patrol_corner=clampi(int(data.get("patrol_corner",1)),0,3)
 wild_hedgehog_enabled=bool(data.get("wild_hedgehog_enabled",true))
 if not wild_hedgehog_enabled:
  hedgehog.hide()
  hedgehog.process_mode=Node.PROCESS_MODE_DISABLED
  return
 if records.has("hedgehog"):
  hedgehog.visit_state="inside"
  hedgehog.add_to_group("garden_npcs")
  var point=data.get("hedgehog_position",[])
  var cell:=Vector2i(0,garden.grid_size.y/2)
  if point is Array and point.size()==2:
   var candidate: Vector2i=garden.local_to_cell(Vector3(float(point[0]),0,float(point[1])))
   if hedgehog._can_reserve(candidate):cell=candidate
  if not hedgehog._can_reserve(cell):
   for y in range(garden.grid_size.y):
    for x in range(garden.grid_size.x):
     if hedgehog._can_reserve(Vector2i(x,y)):cell=Vector2i(x,y);break
  hedgehog.cell=cell
  hedgehog.next_cell=cell
  hedgehog.position=garden.cell_center(cell)
  hedgehog.destination=hedgehog.position

func _process(_delta: float) -> void:
 if not is_instance_valid(garden) or garden.guide.visible:return
 if records.has("hedgehog") and int(records.hedgehog.resident_day)==0 and grass_ratio()>=0.05:record_resident("hedgehog")


```

## generate_ambience.py

```py
"""Generate original, deterministic environmental sound effects. Run with Python 3."""
import math
import random
import wave
from array import array
from pathlib import Path

RATE = 22050
OUT = Path(__file__).parent / 'audio' / 'ambience'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(4719)

def save(name, samples, loop=False):
    if loop:
        # Crossfade the last second into the first; no abrupt noise seam.
        n = RATE
        for i in range(n):
            a = i / n
            samples[i] = samples[-n+i] * (1-a) + samples[i] * a
        samples = samples[:-n]
    pcm = array('h', (int(max(-.95, min(.95, v)) * 32767) for v in samples))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())

for name in ('wind', 'rain', 'thunder', 'stream'):
    duration = 25 if name != 'thunder' else 9
    low = deep = 0.0
    samples = []
    for i in range(RATE * duration):
        t = i / RATE
        white = rng.uniform(-1, 1)
        low += .035 * (white-low)
        deep += .006 * (white-deep)
        if name == 'wind':
            value = (low * 1.7 + white * .025) * (.55 + .2*math.sin(t*.73) + .13*math.sin(t*1.3))
        elif name == 'rain':
            value = (white*.23 + low*.5) * (.85+.1*math.sin(t*.4))
        elif name == 'stream':
            value = (low*1.5 + white*.12) * (.75+.15*math.sin(t*2.3)) + .025*math.sin(math.tau*(420*t+18*math.sin(t*3)))
        else:
            envelope = min(1, t*12) * math.exp(-t*.48) * min(1, (duration-t)*2)
            value = (deep*6 + low*.7 + white*.045) * envelope
        samples.append(value)
    save(name, samples, name != 'thunder')

for name in ('birds', 'crickets'):
    samples = [0.0] * (RATE*25)
    count = 32 if name == 'birds' else 130
    for _ in range(count):
        start = rng.uniform(.3, 24)
        length = rng.uniform(.09, .3) if name == 'birds' else .065
        frequency = rng.uniform(1800, 3300) if name == 'birds' else 4200
        phase = 0.0
        for j in range(int(length*RATE)):
            index = int(start*RATE)+j
            if index >= len(samples):
                break
            t = j/RATE
            phase += math.tau*(frequency + 650*math.sin(t*18))/RATE
            samples[index] += .13*math.sin(phase)*math.sin(math.pi*t/length)**2
    save(name, samples, True)
print('Generated wind, rain, thunder, birds and crickets.')

```

## gliding_cursor.gd

```gd
extends Node3D

const FOLLOW_RATE := 12.0
const SIZE_RATE := 10.0
const FLOOR_OFFSET := 0.10
var ring: MeshInstance3D
var spin := 0.0
var target_position := Vector3.ZERO
var target_size := Vector2.ONE
var current_size := Vector2.ONE
var velocity := Vector3.ZERO
var bounds := Rect2i()
var initialized := false
var surface_height: Callable
var source_vertices := PackedVector3Array()
var source_colors := PackedColorArray()

func _ready() -> void:
	ring = MeshInstance3D.new()
	ring.name = "GoldBlueSpirit"
	ring.mesh = _arrow_ring()
	var data := ring.mesh.surface_get_arrays(0)
	# Subdivide each face so larger selection rings can bend over hollows.
	var raw: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = data[Mesh.ARRAY_COLOR]
	for i in range(0, raw.size(), 3):
		var a := raw[i]
		var b := raw[i+1]
		var c := raw[i+2]
		var ab := (a+b)*0.5
		var bc := (b+c)*0.5
		var ca := (c+a)*0.5
		for vertex in [a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca]:
			source_vertices.append(vertex)
			source_colors.append(colors[i])
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material
	add_child(ring)
	visible = false

func _arrow_ring() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(12):
		var turn := Basis(Vector3.UP, float(i) * TAU / 12.0)
		var top: Array[Vector3] = [Vector3(-0.09, 0.025, 0.48),
			Vector3(0.09, 0.025, 0.48), Vector3(0.0, 0.025, 0.30)]
		for p in top:
			vertices.append(turn * p)
			colors.append(Color("f4c568"))
		for edge in range(3):
			var a := top[edge]
			var b := top[(edge + 1) % 3]
			var c := a - Vector3.UP * 0.065
			var d := b - Vector3.UP * 0.065
			for p in [a, c, b, b, c, d]:
				vertices.append(turn * p)
				colors.append(Color("369eea"))
		for p in top:
			vertices.append(turn * (p - Vector3.UP * 0.065))
			colors.append(Color("2465ba"))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	if visible:
		spin += delta * 0.35
		_update_surface()

func select_bounds(selection: Rect2i, grid_min: Vector2, cell_size: float) -> void:
	if not selection.has_area():
		clear()
		return
	bounds = selection
	var center := grid_min + (Vector2(selection.position) + Vector2(selection.size) * 0.5) * cell_size
	target_position = Vector3(center.x, FLOOR_OFFSET, center.y)
	target_size = Vector2(selection.size) * cell_size
	if not initialized:
		position = target_position
		current_size = target_size
		velocity = Vector3.ZERO
		initialized = true
	_apply_size()
	visible = true

func advance(delta: float) -> void:
	if not visible or not initialized:
		return
	# Analytic critically damped spring: weighted motion independent of frame rate.
	var offset := position - target_position
	var impulse := velocity + offset * FOLLOW_RATE
	var decay := exp(-FOLLOW_RATE * delta)
	position = target_position + (offset + impulse * delta) * decay
	velocity = (velocity - impulse * FOLLOW_RATE * delta) * decay
	current_size = current_size.lerp(target_size, 1.0 - exp(-SIZE_RATE * delta))
	if position.distance_to(target_position) < 0.001 and velocity.length() < 0.01:
		position = target_position
		velocity = Vector3.ZERO
	if current_size.distance_to(target_size) < 0.001:
		current_size = target_size
	_apply_size()

func _apply_size() -> void:
	_update_surface()

func follow_feet(feet: Vector3, size: Vector2, delta: float) -> void:
	# Player movement provides the glide; keep the spirit directly beneath the player.
	position = feet + Vector3.UP * FLOOR_OFFSET
	target_position = position
	target_size = size
	if not initialized:
		current_size = size
		initialized = true
	current_size = current_size.lerp(size, 1.0 - exp(-SIZE_RATE * delta))
	if current_size.distance_to(size) < 0.001:
		current_size = size
	velocity = Vector3.ZERO
	_apply_size()
	visible = true

func is_settled() -> bool:
	return initialized and visible and position == target_position and current_size == target_size

func follow_object(feet: Vector3, size: Vector2, delta: float) -> void:
	target_position = feet + Vector3.UP * FLOOR_OFFSET
	target_size = size
	if not initialized:
		position = target_position
		current_size = size
		initialized = true
	visible = true
	advance(delta)

func clear() -> void:
	visible = false
	initialized = false
	velocity = Vector3.ZERO
	bounds = Rect2i()

func _update_surface() -> void:
	if not is_instance_valid(ring): return
	var vertices := PackedVector3Array()
	var turn := Basis(Vector3.UP, spin)
	for original in source_vertices:
		var p := turn * original
		p.x *= current_size.x
		p.z *= current_size.y
		if surface_height.is_valid():
			p.y += float(surface_height.call(Vector2(position.x+p.x,position.z+p.z))) - position.y + FLOOR_OFFSET
		p.y += sin(spin*4.0)*0.006
		vertices.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = source_colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ring.mesh = mesh

```

## grass.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
uniform float wind_time = 0.0;
uniform float rain_strength = 0.0;
uniform float wetness = 0.0;
uniform vec3 spirit_position;
uniform vec3 visitor_position;
uniform vec3 chicken_position;
varying float variation;

vec2 push_away(vec3 point, vec3 actor, float radius) {
	vec2 offset = point.xz - actor.xz;
	float distance_to_actor = length(offset);
	return offset / max(distance_to_actor, 0.01) * (1.0 - smoothstep(0.0, radius, distance_to_actor));
}
void vertex() {
	vec3 world_root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tip = UV.y * UV.y;
	float sway = sin(wind_time * 1.4 + world_root.x * 2.1 + world_root.z * 1.7 + INSTANCE_CUSTOM.x * 6.28);
	vec2 movement = vec2(sway, sway * 0.38) * (0.045 + rain_strength * 0.025);
	movement += push_away(world_root, spirit_position, 0.48) * 0.22;
	movement += push_away(world_root, visitor_position, 0.35) * 0.18;
	movement += push_away(world_root, chicken_position, 0.23) * 0.10;
	// Apply the bend in world space, preserving pinned roots and instance scale.
	VERTEX += (inverse(MODEL_MATRIX) * vec4(movement.x, -length(movement) * 0.35, movement.y, 0.0)).xyz * tip;
	variation = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec3 root_color = vec3(0.09, 0.18, 0.035);
	vec3 tip_color = mix(vec3(0.26, 0.39, 0.09), vec3(0.39, 0.44, 0.16), variation);
	ALBEDO = mix(root_color, tip_color, smoothstep(0.0, 1.0, UV.y)) * (1.0 - wetness * 0.16);
	ROUGHNESS = mix(0.92, 0.60, wetness);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}

```

## grass_field.gd

```gd
extends Node3D
## Instanced mesh blades, without selection or movement colliders.
var garden: Node3D
var patches: Dictionary = {}
var material: ShaderMaterial
var tuft: ArrayMesh
var wind_time := 0.0

func setup(world: Node3D) -> void:
	garden = world
	material = ShaderMaterial.new()
	material.shader = preload("res://grass.gdshader")
	tuft = _make_tuft()
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x):
			var cell := Vector2i(x, z)
			update_cell(cell, garden.get_terrain(cell))
	garden.terrain_changed.connect(update_cell)

func _make_tuft() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(7):
		var angle := blade * TAU / 7.0
		var sideways := Vector3(cos(angle), 0, sin(angle))
		var lean := Vector3(-sin(angle), 0, cos(angle)) * (0.12 + blade * 0.015)
		var base := sideways * 0.04
		for segment in range(3):
			var a := float(segment) / 3.0
			var b := float(segment + 1) / 3.0
			var lower := base + Vector3.UP * a + lean * a * a
			var upper := base + Vector3.UP * b + lean * b * b
			var half_a := sideways * (1.0 - a) * 0.065
			var half_b := sideways * (1.0 - b) * 0.065
			var points := [lower - half_a, lower + half_a, upper - half_b,
				upper - half_b, lower + half_a, upper + half_b]
			var uvs := [Vector2(0,a), Vector2(1,a), Vector2(0,b), Vector2(0,b), Vector2(1,a), Vector2(1,b)]
			for i in range(6):
				builder.set_uv(uvs[i])
				builder.add_vertex(points[i])
	builder.generate_normals()
	return builder.commit()

func update_cell(cell: Vector2i, kind: int) -> void:
	if patches.has(cell):
		var old: Node3D = patches[cell]
		old.hide()
		old.queue_free()
		patches.erase(cell)
	if kind != garden.Terrain.GRASS and kind != garden.Terrain.LONG_GRASS:
		return
	var tall: bool = kind == garden.Terrain.LONG_GRASS
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = tuft
	instances.instance_count = 52 if tall else 36
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891 + cell.x * 7919 + cell.y * 104729
	var center: Vector3 = garden.cell_center(cell)
	for i in range(instances.instance_count):
		var height := rng.randf_range(0.26, 0.46) if tall else rng.randf_range(0.08, 0.16)
		var width := rng.randf_range(0.38, 0.65) if tall else rng.randf_range(0.25, 0.40)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
		var margin: float = garden.MICRO_SIZE * 0.44
		var point := center + Vector3(rng.randf_range(-margin, margin), 0.005, rng.randf_range(-margin, margin))
		instances.set_instance_transform(i, Transform3D(basis, point))
		instances.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 1))
	var patch := MultiMeshInstance3D.new()
	patch.name = "Grass_%d_%d" % [cell.x, cell.y]
	patch.multimesh = instances
	patch.material_override = material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.extra_cull_margin = 0.4
	add_child(patch)
	patches[cell] = patch

func _process(delta: float) -> void:
	if not is_instance_valid(garden) or garden.guide.visible:
		return
	wind_time += delta
	material.set_shader_parameter("wind_time", wind_time)
	material.set_shader_parameter("spirit_position", garden.cursor.global_position)
	material.set_shader_parameter("visitor_position", garden.visitor.global_position)
	material.set_shader_parameter("chicken_position", garden.chicken.global_position)
	material.set_shader_parameter("rain_strength", garden.valley_cycle.rain_strength)
	material.set_shader_parameter("wetness", garden.valley_cycle.wetness)

```

## hedgehog_intro.gd

```gd
extends Node3D
signal finished
const CAPTIONS=preload("res://arthur_hedgehog_subtitles.gd").CUES
const VOICE=preload("res://assets/sounds/dialogue/Arthur_Hedgehogs.mp3")
const TALK_CLIPS=["Talking_1","Talking_2"]
const CAMERA_SECONDS:=0.85
var garden: Node3D
var arthur: Node3D
var active:=false
var paused:=false
var completed:=false
var pending:=false
var phase:="idle"
var phase_time:=0.0
var clip_time:=0.0
var clip_index:=0
var played_clips: Array[String]=[]
var camera: Camera3D
var voice: AudioStreamPlayer
var ui: CanvasLayer
var bubble: PanelContainer
var caption: Label
var pause_label: Label
var return_transform:=Transform3D.IDENTITY
var portrait_transform:=Transform3D.IDENTITY
var hidden_layers: Array[Dictionary]=[]
var frozen_actors: Array[Dictionary]=[]
var paused_audio: Array[Dictionary]=[]
var previous_animation: StringName
var previous_animation_position:=0.0
var previous_animation_speed:=1.0
var previous_mouse_mode:=Input.MOUSE_MODE_CAPTURED
var tool_visible:=true
var tool_processing:=true

func setup(world: Node3D) -> void:
 garden=world
 arthur=garden.get_node("Arthur")
 camera=Camera3D.new()
 camera.name="ArthurPortraitCamera"
 camera.near=0.04
 camera.far=500.0
 camera.fov=42.0
 add_child(camera)
 voice=AudioStreamPlayer.new()
 voice.name="ArthurHedgehogVoice"
 voice.stream=VOICE
 voice.volume_db=-1.0
 add_child(voice)
 voice.finished.connect(_begin_return)
 ui=CanvasLayer.new()
 ui.layer=90
 add_child(ui)
 bubble=preload("res://arthur_speech_bubble.gd").new()
 bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE
 bubble.custom_minimum_size=Vector2(420,0)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("f4ead2")
 style.border_color=Color("b69755")
 style.set_border_width_all(2)
 style.set_corner_radius_all(18)
 style.content_margin_left=24
 style.content_margin_right=24
 style.content_margin_top=16
 style.content_margin_bottom=20
 style.shadow_color=Color(0,0,0,0.3)
 style.shadow_size=8
 bubble.add_theme_stylebox_override("panel",style)
 ui.add_child(bubble)
 var stack:=VBoxContainer.new()
 stack.add_theme_constant_override("separation",8)
 bubble.add_child(stack)
 stack.add_child(garden._label("ARTHUR",17,Color("796033")))
 caption=garden._label("",22,Color("302e24"))
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 caption.custom_minimum_size=Vector2(372,78)
 stack.add_child(caption)
 pause_label=garden._label("PAUSED\nEsc / Start to continue",20,Color("f4dfaa"))
 ui.add_child(pause_label)
 pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 pause_label.offset_left=-220
 pause_label.offset_right=220
 pause_label.offset_top=-100
 pause_label.offset_bottom=-28
 pause_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 pause_label.add_theme_color_override("font_shadow_color",Color.BLACK)
 pause_label.add_theme_constant_override("shadow_offset_y",2)
 bubble.hide()
 pause_label.hide()
 ui.hide()
 garden.wildlife.animal_event.connect(_animal_event)

func _animal_event(kind: String, species: String, _day: int) -> void:
 if kind=="visit" and species=="hedgehog" and not completed and not active:
  pending=true

func save_data() -> Dictionary:
 return {"completed":completed,"pending":pending or (active and not completed)}

func restore(data: Dictionary) -> void:
 # Existing gardens with a previously recorded visit do not replay old arrivals.
 completed=bool(data.get("completed",garden.wildlife.records.has("hedgehog")))
 pending=not completed and (bool(data.get("pending",false)) or garden.wildlife.records.has("hedgehog"))

func _can_begin() -> bool:
 return garden.is_visible_in_tree() and not garden.guide.visible and not garden.tool_wheel.visible and not garden.field_book.visible and not garden.dev_console.opened

func _begin() -> void:
 if active or completed or not is_instance_valid(arthur):return
 for clip in TALK_CLIPS:
  if not arthur.animation_player.has_animation(clip):
   push_error("Arthur is missing the talking animation: "+clip)
   pending=false
   return
 active=true
 pending=false
 paused=false
 phase="approach"
 phase_time=0.0
 garden._clear_use()
 garden.player.velocity=Vector3.ZERO
 garden.cursor.clear()
 garden.aiming=false
 previous_mouse_mode=Input.mouse_mode
 Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
 tool_visible=garden.floating_tool.visible
 tool_processing=garden.floating_tool.is_processing()
 garden.floating_tool.hide()
 garden.floating_tool.set_process(false)
 hidden_layers.clear()
 for layer in garden.find_children("*","CanvasLayer",true,false):
  if layer==ui:continue
  hidden_layers.append({"node":layer,"visible":layer.visible})
  layer.hide()
 frozen_actors.clear()
 for actor in garden.get_children():
  if actor is CharacterBody3D:
   frozen_actors.append({"node":actor,"physics":actor.is_physics_processing()})
   actor.set_physics_process(false)
 paused_audio.clear()
 for audio in garden.find_children("*","AudioStreamPlayer3D",true,false):
  paused_audio.append({"node":audio,"paused":audio.stream_paused})
  audio.stream_paused=true
 garden.ambience.dialogue_duck=0.3
 var player: AnimationPlayer=arthur.animation_player
 previous_animation=player.current_animation
 previous_animation_position=player.current_animation_position
 previous_animation_speed=player.speed_scale
 player.speed_scale=1.0
 player.play("Happy_Idle",0.25)
 return_transform=garden.camera.global_transform
 camera.global_transform=return_transform
 camera.environment=garden.camera.environment
 var forward: Vector3=arthur.visual.global_basis.z.normalized()
 forward.y=0.0
 forward=forward.normalized()
 var focus:=arthur.global_position+Vector3.UP*1.12
 # Frame Arthur left of centre, keeping room for a readable speech bubble.
 var screen_right:=Vector3.UP.cross(forward).normalized()
 var at:=focus+forward*2.25+Vector3.UP*0.03
 var target:=focus+screen_right*0.32
 portrait_transform=Transform3D(Basis.looking_at(target-at,Vector3.UP),at)
 camera.make_current()
 played_clips.clear()
 bubble.hide()
 pause_label.hide()
 ui.show()

func _play_talk() -> void:
 var clip: String=TALK_CLIPS[clip_index]
 arthur.animation_player.play(clip,0.3)
 arthur.animation_player.advance(0.0)
 clip_time=0.0
 if not played_clips.has(clip):played_clips.append(clip)

func subtitle_at(seconds: float) -> String:
 for cue in CAPTIONS:
  if seconds>=float(cue.start) and seconds<float(cue.end):return cue.text
 return ""

func _process(delta: float) -> void:
 if not active:
  bubble.hide()
  pause_label.hide()
  ui.hide()
  if pending and _can_begin():_begin()
  return
 if paused:return
 phase_time+=delta
 match phase:
  "approach":
   camera.global_transform=return_transform.interpolate_with(portrait_transform,smoothstep(0.0,CAMERA_SECONDS,phase_time))
   arthur.animation_player.advance(delta)
   if phase_time>=CAMERA_SECONDS:
    phase="talk"
    phase_time=0.0
    clip_index=0
    _play_talk()
    voice.play()
  "talk":
   clip_time+=delta
   var duration: float=minf(6.0,arthur.animation_player.get_animation(TALK_CLIPS[clip_index]).length)
   if clip_time>=duration:
    clip_index=(clip_index+1)%TALK_CLIPS.size()
    _play_talk()
   arthur.animation_player.advance(delta)
   var seconds:=maxf(0.0,voice.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
   caption.text=subtitle_at(seconds)
   var face:=camera.unproject_position(arthur.global_position+Vector3.UP*1.35)
   var viewport:=get_viewport().get_visible_rect().size
   bubble.position=Vector2(clampf(face.x+140.0,32.0,viewport.x-452.0),clampf(face.y+20.0,40.0,viewport.y-240.0))
   bubble.visible=voice.playing and not caption.text.is_empty()
  "return":
   arthur.animation_player.advance(delta)
   camera.global_transform=portrait_transform.interpolate_with(return_transform,smoothstep(0.0,CAMERA_SECONDS,phase_time))
   if phase_time>=CAMERA_SECONDS:_finish()

func _begin_return() -> void:
 if not active or phase=="return":return
 completed=true
 pending=false
 phase="return"
 phase_time=0.0
 bubble.hide()
 arthur.animation_player.play("Happy_Idle",0.3)

func set_paused(value: bool) -> void:
 if not active:return
 paused=value
 voice.stream_paused=value
 pause_label.visible=value

func _input(event: InputEvent) -> void:
 if not active:return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide"):
  set_paused(not paused)
 get_viewport().set_input_as_handled()

func _finish() -> void:
 voice.stop()
 voice.stream_paused=false
 bubble.hide()
 caption.text=""
 pause_label.hide()
 ui.hide()
 garden.camera.global_transform=return_transform
 garden.camera.make_current()
 for entry in hidden_layers:
  if is_instance_valid(entry.node):entry.node.visible=entry.visible
 for entry in frozen_actors:
  if is_instance_valid(entry.node):entry.node.set_physics_process(entry.physics)
 for entry in paused_audio:
  if is_instance_valid(entry.node):entry.node.stream_paused=entry.paused
 var player: AnimationPlayer=arthur.animation_player
 if not previous_animation.is_empty() and player.has_animation(previous_animation):
  player.play(previous_animation,0.25)
  player.seek(previous_animation_position,true)
 player.speed_scale=previous_animation_speed
 garden.floating_tool.visible=tool_visible
 garden.floating_tool.set_process(tool_processing)
 garden.ambience.dialogue_duck=1.0
 garden.aiming=true
 Input.mouse_mode=previous_mouse_mode
 garden._clear_use()
 active=false
 paused=false
 phase="idle"
 finished.emit()
 var host:=garden.get_parent()
 if host.has_method("_save_garden"):host.call_deferred("_save_garden")

```

## hedgehog_npc.gd

```gd
extends "res://wandering_npc.gd"
const HEDGEHOG = preload("res://assets/hedgehog.glb")
var body: Node3D
var gait := 0.0
var sniff_time := 0.0
var walk_time := 5.0

func _create_visual() -> void:
 collision_radius = 0.18
 collision_height = 0.28
 cell = Vector2i(1,6)
 next_cell = cell
 move_speed = 0.23
 visual = Node3D.new()
 add_child(visual)
 body = HEDGEHOG.instantiate()
 body.scale = Vector3.ONE * (0.35 / 0.976685)
 visual.add_child(body)
 # The file has unnamed zero-rest bones and no clips. Use its undeformed mesh
 # with whole-body procedural animation, rather than relying on that rig.
 for part in body.find_children("*","MeshInstance3D",true,false):
  var source: Mesh = part.mesh
  var mesh := ArrayMesh.new()
  for surface in range(source.get_surface_count()):
   var arrays := source.surface_get_arrays(surface)
   arrays[Mesh.ARRAY_BONES] = null
   arrays[Mesh.ARRAY_WEIGHTS] = null
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   mesh.surface_set_material(surface,source.surface_get_material(surface))
  part.mesh = mesh
  part.skin = null
  part.skeleton = NodePath("")
 animation_player = AnimationPlayer.new()
 add_child(animation_player)
 walk_time = rng.randf_range(4,8)

func advance(delta: float) -> void:
 if garden.guide.visible: return
 gait += delta
 if sniff_time > 0:
  sniff_time = maxf(0,sniff_time-delta)
  walking = false
  body.rotation.x = sin(gait*5.0)*0.10
  body.rotation.z = sin(gait*2.0)*0.025
  body.position.y = 0.003+sin(gait*3.0)*0.002
 else:
  super.advance(delta)
  walk_time -= delta
  body.rotation.x = sin(gait*8.0)*0.025
  body.rotation.z = sin(gait*10.0)*0.07
  body.position.y = absf(sin(gait*10.0))*0.008
  if walk_time<=0 and position.distance_to(destination)<0.03:
   sniff_time = rng.randf_range(2,4)
   walk_time = rng.randf_range(4,9)
 var breathing := 1.0+sin(gait*2.5)*0.012
 body.scale = Vector3(1,breathing,1)*(0.35/0.976685)

```

## height_terrain.gd

```gd
extends Node3D

const RESOLUTION := 12
const WATER_LEVEL := 0.012
const BASE_LEVEL := -0.95
const MAX_MEADOW_HEIGHT := 0.18
const HEIGHT_PROFILE_VERSION := 2
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
   var rolling := 0.10 + noise.get_noise_2dv(p)*0.18
   rolling += 0.025*sin(p.x*0.75)*cos(p.y*0.65)
   heights.set_pixel(x,z,Color(clampf(rolling,0.0,MAX_MEADOW_HEIGHT)*edge*working_plot,0,0))

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
 value=clampf(value,BASE_LEVEL+0.12,MAX_MEADOW_HEIGHT)
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
 var baseline:=0.0 # Thump always sets the entire selected tile to garden zero.
 # Integer bounds include every shared edge and corner of the selected tile.
 var tile_steps:=roundi(float(garden.MICRO_SIZE)/spacing)
 var tile_low:=cell*tile_steps
 var tile_high:=tile_low+Vector2i.ONE*tile_steps
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
    3:
     var outside:=Vector2(maxi(maxi(tile_low.x-x,0),x-tile_high.x),maxi(maxi(tile_low.y-z,0),z-tile_high.y))*spacing
     # Full strength across the square; blend only beyond its boundary.
     var tile_weight:=1.0-smoothstep(0.0,0.3,outside.length())
     value=baseline if outside==Vector2.ZERO else lerpf(old,baseline,tile_weight)
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
 return {"profile_version":HEIGHT_PROFILE_VERSION,"samples":[samples.x,samples.y],"heights":values,"seed_holes":holes}

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
  # Older positive edits used the much taller meadow. Preserve excavations.
  if int(data.get("profile_version",1))<HEIGHT_PROFILE_VERSION and height>0.0:height*=0.35
  _write_height(cell.x,cell.y,height)
  var area:=Rect2i(cell,Vector2i.ONE)
  changed=area if changed.size==Vector2i.ZERO else changed.merge(area)
 for value in data.get("seed_holes",[]):
  if value is Array and value.size()==2:
   var cell:=Vector2i(int(value[0]),int(value[1]))
   if garden.contains_cell(cell):seed_holes[cell]=true
 _rebuild_samples(changed)

```

## import_angus.py

```py
"""Run with Blender --background --python import_angus.py."""
import bpy
from pathlib import Path
source=Path(r'C:\Users\Shadow\OneDrive\Desktop\CWTCH\NPCS\Angus-McDoogal')
out=Path(__file__).resolve().parent/'assets'/'npcs'/'angus.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source/'Angus.fbx'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data.action.name='Angus_Performance'
for image in bpy.data.images:
 if image.source=='FILE': image.pack()
for material in bpy.data.materials:
 if material.use_nodes:
  shader=material.node_tree.nodes.get('Principled BSDF')
  if shader: shader.inputs['Roughness'].default_value=.85
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
print('EXPORTED',out)

```

## import_garden_npcs.py

```py
"""Combine the supplied NPC FBX clips and textures into portable Godot GLBs.
Run with Blender --background --python import_garden_npcs.py.
"""
import bpy
from pathlib import Path
SOURCE = Path(r'C:\Users\Shadow\OneDrive\Desktop\CWTCH\NPCS')
OUTPUT = Path(__file__).resolve().parent / 'assets' / 'npcs'
OUTPUT.mkdir(parents=True, exist_ok=True)
for name in ('Arthur', 'Meera'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = SOURCE / name
    bpy.ops.import_scene.fbx(filepath=str(folder / (name + '_Walking.fbx')))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    actions = [('Walking', rig.animation_data.action)]
    rig.animation_data.action = None
    for path in sorted(folder.glob(name + '_*.fbx')):
        if path.stem.endswith('_Walking'): continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(path))
        imported = set(bpy.data.objects) - before
        donor = next(o for o in imported if o.type == 'ARMATURE')
        assert set(rig.data.bones.keys()) == set(donor.data.bones.keys()), path
        action = donor.animation_data.action
        action.use_fake_user = True
        actions.append((path.stem[len(name)+1:], action))
        for obj in imported: bpy.data.objects.remove(obj, do_unlink=True)
    texture = bpy.data.images.load(str(next(folder.glob('*.jpg'))))
    texture.pack()
    material = bpy.data.materials.new(name + ' Clothing')
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .86
    image = material.node_tree.nodes.new('ShaderNodeTexImage')
    image.image = texture
    material.node_tree.links.new(image.outputs['Color'], bsdf.inputs['Base Color'])
    for mesh in meshes:
        mesh.data.materials.clear()
        mesh.data.materials.append(material)
    for label, action in actions:
        action.name = label
        track = rig.animation_data.nla_tracks.new()
        track.name = label
        strip = track.strips.new(label, 1, action)
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (name.lower() + '.glb')),
        export_format='GLB', export_animation_mode='NLA_TRACKS',
        export_anim_slide_to_zero=True, export_force_sampling=True)
    print('EXPORTED', name, [label for label, _ in actions])

```

## imported_trees.gd

```gd
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

```

## land_area_page.gd

```gd
extends Control
## One map pixel-block per micro-tile, measured from the editable garden only.
const COLORS := [Color("876343"),Color("b29a76"),Color("72914b"),Color("365d39"),Color("68a5ad"),Color("365574"),Color("cdb891"),Color("85858b")]
const INK := Color("483322")
const MAP := Rect2(40,15,330,330)
var garden: Node3D
var font: Font
var counts: Array[int]=[]
var percentages: Array[float]=[]
var tile_types: Array[int]=[]
var selected := Vector2i.ZERO
var dirty := true

func setup(world: Node3D, handwriting: Font) -> void:
 if garden!=world:
  if is_instance_valid(garden) and garden.terrain_changed.is_connected(_changed):garden.terrain_changed.disconnect(_changed)
  garden=world
  garden.terrain_changed.connect(_changed)
 font=handwriting
 position=Vector2(80,138)
 size=Vector2(920,374)
 mouse_filter=Control.MOUSE_FILTER_PASS
 selected=selected.clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 refresh()

func _changed(_cell: Vector2i, _kind: int) -> void:
 dirty=true

func refresh() -> void:
 counts.assign([0,0,0,0,0,0,0,0])
 tile_types.clear()
 var total: int=garden.grid_size.x*garden.grid_size.y
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   var kind: int=garden.get_terrain(Vector2i(x,z))
   tile_types.append(kind)
   counts[kind]+=1
 percentages.clear()
 for count in counts:percentages.append(100.0*float(count)/float(total))
 dirty=false
 queue_redraw()

func _process(_delta: float) -> void:
 if is_visible_in_tree() and dirty:refresh()

func move_selection(offset: Vector2i) -> void:
 selected=(selected+offset).clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 queue_redraw()

func turn(direction: int) -> void:
 var index: int=posmod(selected.y*garden.grid_size.x+selected.x+direction,tile_types.size())
 selected=Vector2i(index%garden.grid_size.x,index/garden.grid_size.x)
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion or event is InputEventMouseButton and event.pressed:
  var point: Vector2=event.position
  if MAP.has_point(point):
   selected=Vector2i((point-MAP.position)/MAP.size*Vector2(garden.grid_size)).clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
   queue_redraw()
   accept_event()

func _draw() -> void:
 if not is_instance_valid(garden) or tile_types.is_empty():return
 var cell_size:=MAP.size/Vector2(garden.grid_size)
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   draw_rect(Rect2(MAP.position+Vector2(x,z)*cell_size,cell_size),COLORS[tile_types[z*garden.grid_size.x+x]])
 for x in range(garden.grid_size.x+1):
  var px:=MAP.position.x+x*cell_size.x
  draw_line(Vector2(px,MAP.position.y),Vector2(px,MAP.end.y),Color(0.24,0.17,0.1,0.22))
 for z in range(garden.grid_size.y+1):
  var pz:=MAP.position.y+z*cell_size.y
  draw_line(Vector2(MAP.position.x,pz),Vector2(MAP.end.x,pz),Color(0.24,0.17,0.1,0.22))
 draw_rect(MAP,INK,false,2)
 var chosen:=Rect2(MAP.position+Vector2(selected)*cell_size,cell_size)
 draw_rect(chosen,Color("fff1c9"),false,3)
 draw_rect(chosen.grow(1),INK,false,1)
 _text(Vector2(173,9),"↑ NORTH",13)
 var kind: int=tile_types[selected.y*garden.grid_size.x+selected.x]
 _text(Vector2(30,366),"Tile %d, %d  ·  %s"%[selected.x+1,selected.y+1,garden.TERRAIN_NAMES[kind]],16)
 _text(Vector2(500,96),"%.0f m × %.0f m   ·   %d tiles"%[garden.chunk_count.x*garden.CHUNK_SIZE,garden.chunk_count.y*garden.CHUNK_SIZE,tile_types.size()],17)
 for i in counts.size():
  var y:=128.0+i*28.0
  draw_rect(Rect2(500,y-13,14,14),COLORS[i])
  draw_rect(Rect2(500,y-13,14,14),INK,false,1)
  _text(Vector2(524,y),garden.TERRAIN_NAMES[i],17)
  _text(Vector2(706,y),str(counts[i]),16)
  _text(Vector2(820,y),"%.2f%%"%percentages[i],16)
 _text(Vector2(500,366),"Garden ground only. Each square is one tile.",14)

func _text(at: Vector2, value: String, font_size: int) -> void:
 draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,INK)

```

## landscape_surface.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 haze_color : source_color = vec3(0.53,0.62,0.66);
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
uniform float scenery_time = 0.0;
varying vec3 point;
varying vec3 slope_normal;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;slope_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 vec3 blend=pow(abs(slope_normal),vec3(4.0));blend/=max(dot(blend,vec3(1.0)),0.0001);
 vec3 grass=texture(color_maps,vec3(point.xz,1.0)).rgb;
 vec3 soil=texture(color_maps,vec3(point.xz*0.8,0.0)).rgb;
 vec3 rock=texture(color_maps,vec3(point.yz*0.45,2.0)).rgb*blend.x+texture(color_maps,vec3(point.xz*0.45,2.0)).rgb*blend.y+texture(color_maps,vec3(point.xy*0.45,2.0)).rgb*blend.z;
 rock=mix(rock,texture(color_maps,vec3(point.xz*0.055,2.0)).rgb,0.28);
 float steep=smoothstep(0.12,0.58,1.0-abs(slope_normal.y));
 float altitude=smoothstep(12.0,40.0,point.y);
 vec3 ground=mix(grass,soil,steep*0.35);
 ground=mix(ground,rock,max(steep,altitude));
 ground*=mix(vec3(1.0),vec3(0.72,0.82,0.96),altitude);
 float snow=smoothstep(43.0,67.0,point.y+sin(point.x*0.17)*3.0)*smoothstep(0.2,0.75,abs(slope_normal.y));
 ground=mix(ground,vec3(0.79,0.83,0.83),snow);
 float distance_haze=(1.0-exp(-max(distance(CAMERA_POSITION_WORLD,point)-45.0,0.0)*0.003));
 ALBEDO=mix(ground*(1.0-rain_strength*0.16),haze_color,distance_haze*0.24);
 ROUGHNESS=0.96;
 SPECULAR=0.1;
 if(!FRONT_FACING){NORMAL=-NORMAL;}
}

```

## main.gd

```gd
extends Node3D

signal micro_tile_hovered(cell: Vector2i, terrain: int)
signal terrain_changed(cell: Vector2i, terrain: int)

enum Terrain { DIRT, HARD_DIRT, GRASS, LONG_GRASS, WATER, DEEP_WATER, PATH, STONE }
const CHUNK_SIZE := 2.0
const SUBDIVISIONS := 3
const MICRO_SIZE := CHUNK_SIZE / float(SUBDIVISIONS)
const FLOOR_MASK := 1
const INVALID_CELL := Vector2i(-1, -1)
const TERRAIN_NAMES := ["Dirt", "Hard dirt", "Grass", "Long grass", "Water", "Deep water", "Path", "Stone"]

@export var chunk_count := Vector2i(3, 3)

var grid_size: Vector2i
var grid_min: Vector2
var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_material: ShaderMaterial
var chunks: Dictionary = {}
var camera: Camera3D
var cursor: Node3D
var status: Label
var hovered_cell := INVALID_CELL
var selected_terrain: int = Terrain.GRASS
var paint_requested := false

func _ready() -> void:
	chunk_count = Vector2i(maxi(chunk_count.x, 1), maxi(chunk_count.y, 1))
	grid_size = chunk_count * SUBDIVISIONS
	grid_min = -Vector2(chunk_count) * CHUNK_SIZE * 0.5
	_create_terrain()
	_create_chunks()
	_create_view()
	_create_cursor()
	_update_status()

func _create_terrain() -> void:
	terrain_image = Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_R8)
	# Seven demonstration bands; each row crosses chunk boundaries.
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			var kind := mini(int(float(z) * 7.0 / float(grid_size.y)), 6)
			terrain_image.set_pixel(x, z, Color(float(kind) / 255.0, 0.0, 0.0))
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://terrain.gdshader")
	terrain_material.set_shader_parameter("terrain_ids", terrain_texture)
	terrain_material.set_shader_parameter("grid_size", Vector2(grid_size))
	terrain_material.set_shader_parameter("grid_min", grid_min)
	terrain_material.set_shader_parameter("micro_size", MICRO_SIZE)
	terrain_material.set_shader_parameter("world_to_grid", global_transform.affine_inverse())

func _create_chunks() -> void:
	# Same dimensions and nine surface quads as the Blender asset.
	var surface := PlaneMesh.new()
	surface.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	surface.subdivide_width = SUBDIVISIONS - 1
	surface.subdivide_depth = SUBDIVISIONS - 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(CHUNK_SIZE, 0.2, CHUNK_SIZE)
	for z in range(chunk_count.y):
		for x in range(chunk_count.x):
			var chunk := Node3D.new()
			chunk.name = "Chunk_%d_%d" % [x, z]
			chunk.position = Vector3(grid_min.x + (x + 0.5) * CHUNK_SIZE,
				0.0, grid_min.y + (z + 0.5) * CHUNK_SIZE)
			add_child(chunk)
			chunks[Vector2i(x, z)] = chunk
			var ground := MeshInstance3D.new()
			ground.mesh = surface
			ground.material_override = terrain_material
			chunk.add_child(ground)
			var body := StaticBody3D.new()
			body.collision_layer = FLOOR_MASK
			body.collision_mask = 0
			chunk.add_child(body)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position.y = -0.1
			body.add_child(collider)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(chunk_count.x * CHUNK_SIZE, 0.3, chunk_count.y * CHUNK_SIZE)
	base.mesh = box
	base.position.y = -0.155
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("493a2d")
	earth.roughness = 1.0
	base.material_override = earth
	add_child(base)

func _create_view() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7.0, 9.0, 9.0)
	camera.look_at(to_global(Vector3.ZERO), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(chunk_count.x, chunk_count.y) * CHUNK_SIZE * 1.7
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263137")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c2cb")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var ui := CanvasLayer.new()
	add_child(ui)
	status = Label.new()
	status.position = Vector2(20.0, 20.0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(status)

func _create_cursor() -> void:
	cursor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * MICRO_SIZE * 0.95
	cursor.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://cursor.gdshader")
	cursor.material_override = material
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			selected_terrain = event.keycode - KEY_1
			_update_status()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			paint_requested = true

func _physics_process(_delta: float) -> void:
	terrain_material.set_shader_parameter("world_to_grid", global_transform.affine_inverse())
	var cell := INVALID_CELL
	var mouse := get_viewport().get_mouse_position()
	if get_viewport().get_visible_rect().has_point(mouse):
		var origin := camera.project_ray_origin(mouse)
		var end := origin + camera.project_ray_normal(mouse) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(origin, end, FLOOR_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var local_hit := to_local(hit["position"])
			# Reject the side walls of floor colliders.
			if absf(local_hit.y) < 0.001:
				cell = local_to_cell(local_hit)
	cursor.visible = cell != INVALID_CELL
	if cursor.visible:
		cursor.position = cell_center(cell) + Vector3.UP * 0.025
	if cell != hovered_cell:
		hovered_cell = cell
		micro_tile_hovered.emit(cell, get_terrain(cell))
		_update_status()
	if paint_requested and cell != INVALID_CELL:
		set_terrain(cell, selected_terrain)
	paint_requested = false

func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func local_to_cell(point: Vector3) -> Vector2i:
	var p := (Vector2(point.x, point.z) - grid_min) / MICRO_SIZE
	var cell := Vector2i(floori(p.x), floori(p.y))
	return cell if contains_cell(cell) else INVALID_CELL

func cell_center(cell: Vector2i) -> Vector3:
	var p := grid_min + (Vector2(cell) + Vector2.ONE * 0.5) * MICRO_SIZE
	return Vector3(p.x, 0.0, p.y)

func get_terrain(cell: Vector2i) -> int:
	if not contains_cell(cell):
		return -1
	return roundi(terrain_image.get_pixel(cell.x, cell.y).r * 255.0)

func set_terrain(cell: Vector2i, terrain: int) -> void:
	if not contains_cell(cell) or terrain < Terrain.DIRT or terrain > Terrain.STONE:
		return
	if get_terrain(cell) == terrain:
		return
	terrain_image.set_pixel(cell.x, cell.y, Color(float(terrain) / 255.0, 0.0, 0.0))
	terrain_texture.update(terrain_image)
	terrain_changed.emit(cell, terrain)
	_update_status()

func _update_status() -> void:
	status.text = "ABERGLEN\n1–7: select terrain • Left click: paint\nBrush: %s\nCell: %s" % [
		TERRAIN_NAMES[selected_terrain], str(hovered_cell)]

```

## main.tscn

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://garden.gd" id="1"]

[node name="Aberglen" type="Node3D"]
script = ExtResource("1")
chunk_count = Vector2i(12, 12)

```

## main_menu.gd

```gd
extends Node3D
## The menu stays alive while the garden runs, preserving its scene and clock.
const Ambience = preload("res://valley_ambience.gd")
const Weather = preload("res://valley_cycle.gd")
const SAVE_PATH := "user://garden.json"
const OPTIONS_PATH := "user://options.json"
var stage: Node3D
var interface: CanvasLayer
var camera: Camera3D
var sun: DirectionalLight3D
var lightning: DirectionalLight3D
var world: WorldEnvironment
var ambience: Node
var sky_material: ShaderMaterial
var scenery_material: ShaderMaterial
var rain: CPUParticles3D
var birds: Array[Node3D] = []
var landscape: Node3D
var garden: Node3D
var village: Node3D
var coins := 500
var purchases: Array = []
var menu_active := true
var elapsed := 1000.0
var weather_elapsed := 0.0
var weather_index := 0
var rain_strength := 0.0
var cloud_cover := 0.3
var flash := 0.0
var storm_wait := 12.0
var thunder_delay := -1.0
var options: PanelContainer
var menu_buttons: VBoxContainer
var heading: VBoxContainer
var weather_label: Label
var loading_label: Label
var new_dialog: ConfirmationDialog
var rng := RandomNumberGenerator.new()
var weather_override := -1

func _ready() -> void:
	get_tree().root.theme = preload("res://cwtch_theme.gd").make()
	get_tree().auto_accept_quit = false
	rng.seed = 1891
	stage = Node3D.new()
	add_child(stage)
	_build_landscape()
	_build_ui()
	ControllerInput.mode_changed.connect(_focus_menu)
	ambience = Ambience.new()
	ambience.stream_level = 0.22
	add_child(ambience)
	_load_options()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_weather(0.0)
	var model_weather := preload("res://model_weather.gd").new()
	stage.add_child(model_weather)
	model_weather.setup(self)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _build_landscape() -> void:
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.position = Vector3(17,16,110)
	camera.look_at(Vector3(-5,31,-80))
	camera.far = 300
	camera.current = true
	sun = DirectionalLight3D.new()
	stage.add_child(sun)
	world = WorldEnvironment.new()
	stage.add_child(world)
	preload("res://welsh_sky.gd").apply(world,sun)
	camera.environment = world.environment
	sky_material = world.environment.sky.sky_material
	world.environment.sky.sky_material = sky_material
	world.environment.fog_enabled = true
	world.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	lightning = DirectionalLight3D.new()
	lightning.rotation_degrees = Vector3(-55,-20,0)
	lightning.light_energy = 0
	stage.add_child(lightning)
	landscape = preload("res://menu_valley_3d.gd").new()
	stage.add_child(landscape)
	landscape.build()
	birds = landscape.birds
	scenery_material = landscape.material
	rain = CPUParticles3D.new()
	rain.position = Vector3(10,40,85)
	rain.amount = 1200
	rain.lifetime = 2.5
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(40,0.1,22)
	rain.direction = Vector3(0.12,-1,0)
	rain.spread = 4
	rain.initial_velocity_min = 10
	rain.initial_velocity_max = 12
	var drop := BoxMesh.new()
	drop.size = Vector3(0.035,0.6,0.035)
	var drop_material := _material(Color(0.65,0.75,0.8,0.35))
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_material
	rain.mesh = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(rain)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _style(color: Color) -> StyleBoxFlat:
	return preload("res://cwtch_theme.gd").panel(color)

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.custom_minimum_size = Vector2(280,51)
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_color_override("font_color",Color("ecdfbd"))
	button.add_theme_stylebox_override("normal",_style(Color(0.08,0.15,0.13,0.89)))
	button.add_theme_stylebox_override("hover",_style(Color(0.22,0.29,0.21,0.97)))
	button.add_theme_stylebox_override("pressed",_style(Color("172a24")))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	interface = CanvasLayer.new()
	add_child(interface)
	var root := Control.new()
	root.theme = preload("res://cwtch_theme.gd").make()
	interface.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading = VBoxContainer.new()
	root.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	heading.offset_left = -300
	heading.offset_right = 300
	heading.offset_top = 146
	var title := _label("CWTCH",112,Color("ffbf55"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial","Segoe UI"])
	font.font_weight = 800
	title.add_theme_font_override("font",font)
	title.add_theme_color_override("font_shadow_color",Color(0.16,0.29,0.31,0.45))
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",3)
	title.add_theme_constant_override("shadow_outline_size",0)
	heading.add_child(title)
	var tagline := _label("Y O U R  S L I C E  O F  T H E\nV A L L E Y.",20,Color("ffbf55"))
	tagline.add_theme_font_override("font",font)
	tagline.add_theme_color_override("font_shadow_color",Color("18251f"))
	tagline.add_theme_constant_override("shadow_offset_y",2)
	heading.add_child(tagline)
	menu_buttons = VBoxContainer.new()
	menu_buttons.add_theme_constant_override("separation",12)
	root.add_child(menu_buttons)
	menu_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu_buttons.offset_left = -150
	menu_buttons.offset_right = 150
	menu_buttons.offset_top = -285
	menu_buttons.offset_bottom = -24
	_button("enter garden",func(): _begin_garden(false),menu_buttons)
	_button("new garden",_request_new,menu_buttons)
	_button("options",func(): options.show(); menu_buttons.hide(); heading.hide(); ControllerInput.focus_first.call_deferred(options),menu_buttons)
	_button("QUIT GAME",save_and_quit,menu_buttons)
	weather_label = _label("",14,Color("66818a"))
	root.add_child(weather_label)
	weather_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	weather_label.offset_left = 24
	weather_label.offset_right = 310
	weather_label.offset_top = -32
	weather_label.offset_bottom = -10
	loading_label = _label("",18,Color("f2e5c4"))
	root.add_child(loading_label)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.offset_left = -220
	loading_label.offset_right = 220
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "A FRESH GARDEN"
	new_dialog.dialog_text = "START AGAIN? THIS REPLACES YOUR SAVED GARDEN."
	new_dialog.confirmed.connect(func(): _begin_garden(true))
	root.add_child(new_dialog)
	new_dialog.get_ok_button().text="START AGAIN"
	new_dialog.get_cancel_button().text="CANCEL"
	options = PanelContainer.new()
	root.add_child(options)
	options.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options.offset_left = -220
	options.offset_right = 220
	options.offset_top = -55
	options.add_theme_stylebox_override("panel",_style(Color(0.07,0.13,0.12,0.97)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	options.add_child(box)
	box.add_child(_label("options",24,Color("e2bf6e")))
	box.add_child(_label("Sound volume",16,Color("eee6d0")))
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.min_value = 0
	volume.max_value = 100
	volume.value = 70
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value/100.0,0.0001)))
		_save_options(value))
	box.add_child(volume)
	_button("toggle fullscreen",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_options(volume.value),box)
	var preview := OptionButton.new()
	preview.add_item("WEATHER: NATURAL CYCLE")
	for weather in Weather.WEATHER_NAMES:
		preview.add_item(weather.to_upper())
	preview.item_selected.connect(func(index: int): weather_override = index-1)
	box.add_child(preview)
	_button("back",func(): _close_options(),box)
	options.hide()

func _process(delta: float) -> void:
	if not menu_active:
		return
	elapsed += delta
	_update_weather(delta)

func _update_weather(delta: float) -> void:
	weather_elapsed += delta
	while weather_elapsed >= Weather.WEATHER_DURATIONS[weather_index]:
		weather_elapsed -= Weather.WEATHER_DURATIONS[weather_index]
		weather_index = (weather_index+1)%Weather.WEATHER_NAMES.size()
	var index := weather_index if weather_override < 0 else weather_override
	rain_strength = move_toward(rain_strength,Weather.RAIN_LEVELS[index],delta/12.0)
	cloud_cover = move_toward(cloud_cover,Weather.CLOUD_LEVELS[index],delta/30.0)
	var angle := fposmod(elapsed,Weather.FULL_CYCLE)/Weather.FULL_CYCLE*TAU
	var direction := Vector3(cos(angle),sin(angle),0.25).normalized()
	var daylight := smoothstep(-0.08,0.20,direction.y)
	sun.look_at(-direction,Vector3.UP)
	sun.light_energy = maxf(0.0,direction.y)*1.3*(1-cloud_cover*0.65)
	sun.light_color = Color("ffc18b").lerp(Color("fff0cd"),smoothstep(0,0.5,direction.y))
	var env := world.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("748bb9").lerp(Color("dad7c0"),daylight)
	env.ambient_light_energy = lerpf(0.35,0.8,daylight)
	env.fog_light_color = Color("25384d").lerp(Color("b5b9ac"),daylight)
	env.fog_density = lerpf(0.0018,0.0045,rain_strength)
	sky_material.set_shader_parameter("sun_direction",direction)
	sky_material.set_shader_parameter("daylight",daylight)
	sky_material.set_shader_parameter("cloud_cover",cloud_cover)
	sky_material.set_shader_parameter("cycle_time",elapsed)
	scenery_material.set_shader_parameter("daylight",daylight)
	scenery_material.set_shader_parameter("rain_strength",rain_strength)
	scenery_material.set_shader_parameter("haze_color",env.fog_light_color)
	var count := maxi(1,roundi(1600*Weather.RAIN_LEVELS[index]))
	if rain.amount != count: rain.amount = count
	rain.emitting = rain_strength > 0.03
	rain.mesh.material.albedo_color.a = rain_strength*0.5
	flash = move_toward(flash,0,delta*3.5)
	if thunder_delay >= 0:
		thunder_delay -= delta
		if thunder_delay < 0: ambience.thunder()
	if index == 5 and rain_strength > 0.7:
		storm_wait -= delta
		if storm_wait <= 0:
			flash = 1.1
			thunder_delay = randf_range(1.5,3.5)
			storm_wait = randf_range(16,32)
	else:
		storm_wait = 8
	lightning.light_energy = flash
	landscape.animate(elapsed,daylight,rain_strength)
	camera.position.x = 17+sin(elapsed*0.025)*7
	camera.look_at(Vector3(-5,31,-80))
	sky_material.set_shader_parameter("lightning",flash)
	ambience.update_mix(delta,rain_strength,daylight,false)
	var minutes := int(fposmod(6+elapsed*24/Weather.FULL_CYCLE,24)*60)
	weather_label.text = "%02d:%02d  ·  %s" % [minutes/60,minutes%60,Weather.WEATHER_NAMES[index].to_upper()]

func _request_new() -> void:
	if is_instance_valid(garden) or FileAccess.file_exists(SAVE_PATH):
		new_dialog.popup_centered()
	else:
		_begin_garden(true)

func _begin_garden(fresh: bool) -> void:
	if fresh:
		coins=500
		purchases.clear()
	menu_buttons.hide()
	loading_label.text = "OPENING YOUR GARDEN…"
	await get_tree().process_frame
	await get_tree().process_frame
	if fresh and is_instance_valid(garden):
		remove_child(garden)
		garden.free()
	if not is_instance_valid(garden):
		garden = load("res://main.tscn").instantiate()
		add_child(garden)
		for child in garden.get_children():
			if child is WorldEnvironment: garden.camera.environment = child.environment
		if not fresh: _restore_garden()
	menu_active = false
	stage.hide()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	interface.hide()
	ambience.update_mix(0,rain_strength,1,true)
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false):
		if layer!=garden.hedgehog_intro.ui:layer.show()
	garden.process_mode = Node.PROCESS_MODE_INHERIT
	garden.camera.make_current()
	garden._set_guide(false)
	_save_garden()
	loading_label.text = ""
	menu_buttons.show()

func open_menu() -> void:
	_save_garden()
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stream_paused = true
	garden.process_mode = Node.PROCESS_MODE_DISABLED
	garden.hide()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.hide()
	stage.show()
	stage.process_mode = Node.PROCESS_MODE_INHERIT
	interface.show()
	camera.make_current()
	menu_active = true
	_focus_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _save_garden() -> bool:
	if not is_instance_valid(garden): return true
	var terrain := []
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x): terrain.append(garden.get_terrain(Vector2i(x,z)))
	var crops := []
	for cell in garden.crops:
		var crop: Dictionary = garden.crops[cell]
		crops.append({"x":cell.x,"z":cell.y,"age":crop.age,"watered":crop.watered})
	var data := {"version":1,"terrain":terrain,"crops":crops,"harvested":garden.harvested,
		"player":[garden.player.cell.x,garden.player.cell.y],"player_position":[garden.player.position.x,garden.player.position.z],"elapsed":garden.valley_cycle.elapsed,
		"weather":garden.valley_cycle.weather_index,"weather_elapsed":garden.valley_cycle.weather_elapsed,
		"deformation":garden.heightfield.save_deformation(),"wildlife":garden.wildlife.save_data(),"hedgehog_intro":garden.hedgehog_intro.save_data(),"wetness":garden.valley_cycle.wetness,"watered":_saved_watered(),"coins":coins,"purchases":purchases}
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	return file.get_error()==OK

func _saved_watered() -> Array:
	var values := []
	for cell in garden.watered_cells:
		values.append([cell.x,cell.y,garden.watered_cells[cell]])
	return values

func _restore_garden() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or data.get("version",0) != 1: return
	var terrain: Array = data.get("terrain",[])
	if terrain.size() != garden.grid_size.x*garden.grid_size.y: return
	for z in range(garden.grid_size.y):
		for x in range(garden.grid_size.x): garden.set_terrain(Vector2i(x,z),clampi(int(terrain[z*garden.grid_size.x+x]),0,7))
	garden.heightfield.restore_deformation(data.get("deformation",{}))
	for saved in data.get("crops",[]):
		var cell := Vector2i(int(saved.x),int(saved.z))
		if not garden.contains_cell(cell) or garden.blocked_cells.has(cell): continue
		var plant: Node3D = garden._make_plant(cell)
		garden.crops[cell] = {"node":plant,"age":float(saved.age),"watered":bool(saved.watered)}
		if bool(saved.watered): garden._add_water_ring(plant)
	garden.harvested = int(data.get("harvested",0))
	var cell := Vector2i(int(data.player[0]),int(data.player[1]))
	if garden.contains_cell(cell) and not garden.blocked_cells.has(cell):
		garden.player.cell = cell
		garden.player.target_cell = cell
		garden.player.position = garden.cell_center(cell)
	var free_position = data.get("player_position",[])
	if free_position is Array and free_position.size()==2:
		garden.player.restore_position(Vector3(float(free_position[0]),0,float(free_position[1])))
	garden.valley_cycle.elapsed = float(data.get("elapsed",0))
	garden.valley_cycle.weather_index = clampi(int(data.get("weather",0)),0,6)
	garden.valley_cycle.weather_elapsed = float(data.get("weather_elapsed",0))
	garden.valley_cycle.wetness = float(data.get("wetness",0))
	for value in data.get("watered",[]):
		var wet_cell := Vector2i(int(value[0]),int(value[1]))
		if garden.contains_cell(wet_cell):
			garden.watered_cells[wet_cell]=clampf(float(value[2]),0,1)
			garden.watered_image.set_pixel(wet_cell.x,wet_cell.y,Color(garden.watered_cells[wet_cell],0,0))
	garden.watered_texture.update(garden.watered_image)
	coins=maxi(0,int(data.get("coins",500)))
	garden.wildlife.suppress_events=true
	garden.wildlife.restore(data.get("wildlife",{}))
	garden.hedgehog_intro.restore(data.get("hedgehog_intro",{}))
	purchases.clear()
	for record in data.get("purchases",[]):
		if not record is Dictionary or not record.has_all(["id","x","z"]): continue
		if preload("res://village_stock.gd").item(str(record.id)).is_empty(): continue
		if not garden.contains_cell(Vector2i(int(record.x),int(record.z))): continue
		purchases.append(record)
		preload("res://village_stock.gd").deliver(garden,record)
	garden.wildlife.suppress_events=false
	garden.valley_cycle._update_visuals()
	garden._refresh_ui()

func _save_options(volume: float) -> void:
	var file := FileAccess.open(OPTIONS_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"volume":volume,"fullscreen":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN}))

func _load_options() -> void:
	var volume := 70.0
	if FileAccess.file_exists(OPTIONS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(OPTIONS_PATH))
		if data is Dictionary:
			volume = clampf(float(data.get("volume",70)),0,100)
			if data.get("fullscreen",false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume/100,0.0001)))
	options.find_child("Volume",true,false).set_value_no_signal(volume)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_and_quit()

func _focus_menu() -> void:
	if menu_active:
		ControllerInput.focus_first.call_deferred(options if options.visible else menu_buttons)

func _close_options() -> void:
	options.hide()
	menu_buttons.show()
	heading.show()
	_focus_menu()

func _unhandled_input(event: InputEvent) -> void:
	if menu_active and event.is_action_pressed("ui_cancel") and options.visible:
		_close_options()
		get_viewport().set_input_as_handled()

func save_and_quit() -> void:
	if not _save_garden():
		if is_instance_valid(garden):
			garden.message="Could not save your garden. Please try again."
			garden._refresh_ui()
		else: loading_label.text="COULD NOT SAVE. PLEASE TRY AGAIN."
		return
	get_tree().quit()

func open_village() -> void:
	if not is_instance_valid(garden) or is_instance_valid(village): return
	garden._set_guide(true)
	garden.ambience.update_mix(0,0,0,true)
	for audio in garden.find_children("*","AudioStreamPlayer3D",true,false): audio.stream_paused=true
	garden.process_mode=Node.PROCESS_MODE_DISABLED
	garden.hide()
	for layer in garden.find_children("*","CanvasLayer",true,false): layer.hide()
	village=preload("res://village.tscn").instantiate()
	add_child(village)
	village.activate(self)

func return_from_village() -> void:
	if not is_instance_valid(village): return
	garden.valley_cycle.active_ambience=null
	village.free()
	village=null
	garden.show()
	for layer in garden.find_children("*","CanvasLayer",true,false):
		if layer!=garden.hedgehog_intro.ui:layer.show()
	garden.process_mode=Node.PROCESS_MODE_INHERIT
	garden.camera.make_current()
	garden._set_guide(false)
	_save_garden()

func purchase_village_item(id: String) -> String:
	var item: Dictionary=preload("res://village_stock.gd").item(id)
	if item.is_empty(): return "That item is unavailable."
	if id=="hedgehog" and garden.wildlife.grass_ratio()<0.01:return "Hedgehogs need at least 1% grass before visiting your garden."
	if coins<int(item.price): return "There are not enough coins in your purse."
	var cell: Vector2i=preload("res://village_stock.gd").find_space(garden,id)
	if cell.x<0: return "Your garden needs more clear ground for this delivery."
	var record: Dictionary={"id":id,"x":cell.x,"z":cell.y}
	coins-=int(item.price)
	purchases.append(record)
	if not _save_garden():
		coins+=int(item.price)
		purchases.pop_back()
		return "The purchase could not be saved. No coins were spent."
	preload("res://village_stock.gd").deliver(garden,record)
	_save_garden()
	return "%s delivered to your garden.\n%d coins remaining."%[item.name,coins]

```

## main_menu.tscn

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main_menu.gd" id="1"]

[node name="Cwtch" type="Node3D"]
script = ExtResource("1")

```

## meadow_grass.gd

```gd
extends Node3D
## Batched, deterministic grass. Terrain textures keep it in sync with tools and saves.
var garden: Node3D
var exclusions: Image
var exclusion_texture: ImageTexture
var refresh_time := 0.0
const TUFTS_PER_PATCH := 320

func build(world: Node3D) -> void:
	garden = world
	name = "MeadowGrass"
	exclusions = Image.create(world.grid_size.x, world.grid_size.y, false, Image.FORMAT_R8)
	exclusion_texture = ImageTexture.create_from_image(exclusions)
	_refresh_exclusions()
	var material := ShaderMaterial.new()
	material.shader = preload("res://meadow_grass.gdshader")
	material.set_shader_parameter("bed_heights",world.heightfield.height_texture)
	material.set_shader_parameter("original_heights",world.heightfield.original_texture)
	material.set_shader_parameter("height_samples",Vector2(world.heightfield.samples))
	material.set_shader_parameter("terrain_ids", world.terrain_texture)
	material.set_shader_parameter("exclusions", exclusion_texture)
	material.set_shader_parameter("grid_min", world.grid_min)
	material.set_shader_parameter("grid_size", Vector2(world.grid_size))
	material.set_shader_parameter("micro_size", world.MICRO_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891
	var blade_mesh := _tuft()
	# One batch per 4 m patch allows Godot to cull distant patches independently.
	for z in range(-5, 5):
		for x in range(-5, 5):
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.use_colors = true
			batch.mesh = blade_mesh
			batch.instance_count = TUFTS_PER_PATCH
			for i in range(batch.instance_count):
				var point := Vector3(x * 4.0 + rng.randf_range(0.12, 3.88), 0.008, z * 4.0 + rng.randf_range(0.12, 3.88))
				var scale_factor := rng.randf_range(0.65, 1.3)
				var ground_point := Vector2(point.x, point.z)
				point.y += world.heightfield.height_at(ground_point) if world.contains_cell(world.local_to_cell(point)) else world.background_meadow.height_at(ground_point)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_factor)
				batch.set_instance_transform(i, Transform3D(basis, point))
				batch.set_instance_color(i, Color(rng.randf_range(0.8, 1.13), rng.randf_range(0.9, 1.1), 0.9))
			var patch := MultiMeshInstance3D.new()
			patch.multimesh = batch
			patch.material_override = material
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			patch.extra_cull_margin = 0.6
			patch.visibility_range_end = 32.0
			add_child(patch)

func _tuft() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var angle := float(i) * 2.39996
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.017
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.035
		var base := lean * 0.3
		var mid := base + lean + Vector3.UP * 0.10
		var tip := base + lean * 2.2 + Vector3.UP * (0.17 + float(i) * 0.014)
		var vertices := [base-side, base+side, mid-side*0.55, base+side, mid+side*0.55, mid-side*0.55, mid-side*0.55, mid+side*0.55, tip]
		for vertex: Vector3 in vertices:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(0.5, vertex.y / 0.22))
			surface.add_vertex(vertex)
	return surface.commit()

func _refresh_exclusions() -> void:
	exclusions.fill(Color.BLACK)
	for cell: Vector2i in garden.blocked_cells:
		if garden.contains_cell(cell):
			exclusions.set_pixel(cell.x, cell.y, Color.WHITE)
	for cell: Vector2i in garden.crops:
		if garden.contains_cell(cell):
			exclusions.set_pixel(cell.x, cell.y, Color.WHITE)
	exclusion_texture.update(exclusions)

func _process(delta: float) -> void:
	refresh_time += delta
	if refresh_time >= 0.5:
		refresh_time = 0.0
		_refresh_exclusions()

```

## meadow_grass.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bed_heights : filter_linear, repeat_disable;
uniform sampler2D original_heights : filter_linear, repeat_disable;
uniform vec2 height_samples;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2D exclusions : filter_nearest, repeat_disable;
uniform vec2 grid_min;
uniform vec2 grid_size;
uniform bool scenery_only = false;
uniform float micro_size = 0.6666667;
varying float present;
varying float tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = (root.xz - grid_min) / micro_size;
	bool inside = !scenery_only && all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, grid_size));
	vec2 map_uv = (floor(cell) + 0.5) / grid_size;
	float kind = floor(texture(terrain_ids, map_uv).r * 255.0 + 0.5);
	present = inside ? ((kind == 2.0 || kind == 3.0) ? 1.0 : 0.0) : 1.0;
	if (inside && texture(exclusions, map_uv).r > 0.5) { present = 0.0; }
	float height_scale = inside ? (kind == 3.0 ? 1.9 : 0.75) : 1.45;
	float tip_weight = UV.y * UV.y;
	VERTEX.y *= height_scale;
	VERTEX.x += sin(TIME * 1.4 + root.x * 0.7 + root.z * 0.4) * 0.035 * tip_weight;
	VERTEX.z += sin(TIME * 1.0 + root.z * 0.8) * 0.022 * tip_weight;
	if (inside) {
	 vec2 height_uv=((root.xz-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
	 float shift=texture(bed_heights,height_uv).r-texture(original_heights,height_uv).r;
	 VERTEX.y+=shift/max(length(MODEL_MATRIX[1].xyz),0.001);
	}
	VERTEX *= present;
	tint = sin(root.x * 12.3 + root.z * 7.1) * 0.5 + 0.5;
}

void fragment() {
	if (present < 0.5) { discard; }
	vec3 base = mix(vec3(0.15, 0.22, 0.075), vec3(0.28, 0.34, 0.12), tint);
	ALBEDO = mix(base * 0.7, base * 1.3, clamp(UV.y, 0.0, 1.0)) * COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}

```

## menu_illustration.gd

```gd
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

```

## menu_illustration.gdshader

```gdshader
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
void fragment() {
 vec3 tint = mix(vec3(0.22,0.35,0.52),vec3(1.0),daylight);
 ALBEDO = COLOR.rgb * tint * (1.0-rain_strength*0.16);
}

```

## menu_mountain.gdshader

```gdshader
shader_type spatial;
uniform float rain_strength = 0.0;
void fragment() {
 ALBEDO = COLOR.rgb * (1.0-rain_strength*0.14);
 ROUGHNESS = mix(0.93,0.65,rain_strength);
}

```

## menu_paper_sky.gdshader

```gdshader
shader_type sky;
uniform vec3 sun_direction = vec3(0.5,0.5,0.0);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.15;
uniform float cycle_time = 0.0;
uniform float lightning = 0.0;
void sky() {
 float sunset=(1.0-smoothstep(0.0,0.32,abs(sun_direction.y)))*daylight;
 vec3 paper=mix(vec3(0.975,0.983,0.98),vec3(0.97,0.90,0.81),sunset*0.42);
 paper=mix(paper,vec3(0.78,0.84,0.85),cloud_cover*0.25);
 vec3 night=mix(vec3(0.025,0.045,0.073),vec3(0.065,0.105,0.15),clamp(EYEDIR.y+0.5,0.0,1.0));
 COLOR=mix(mix(night,paper,daylight),vec3(0.85,0.91,0.98),lightning*0.35);
}

```

## menu_stream.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
varying vec3 point;
void vertex() { point = VERTEX; }
void fragment() {
 float ripple = sin(point.z*3.0 + TIME*1.3 + sin(point.x*6.0)) * sin(point.x*10.0-TIME*0.8);
 ALBEDO = mix(vec3(0.10,0.22,0.23), vec3(0.32,0.42,0.40), ripple*0.5+0.5);
 NORMAL = normalize(NORMAL + vec3(ripple*0.08,0.0,cos(point.z*4.0+TIME)*0.12));
 ROUGHNESS = 0.26;
 SPECULAR = 0.7;
}

```

## menu_valley_3d.gd

```gd
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
	var mountain := _finish(builder,"SnowcapMountain3D")
	preload("res://scenery_grass.gd").plant(self,mountain.mesh,"MenuHillsideGrass",0.5,22.0)

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

```

## model_weather.gd

```gd
extends Node
## Per-scene material copies preserve imported meshes and animation resources.
var scene: Node
var materials: Dictionary = {}
var seen: Dictionary = {}
var scan_time := 0.0
var wetness := 0.0

func setup(root: Node) -> void:
 scene=root
 _scan(scene)

func _channel(index: int) -> Vector4:
 return [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(0.333,0.333,0.333,0)][clampi(index,0,4)]

func _convert(source: Material) -> Material:
 if not source is StandardMaterial3D: return source
 if source.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED: return source
 if source.emission_enabled or source.uv1_triplanar or source.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED: return source
 if source.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]: return source
 var key := source.get_instance_id()
 if materials.has(key): return materials[key]
 var result := ShaderMaterial.new()
 result.shader=preload("res://model_weather.gdshader")
 result.set_shader_parameter("base_color",source.albedo_color)
 result.set_shader_parameter("vertex_tint",source.vertex_color_use_as_albedo)
 result.set_shader_parameter("double_sided",source.cull_mode==BaseMaterial3D.CULL_DISABLED)
 result.set_shader_parameter("cutoff",source.alpha_scissor_threshold if source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.001)
 result.set_shader_parameter("roughness_value",source.roughness)
 result.set_shader_parameter("metal_value",source.metallic)
 result.set_shader_parameter("rough_channel",_channel(source.roughness_texture_channel))
 result.set_shader_parameter("metal_channel",_channel(source.metallic_texture_channel))
 result.set_shader_parameter("normal_strength",source.normal_scale)
 result.set_shader_parameter("has_ao",source.ao_enabled and source.ao_texture!=null)
 if source.ao_texture!=null:result.set_shader_parameter("ao_map",source.ao_texture)
 result.set_shader_parameter("ao_channel",_channel(source.ao_texture_channel))
 result.set_shader_parameter("uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y))
 result.set_shader_parameter("uv_offset",Vector2(source.uv1_offset.x,source.uv1_offset.y))
 for pair in [["albedo",source.albedo_texture],["normal",source.normal_texture if source.normal_enabled else null],["rough",source.roughness_texture],["metal",source.metallic_texture]]:
  result.set_shader_parameter("has_"+pair[0],pair[1]!=null)
  if pair[1]!=null:result.set_shader_parameter(pair[0]+"_map",pair[1])
 materials[key]=result
 return result

func _scan(node: Node) -> void:
 if not seen.has(node.get_instance_id()):
  if node is MeshInstance3D and node.mesh:
   if node.material_override:
    node.material_override=_convert(node.material_override)
   else:
    for i in range(node.mesh.get_surface_count()):
     node.set_surface_override_material(i,_convert(node.get_active_material(i)))
  elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
   if node.material_override:node.material_override=_convert(node.material_override)
   else:
    var mesh: Mesh = node.multimesh.mesh.duplicate()
    for i in range(mesh.get_surface_count()):mesh.surface_set_material(i,_convert(mesh.surface_get_material(i)))
    node.multimesh.mesh=mesh
  seen[node.get_instance_id()]=true
 for child in node.get_children(): _scan(child)

func _process(delta: float) -> void:
 if not is_instance_valid(scene):return
 scan_time+=delta
 if scan_time>=2.0:
  scan_time=0.0
  _scan(scene)
 var rain: float = scene.valley_cycle.rain_strength if scene.get("valley_cycle")!=null else scene.rain_strength
 wetness=move_toward(wetness,rain,delta/(25.0 if rain>wetness else 80.0))
 for material: ShaderMaterial in materials.values():material.set_shader_parameter("wetness",wetness)

```

## model_weather.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_rough = false;
uniform bool has_metal = false;
uniform bool has_ao = false;
uniform sampler2D ao_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ao_channel = vec4(1,0,0,0);
uniform bool vertex_tint = false;
uniform bool double_sided = false;
uniform float cutoff = 0.001;
uniform float normal_strength = 1.0;
uniform float roughness_value = 1.0;
uniform float metal_value = 0.0;
uniform float wetness = 0.0;
uniform vec4 rough_channel = vec4(0,1,0,0);
uniform vec4 metal_channel = vec4(0,0,1,0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
void fragment(){
 if(!double_sided && !FRONT_FACING){discard;}
 vec2 uv=UV*uv_scale+uv_offset;
 vec4 paint=base_color;
 if(has_albedo){paint*=texture(albedo_map,uv);}
 if(vertex_tint){paint*=COLOR;}
 float metal=metal_value*(has_metal ? dot(texture(metal_map,uv),metal_channel) : 1.0);
 float dry=roughness_value*(has_rough ? dot(texture(rough_map,uv),rough_channel) : 1.0);
 ALBEDO=paint.rgb*(1.0-wetness*0.17*(1.0-metal));
 ALPHA=paint.a;
 ALPHA_SCISSOR_THRESHOLD=cutoff;
 METALLIC=metal;
 ROUGHNESS=mix(max(dry,mix(0.72,0.27,metal)),mix(0.48,0.22,metal),wetness*0.65);
 SPECULAR=mix(0.22,0.36,wetness);
 if(has_ao){AO=dot(texture(ao_map,uv),ao_channel);}
 if(!FRONT_FACING){NORMAL=-NORMAL;}
 if(has_normal){NORMAL_MAP=texture(normal_map,uv).rgb;NORMAL_MAP_DEPTH=normal_strength;}
}

```

## optimize_tools.py

```py
import bpy
from pathlib import Path
root=Path(__file__).resolve().parent/'assets'/'tools'
for name in ['hoe','seeds','water']:
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(root/(name+'_source.glb')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 total=sum(len(o.data.polygons) for o in meshes)
 for obj in meshes:
  bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('Tool detail','DECIMATE')
  modifier.ratio=min(1.0,18000.0/total)
  bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.export_scene.gltf(filepath=str(root/(name+'.glb')),export_format='GLB',export_animations=False)
 print('TOOL',name,total,'to',sum(len(o.data.polygons) for o in meshes),flush=True)

```

## optimize_trees.py

```py
import bpy
from pathlib import Path
root=Path(__file__).resolve().parent / 'assets' / 'trees'
for name in ['ash','birch']:
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(root/(name+'.glb')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 total=sum(len(o.data.polygons) for o in meshes)
 ratio=min(1.0,10000.0/total)
 for obj in meshes:
  bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('Forest detail','DECIMATE')
  modifier.ratio=ratio
  bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.export_scene.gltf(filepath=str(root/(name+'_forest.glb')),export_format='GLB',export_animations=False)
 print('TREE OPTIMIZED',name,total,'to',sum(len(o.data.polygons) for o in meshes),flush=True)

```

## peacock_npc.gd

```gd
extends "res://wandering_npc.gd"
var stride := 0.0
func _create_visual() -> void:
 collision_radius=0.27
 collision_height=0.85
 move_speed=0.34
 visual=load("res://assets/animals/Peacock/Peacock.fbx").instantiate()
 var box: AABB=preload("res://floating_tool.gd").bounds(visual)
 var scale_factor:=0.85/box.size.y
 visual.scale*=scale_factor
 visual.position-=Vector3(box.get_center().x,box.position.y,box.get_center().z)*scale_factor
 add_child(visual)
 animation_player=AnimationPlayer.new()
 add_child(animation_player)
 set_meta("animal_id","peacock")
func advance(delta: float) -> void:
 super.advance(delta)
 if garden.guide.visible:return
 stride+=delta
 visual.rotation.z=sin(stride*8)*0.025*motion_ratio

```

## Play Aberglen.cmd

```cmd
@echo off
setlocal
set "APPDATA=%~dp0runtime\data"
start "CWTCH" "%~dp0runtime\Godot_v4.6.2-stable_win64.exe" --path "%~dp0." --log-file "%~dp0play.log"

```

## pom_material.gd

```gd
extends RefCounted

# For meshes with regular UVs and tangents. All maps must be aligned.
static func create_standard(albedo: Texture2D, normal: Texture2D,
		height: Texture2D, roughness: Texture2D = null) -> StandardMaterial3D:
	assert(albedo != null and normal != null and height != null)
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.8
	material.heightmap_enabled = true
	material.heightmap_deep_parallax = true
	material.heightmap_texture = height
	material.heightmap_scale = 0.8
	material.heightmap_min_layers = 12
	material.heightmap_max_layers = 48
	material.heightmap_flip_texture = false
	material.uv1_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.roughness = 0.95
	if roughness != null:
		material.roughness_texture = roughness
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return material

# Packed linear height data: R dirt, G grass, B stone, A path.
# This feeds our custom terrain shader so the terrain types still blend.
static func generate_heights(size: int = 256) -> ImageTexture:
	var maps: Array[Image] = []
	for i in range(4):
		var noise := FastNoiseLite.new()
		noise.seed = 1826 + i * 71
		noise.frequency = [0.065, 0.12, 0.035, 0.09][i]
		noise.fractal_octaves = 3
		maps.append(noise.get_seamless_image(size, size))
	var packed := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dirt := maps[0].get_pixel(x, y).r
			var grass := pow(maps[1].get_pixel(x, y).r, 1.5)
			var stone := smoothstep(0.2, 0.65, maps[2].get_pixel(x, y).r)
			var path := maps[3].get_pixel(x, y).r
			packed.set_pixel(x, y, Color(dirt, grass, stone, path))
	packed.generate_mipmaps()
	return ImageTexture.create_from_image(packed)

```

## procedural_animal.gd

```gd
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

```

## project.godot

```godot
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="CWTCH"
config/icon="res://assets/branding/cwtch.png"
config/windows_native_icon="res://assets/branding/cwtch.ico"
run/main_scene="res://main_menu.tscn"
config/features=PackedStringArray("4.6")

[autoload]

ControllerInput="*res://controller_input.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.12, 0.15, 0.17, 1)

```

## scenery_grass.gd

```gd
extends RefCounted
## Scatter on actual mesh triangles, never on an approximate hillside height.
static func plant(parent: Node3D, terrain: Mesh, label: String, density: float, max_height: float) -> void:
 var random:=RandomNumberGenerator.new()
 random.seed=1896
 var groups: Dictionary={}
 var arrays:=terrain.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 var count:=indices.size() if not indices.is_empty() else vertices.size()
 for i in range(0,count,3):
  var a:=vertices[indices[i] if not indices.is_empty() else i]
  var b:=vertices[indices[i+1] if not indices.is_empty() else i+1]
  var c:=vertices[indices[i+2] if not indices.is_empty() else i+2]
  var cross: Vector3=(b-a).cross(c-a)
  var area:=cross.length()*0.5
  if area<0.001:continue
  var normal:=cross.normalized()
  if normal.y<0:normal=-normal
  if normal.y<0.78 or (a.y+b.y+c.y)/3.0>max_height:continue
  var expected:=area*density
  var amount:=mini(100,floori(expected)+(1 if random.randf()<fposmod(expected,1.0) else 0))
  for j in range(amount):
   var u:=sqrt(random.randf())
   var v:=random.randf()
   var point: Vector3=(1.0-u)*a+u*(1.0-v)*b+u*v*c+Vector3.UP*0.01
   var key:=Vector2i(floori(point.x/16),floori(point.z/16))
   if not groups.has(key):groups[key]=[]
   var scale_factor:=random.randf_range(1.3,2.7)
   groups[key].append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*scale_factor),point))
 var generator:=preload("res://meadow_grass.gd").new()
 var tuft:=generator._tuft()
 generator.free()
 var material:=ShaderMaterial.new()
 material.shader=preload("res://meadow_grass.gdshader")
 material.set_shader_parameter("scenery_only",true)
 material.set_shader_parameter("grid_size",Vector2(36,36))
 for key: Vector2i in groups:
  var batch:=MultiMesh.new()
  batch.transform_format=MultiMesh.TRANSFORM_3D
  batch.mesh=tuft
  batch.instance_count=groups[key].size()
  for i in range(batch.instance_count):batch.set_instance_transform(i,groups[key][i])
  var node:=MultiMeshInstance3D.new()
  node.name=label+"_%d_%d"%[key.x,key.y]
  node.multimesh=batch
  node.material_override=material
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.extra_cull_margin=0.8
  node.visibility_range_end=220.0
  parent.add_child(node)


```

## selection_target.gd

```gd
extends Area3D
## Attach to a model root. Layer 2 is selection-only, never player collision.
var subject: Node3D
var label := "Object"
var footprint := Vector2.ONE
var crop_cell := Vector2i(-1, -1)

static func attach(parent: Node3D, title: String, size: Vector3, cell := Vector2i(-1, -1)) -> Area3D:
	var script = load("res://selection_target.gd")
	var target = script.new()
	target.subject = parent
	target.label = title
	target.footprint = Vector2(size.x, size.z)
	target.crop_cell = cell
	target.collision_layer = 2
	target.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = size.y * 0.5
	target.add_child(collider)
	parent.add_child(target)
	return target

func selection_size() -> Vector2:
	var world_scale := subject.global_basis.get_scale()
	return footprint * Vector2(absf(world_scale.x), absf(world_scale.z)) + Vector2.ONE * 0.16

```

## stone_wall.gdshader

```gdshader
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stone_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_ao : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float grain = sin(world_point.x * 61.0 + sin(world_point.z * 37.0))
		* sin(world_point.y * 53.0 + world_point.z * 29.0);
	float patch = sin(world_point.x * 4.1 + world_point.z * 3.5) * sin(world_point.z * 7.0 + world_point.y * 4.0);
	vec3 stone = texture(stone_color, UV).rgb * mix(0.85, 1.08, COLOR.r);
	float moss = smoothstep(0.05, 0.65, patch + max(world_normal.y, 0.0) * 0.3);
	ALBEDO = mix(stone, stone * vec3(0.72, 0.88, 0.48), moss * 0.5) * (0.95 + grain * 0.05);
	ROUGHNESS = texture(stone_roughness, UV).r;
	AO = mix(1.0, texture(stone_ao, UV).r, 0.65);
	NORMAL_MAP = texture(stone_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.65;
}

```

## tardis_event.gd

```gd
extends Node3D
## A stationary materialisation just beyond the north boundary, doors facing south.
const ASSET := "res://assets/easter_egg/Tardis/"
const NORTH_OFFSET := 2.4
var garden: Node3D
var state := "away"
var visual: Node3D
var animation: AnimationPlayer
var material: ShaderMaterial
var audio: AudioStreamPlayer3D
var lamp: OmniLight3D
var body: StaticBody3D
var elapsed := 0.0
var duration := 1.0
var automatic := false
var stay := 0.0

func setup(world: Node3D) -> void:
 garden=world
 name="TardisEvent"
 audio=AudioStreamPlayer3D.new()
 audio.volume_db=-12.0
 audio.unit_size=12.0
 audio.max_distance=60.0
 add_child(audio)

func _load_model() -> void:
 if is_instance_valid(visual):return
 visual=load(ASSET+"source/For sketchfab.fbx").instantiate()
 add_child(visual)
 # The source is 3.114 m high, with its origin 5 cm below its feet.
 visual.scale=Vector3.ONE*(2.7/3.11391)
 visual.position.y=0.05*visual.scale.x
 material=ShaderMaterial.new()
 material.shader=preload("res://tardis_material.gdshader")
 var prefix: String=ASSET+"textures/Tardis_lp_RandomColor_1_"
 for pair in [["color_map","Diffuse"],["normal_map","Normal"],["glow_map","Emissive"],["gloss_map","Glossiness"]]:
  material.set_shader_parameter(pair[0],load(prefix+pair[1]+".png"))
 for child in visual.find_children("*","",true,false):
  if child is MeshInstance3D:child.material_override=material
  if child is AnimationPlayer:
   animation=child
   animation.stop()
   animation.active=false
 lamp=OmniLight3D.new()
 lamp.position.y=2.6
 lamp.light_color=Color("b7eaff")
 lamp.omni_range=5.0
 add_child(lamp)
 body=StaticBody3D.new()
 body.collision_layer=4
 body.collision_mask=0
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(1.4,2.7,1.4)
 shape.shape=box
 shape.position.y=1.35
 body.add_child(shape)
 add_child(body)
 body.collision_layer=0
 hide()

func landing_point() -> Vector3:
 var point:=Vector3(0,0,garden.grid_min.y-NORTH_OFFSET)
 for x in [-0.7,0.0,0.7]:
  for z in [-0.7,0.0,0.7]:
   point.y=maxf(point.y,garden.background_meadow.height_at(Vector2(point.x+x,point.z+z)))
 return point

func land(auto_leave: bool=false) -> String:
 if state!="away":return "The TARDIS is already "+state+"."
 _load_model()
 position=landing_point()
 # The source's door and telephone notice face +Z (south) in its rest pose.
 rotation=Vector3.ZERO
 automatic=auto_leave
 state="landing"
 body.collision_layer=4
 show()
 _start_sound("Landing")
 material.set_shader_parameter("presence",0.0)
 garden.message="A strange blue box is arriving beyond the north edge."
 garden._refresh_ui()
 return "Landing just north of the garden, facing south."

func _start_sound(filename: String) -> void:
 elapsed=0.0
 audio.stream=load(ASSET+filename+".mp3")
 duration=audio.stream.get_length()
 audio.play()

func takeoff() -> String:
 if state!="landed":return "Takeoff requires a landed TARDIS (currently "+state+")."
 state="taking off"
 _start_sound("Takeoff")
 return "The TARDIS is taking off."

func _process(delta: float) -> void:
 if state=="away":return
 var paused: bool=garden.guide.visible
 audio.stream_paused=paused
 if paused:return
 if state=="landed":
  lamp.light_energy=0.25
  material.set_shader_parameter("lamp_energy",0.35)
  if automatic:
   stay-=delta
   if stay<=0.0:takeoff()
  return
 elapsed=minf(elapsed+delta,duration)
 var progress:=elapsed/duration
 var arriving: bool=state=="landing"
 var amount:=progress if arriving else 1.0-progress
 var pulse:=0.5+0.5*sin(progress*TAU*7.0)
 var presence:=clampf(amount+sin(progress*PI)*0.23*(pulse-0.5),0.0,1.0)
 material.set_shader_parameter("presence",presence)
 material.set_shader_parameter("lamp_energy",0.5+pulse*2.0)
 lamp.light_energy=presence*(0.6+pulse*1.5)
 if elapsed>=duration:
  if arriving:
   state="landed"
   stay=20.0
   material.set_shader_parameter("presence",1.0)
  else:
   state="away"
   hide()
   body.collision_layer=0
   audio.stop()

```

## tardis_material.gdshader

```gdshader
shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D glow_map : source_color, filter_linear_mipmap;
uniform sampler2D gloss_map : filter_linear_mipmap;
uniform float presence : hint_range(0.0,1.0) = 1.0;
uniform float lamp_energy = 0.3;
void fragment() {
 float noise = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
 if (presence < 0.001 || noise > presence) { discard; }
 ALBEDO = texture(color_map,UV).rgb;
 NORMAL_MAP = texture(normal_map,UV).rgb;
 ROUGHNESS = clamp(1.0-texture(gloss_map,UV).r,0.45,0.95);
 METALLIC = 0.0;
 SPECULAR = 0.25;
 EMISSION = texture(glow_map,UV).rgb*lamp_energy;
}

```

## terrain.gdshader

```gdshader
shader_type spatial;
uniform sampler2D watered_tiles : filter_linear, repeat_disable;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray detail_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_size = vec2(9.0);
uniform vec2 grid_min = vec2(-3.0);
uniform float micro_size = 0.666666667;
uniform mat4 world_to_grid;
uniform float repeats_per_metre = 1.0;
uniform float relief_metres = 0.012;
uniform bool pom_enabled = true;
uniform bool orthographic_view = false;
uniform float wetness = 0.0;
uniform sampler2D riverbed_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool background_surface = false;
uniform sampler2D brush_weights : filter_linear, repeat_disable;
uniform float background_width = 160.0;
varying vec2 ground_position;
varying float ground_height;
varying vec3 eye_position;
varying vec3 orthographic_direction;
void vertex() {
 ground_position = (world_to_grid * MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
 ground_height = (world_to_grid * MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
 eye_position = (world_to_grid * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
 orthographic_direction = (world_to_grid * INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
}
int terrain_at(vec2 cell) {
 cell = clamp(cell, vec2(0.0), grid_size - 1.0);
 return int(floor(texture(terrain_ids, (cell + 0.5) / grid_size).r * 255.0 + 0.5));
}
float layer(int kind) {
 if (kind == 2) { return 1.0; }
 if (kind == 3) { return 4.0; }
 if (kind == 7) { return 2.0; }
 if (kind == 6) { return 3.0; }
 return 0.0;
}
vec4 weights(vec2 blend) {
 return vec4((1.0-blend.x)*(1.0-blend.y), blend.x*(1.0-blend.y), (1.0-blend.x)*blend.y, blend.x*blend.y);
}
vec3 details(vec2 uv, vec4 layers, vec4 w, vec2 dx, vec2 dy) {
 vec3 result = vec3(0.0);
 for (int i=0; i<4; i++) {
  if(w[i] > 0.001) { result += textureGrad(detail_maps, vec3(uv,layers[i]),dx,dy).rgb*w[i]; }
 }
 return result;
}
vec3 blended_details(vec2 uv, vec4 layers, vec4 w, vec4 meadow, float outside_blend, vec2 dx, vec2 dy) {
 vec3 garden_detail=details(uv,layers,w,dx,dy);
 if(outside_blend<=0.001) { return garden_detail; }
 return mix(garden_detail,details(uv,vec4(1.0,4.0,0.0,2.0),meadow,dx,dy),outside_blend);
}
void fragment() {
 vec2 grid = (ground_position-grid_min)/micro_size-0.5;
 vec2 cell = floor(grid);
 vec4 w = weights(smoothstep(vec2(0.30),vec2(0.70),fract(grid)));
 ivec4 kinds = ivec4(terrain_at(cell),terrain_at(cell+vec2(1,0)),terrain_at(cell+vec2(0,1)),terrain_at(cell+vec2(1)));
 vec4 layers = vec4(layer(kinds.x),layer(kinds.y),layer(kinds.z),layer(kinds.w));
 // Continue the live edge cells onto the meadow, then fade over 1.5 metres.
 // Both surfaces use the same world UVs, POM and wetness at their shared edge.
 vec2 outside=max(max(grid_min-ground_position,ground_position-(grid_min+grid_size*micro_size)),vec2(0.0));
 float outside_blend=background_surface ? smoothstep(0.0,1.5,length(outside)) : 0.0;
 vec4 meadow=vec4(1.0,0.0,0.0,0.0);
 if(background_surface) {
  meadow=texture(brush_weights,ground_position/background_width+0.5);
  meadow/=max(dot(meadow,vec4(1.0)),0.0001);
 }
 vec2 uv = ground_position*repeats_per_metre;
 vec2 dx = dFdx(uv);
 vec2 dy = dFdy(uv);
 vec3 view = normalize(eye_position-vec3(ground_position.x,ground_height,ground_position.y));
 if(orthographic_view) { view=normalize(orthographic_direction); }
 if(pom_enabled && outside_blend<0.999) {
  float count = floor(mix(28.0,10.0,abs(view.y)));
  float step_depth = 1.0/count;
  vec2 step_uv = -view.xz/max(abs(view.y),0.15)*relief_metres*repeats_per_metre/count;
  step_uv *= (1.0-outside_blend)*smoothstep(0.02,0.15,abs(view.y));
  float depth = 0.0;
  float surface_depth = 1.0-blended_details(uv,layers,w,meadow,outside_blend,dx,dy).r;
  float previous_surface = surface_depth;
  vec2 previous_uv = uv;
  for(int i=0;i<28;i++) {
   if(depth>=surface_depth || float(i)>=count) { break; }
   previous_uv=uv;
   previous_surface=surface_depth;
   uv+=step_uv;
   depth+=step_depth;
   surface_depth=1.0-blended_details(uv,layers,w,meadow,outside_blend,dx,dy).r;
  }
  float after=depth-surface_depth;
  float before=depth-step_depth-previous_surface;
  uv=mix(uv,previous_uv,clamp(after/max(after-before,0.00001),0.0,1.0));
 }
 vec3 color=vec3(0);
 vec3 mapped_normal=vec3(0);
 for(int i=0;i<4;i++) {
  if(w[i]>0.001) {
   vec3 tint = kinds[i]==1 ? vec3(0.84,0.80,0.73) : vec3(1.0);
   vec3 sampled_color=textureGrad(color_maps,vec3(uv,layers[i]),dx,dy).rgb;
   if(kinds[i]==4 || kinds[i]==5) { sampled_color=textureGrad(riverbed_color,uv,dx,dy).rgb; }
   color+=sampled_color*w[i]*tint;
   mapped_normal+=(textureGrad(normal_maps,vec3(uv,layers[i]),dx,dy).xyz*2.0-1.0)*w[i];
  }
 }
 if(outside_blend>0.001) {
  vec3 meadow_color=vec3(0.0);
  vec3 meadow_normal=vec3(0.0);
  vec4 meadow_layers=vec4(1.0,4.0,0.0,2.0);
  for(int i=0;i<4;i++) {
   if(meadow[i]>0.001) {
    meadow_color+=textureGrad(color_maps,vec3(uv,meadow_layers[i]),dx,dy).rgb*meadow[i];
    meadow_normal+=(textureGrad(normal_maps,vec3(uv,meadow_layers[i]),dx,dy).xyz*2.0-1.0)*meadow[i];
   }
  }
  color=mix(color,meadow_color,outside_blend);
  mapped_normal=mix(mapped_normal,meadow_normal,outside_blend);
 }
 vec3 data=blended_details(uv,layers,w,meadow,outside_blend,dx,dy);
 float moisture=max(wetness,texture(watered_tiles,(ground_position-grid_min)/(grid_size*micro_size)).r*(1.0-outside_blend));
 ALBEDO=color * (1.0 - moisture * 0.28);
 ROUGHNESS=mix(clamp(data.g,0.88,1.0),0.73,moisture*0.6);
 SPECULAR=0.12;
 AO=mix(1.0,data.b,0.65);
 // UVs increase in world +X/+Z: OpenGL map green points toward -Z.
 vec3 normal=normalize(vec3(mapped_normal.x*0.65,mapped_normal.z,-mapped_normal.y*0.65));
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX*MODEL_MATRIX)*vec3(normal.x,0.0,normal.z));
}

```

## third_person_player.gd

```gd
extends CharacterBody3D
## Continuous spirit movement; cells are only used to choose the soil being worked.
const SPEED := 3.0
const RADIUS := 0.16
var garden: Node3D
var cell := Vector2i(2,5)
var target_cell := Vector2i(2,5)

func setup(world: Node3D) -> void:
 garden=world
 collision_layer=0
 collision_mask=4
 var shape:=CollisionShape3D.new()
 var capsule:=CapsuleShape3D.new()
 capsule.radius=RADIUS
 capsule.height=0.5
 shape.shape=capsule
 shape.position.y=0.35
 add_child(shape)
 cell+=(garden.grid_size-Vector2i(9,9))/2
 cell=cell.clamp(Vector2i.ZERO,garden.grid_size-Vector2i.ONE)
 target_cell=cell
 position=garden.cell_center(cell)

func _allowed(point: Vector3) -> bool:
 for offset in [Vector2(-RADIUS,-RADIUS),Vector2(RADIUS,-RADIUS),Vector2(-RADIUS,RADIUS),Vector2(RADIUS,RADIUS)]:
  var candidate: Vector2i=garden.local_to_cell(point+Vector3(offset.x,0,offset.y))
  if not garden.contains_cell(candidate) or garden.blocked_cells.has(candidate):return false
 return true

func restore_position(point: Vector3) -> void:
 if not point.is_finite() or not _allowed(point):return
 position=point
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z))
 velocity=Vector3.ZERO
 cell=garden.local_to_cell(position)
 target_cell=cell

func advance(delta: float, input: Vector2, camera_yaw: float) -> void:
 var wanted:=Basis(Vector3.UP,camera_yaw)*Vector3(input.x,0,input.y).limit_length()*SPEED
 velocity=velocity.lerp(wanted,1.0-exp(-12.0*delta))
 if wanted.length_squared()<0.001 and velocity.length()<0.01:velocity=Vector3.ZERO
 var motion:=velocity*delta
 # Axis sliding also respects reserved shop-building footprints without grid snapping.
 for step in [Vector3(motion.x,0,0),Vector3(0,0,motion.z)]:
  if _allowed(position+step):move_and_collide(step)
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z))
 cell=garden.local_to_cell(position)
 target_cell=cell

func is_settled() -> bool:
 return velocity.length()<0.05

```

## tool_wheel.gd

```gd
extends Control
signal tool_selected(index: int)
signal mode_selected(index: int)
signal cancelled
const LABELS := ["Hoe", "Seed packet", "Watering can", "Shovel", "Put away"]
const MODE_LABELS := ["Dig","Pick","Pour","Thump"]
const MODE_NOTES := ["Dig a water-filled hollow", "Make a small seed hole", "Fill the ground with dirt", "Level the whole tile"]
var mode_page := false
const NOTES := ["Turn grass into earth", "Scatter a little green", "Give the ground a drink", "Choose how to shape the earth", "Stow your tool and wander"]
var selected := 0
var hovered := -1
var title: Label
var subtitle: Label
var instruction: Label
var center: Vector2
var icons: Array[Texture2D] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for key in ["hoe","seeds","water","shovel"]:
		icons.append(load("res://assets/tools/%s_icon.png" % key) if ResourceLoader.exists("res://assets/tools/%s_icon.png" % key) else null)
	title = _label(24,Color("e5c17c"))
	subtitle = _label(15,Color("d0ded0"))
	instruction = _label(14,Color("b2c6bb"))
	instruction.text = "MOVE MOUSE TO CHOOSE    ·    CLICK TO EQUIP    ·    TAB / ESC TO CLOSE"
	resized.connect(_layout)
	_layout()
	hide()

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _layout() -> void:
	center = size*0.5
	title.position = center+Vector2(-180,-264)
	title.size = Vector2(360,36)
	subtitle.position = center+Vector2(-200,205)
	subtitle.size = Vector2(400,28)
	instruction.position = center+Vector2(-370,244)
	instruction.size = Vector2(740,28)
	queue_redraw()

func open(current: int) -> void:
	mode_page=false
	selected = current
	hovered = current
	show()
	_refresh()

func open_modes(current: int) -> void:
	mode_page=true
	selected=current
	hovered=current
	show()
	_refresh()

func _labels() -> Array:
	return MODE_LABELS if mode_page else LABELS

func _choose() -> void:
	var choice: int=hovered if hovered>=0 else selected
	if mode_page:mode_selected.emit(choice)
	else:tool_selected.emit(choice)

func _cancel() -> void:
	if mode_page:open(3)
	else:cancelled.emit()

func _sector(offset: Vector2) -> int:
	var step: float=TAU/_labels().size()
	return int(floor(fposmod(offset.angle()+PI/2+step/2,TAU)/step))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var offset: Vector2 = event.position-center
		if offset.length()<65 or offset.length()>220:
			hovered = -1
		else:
			hovered = _sector(offset)
		_refresh()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and hovered>=0:
			_choose()
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			_cancel()
		accept_event()

func _refresh() -> void:
	instruction.text = "LEFT STICK / D-PAD  CHOOSE · A / CROSS  EQUIP · B / CIRCLE  CLOSE" if ControllerInput.using_pad else "MOVE MOUSE TO CHOOSE · CLICK TO EQUIP · TAB / ESC TO CLOSE"
	title.text = "Shovel · choose a mode" if mode_page else "Choose your tool"
	subtitle.text = (MODE_NOTES if mode_page else NOTES)[hovered] if hovered>=0 else "Take your time."
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.045,0.04,0.64))
	var labels:=_labels()
	var step: float=TAU/labels.size()
	for i in labels.size():
		var angle := -PI/2+i*step
		var start := angle-step/2+0.028
		var end := angle+step/2-0.028
		var polygon := PackedVector2Array()
		for j in range(41): polygon.append(center+Vector2.from_angle(lerpf(start,end,j/40.0))*198)
		for j in range(40,-1,-1): polygon.append(center+Vector2.from_angle(lerpf(start,end,j/40.0))*72)
		draw_colored_polygon(polygon,Color("395548") if i==hovered else Color("18352f"))
		draw_arc(center,198,start,end,48,Color("e5c17c") if i==hovered else Color("657868"),2.0,true)
		var icon_center := center+Vector2.from_angle(angle)*128
		var icon_index: int=3 if mode_page else i
		if icons.size()>icon_index and icons[icon_index]:
			draw_texture_rect(icons[icon_index],Rect2(icon_center-Vector2(48,56),Vector2(96,96)),false)
		var font := get_theme_default_font()
		var text_width := font.get_string_size(labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(font,icon_center+Vector2(-text_width*0.5,57),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f3ead4"))
	draw_circle(center,67,Color("102a25"))
	draw_arc(center,67,0,TAU,64,Color("9b895f"),1.0,true)
	var font := get_theme_default_font()
	draw_string(font,center+Vector2(-17,6),("Y / △" if ControllerInput.using_pad else "TAB"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e5c17c"))

func _process(_delta: float) -> void:
	if not visible: return
	var stick := ControllerInput.movement()
	if stick.length()>0.35:
		hovered=_sector(stick)
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_accept"):
		_choose()
	elif event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_left"):
		hovered=posmod(hovered-1,_labels().size())
	elif event.is_action_pressed("ui_right"):
		hovered=posmod(hovered+1,_labels().size())
	elif event.is_action_pressed("ui_up"):
		hovered=0
	elif event.is_action_pressed("ui_down"):
		hovered=2
	else: return
	_refresh()
	get_viewport().set_input_as_handled()

```

## valley_ambience.gd

```gd
extends Node
## Original synthesized environmental loops; independent from NPC dialogue.
var layers: Dictionary = {}
var muted := false
var dialogue_duck := 1.0
var stream_level := 0.0

func _ready() -> void:
	for sound in ["wind", "rain", "birds", "crickets", "thunder", "stream"]:
		var player := AudioStreamPlayer.new()
		player.name = sound.capitalize()
		var stream := load("res://audio/ambience/%s.wav" % sound).duplicate() as AudioStreamWAV
		if sound != "thunder":
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length()*stream.mix_rate)
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		layers[sound] = player
		if sound != "thunder":
			player.play()

func update_mix(delta: float, rain: float, daylight: float, paused: bool) -> void:
	var levels := {"wind": 0.18 + rain * 0.3, "rain": rain * 0.75,
		"birds": daylight * (1.0-rain) * 0.32, "crickets": (1.0-daylight) * (1.0-rain) * 0.20, "stream": stream_level}
	for sound in layers:
		var player: AudioStreamPlayer = layers[sound]
		player.stream_paused = paused or muted
		if levels.has(sound):
			var level: float = levels[sound]*dialogue_duck
			player.volume_db = lerpf(player.volume_db, linear_to_db(maxf(level, 0.0001)), 1.0-exp(-delta*2.0))

func thunder() -> void:
	var player: AudioStreamPlayer = layers["thunder"]
	player.volume_db = -6.0
	player.pitch_scale = randf_range(0.8, 1.05)
	player.play()

```

## valley_cycle.gd

```gd
extends Node3D
## 06:00–18:00 is 1200 real seconds; 18:00–06:00 another 1200.
const DAY_SECONDS := 1200.0
const FULL_CYCLE := DAY_SECONDS * 2.0
const WEATHER_NAMES := ["Fair", "Cloudy", "Light rain", "Rain", "Heavy rain", "Thunderstorm", "Clearing"]
const RAIN_LEVELS := [0.0, 0.0, 0.18, 0.45, 0.8, 1.0, 0.0]
const CLOUD_LEVELS := [0.15, 0.8, 0.85, 0.95, 1.0, 1.0, 0.4]
const WEATHER_DURATIONS := [180.0, 90.0, 150.0, 150.0, 120.0, 90.0, 120.0]
var elapsed := 0.0
var weather_elapsed := 0.0
var weather_index := 0
var rain_strength := 0.0
var cloud_cover := 0.15
var wetness := 0.0
var active_ambience: Node
var garden: Node3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var clock_label: Label
var rain: CPUParticles3D
var lightning: DirectionalLight3D
var lightning_energy := 0.0
var storm_wait := 12.0
var thunder_delay := -1.0

func setup(world: Node3D) -> void:
	garden = world
	for child in garden.get_children():
		if child is WorldEnvironment:
			environment = child.environment
		elif child is DirectionalLight3D:
			sun = child
	sky_material = environment.sky.sky_material
	environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	moon = DirectionalLight3D.new()
	moon.light_color = Color("aebfdc")
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -220
	panel.offset_right = -28
	panel.offset_top = 24
	panel.offset_bottom = 104
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", garden._panel_style(Color("263a35")))
	clock_label = garden._label("", 16, Color("eedeb9"))
	panel.add_child(clock_label)
	lightning = DirectionalLight3D.new()
	lightning.name = "DistantLightning"
	lightning.rotation_degrees = Vector3(-55, -30, 0)
	lightning.light_color = Color("c4d5f0")
	lightning.light_energy = 0.0
	lightning.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(lightning)
	_create_rain()
	_update_visuals()

func _create_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "ValleyRain"
	rain.position.y = 3.2
	rain.amount = 2400
	rain.lifetime = 0.65
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(Vector2(garden.chunk_count).x, 0.05, Vector2(garden.chunk_count).y)
	rain.direction = Vector3(0.05, -1, 0.02)
	rain.spread = 3.0
	rain.initial_velocity_min = 4.8
	rain.initial_velocity_max = 5.2
	rain.gravity = Vector3(0, -1, 0)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.006, 0.09, 0.006)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.78, 0.83, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = material
	rain.mesh = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)

func _process(delta: float) -> void:
	if not is_instance_valid(garden):
		return
	var paused: bool = garden.guide.visible or (is_instance_valid(garden.hedgehog_intro) and garden.hedgehog_intro.active and garden.hedgehog_intro.paused)
	rain.speed_scale = 0.0 if paused else 1.0
	if not paused:
		advance(delta)
	var daylight := smoothstep(-0.08, 0.20, sin(fposmod(elapsed, FULL_CYCLE) / FULL_CYCLE * TAU))
	garden.ambience.update_mix(delta, rain_strength, daylight, paused)

func advance(delta: float) -> void:
	elapsed += delta
	weather_elapsed += delta
	while weather_elapsed >= WEATHER_DURATIONS[weather_index]:
		weather_elapsed -= WEATHER_DURATIONS[weather_index]
		weather_index = (weather_index + 1) % WEATHER_NAMES.size()
	rain_strength = move_toward(rain_strength, RAIN_LEVELS[weather_index], delta / 12.0)
	cloud_cover = move_toward(cloud_cover, CLOUD_LEVELS[weather_index], delta / 30.0)
	_advance_storm(delta)
	# Rain fills low patches over 75 seconds; clear weather dries them over 3 minutes.
	wetness = clampf(wetness + delta * (rain_strength / 75.0 if rain_strength > 0.03 else -1.0 / 180.0), 0.0, 1.0)
	_update_visuals()

func _update_visuals() -> void:
	var phase := fposmod(elapsed, FULL_CYCLE) / FULL_CYCLE
	var angle := phase * TAU
	var direction := Vector3(cos(angle), sin(angle), 0.25).normalized()
	sun.look_at(sun.global_position - direction, Vector3.UP)
	moon.look_at(moon.global_position + direction, Vector3.UP)
	var daylight := smoothstep(-0.08, 0.20, direction.y)
	sun.light_energy = maxf(0.0, direction.y) * 1.1 * (1.0 - cloud_cover * 0.65)
	sun.light_color = Color("ffc080").lerp(Color("fff0ce"), smoothstep(0.0, 0.5, direction.y))
	moon.light_energy = (1.0 - daylight) * 0.4
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8c9fc4").lerp(Color("e0dac9"), daylight)
	environment.ambient_light_sky_contribution = 0.55
	environment.ambient_light_energy = lerpf(0.45, 0.85, daylight) * (1.0 - cloud_cover * 0.15)
	environment.fog_light_color = Color("243549").lerp(Color("c9c5ad"), daylight)
	environment.fog_density = lerpf(0.0025, 0.009, rain_strength)
	sky_material.set_shader_parameter("sun_direction", direction)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("cloud_cover", cloud_cover)
	sky_material.set_shader_parameter("cycle_time", elapsed)
	garden.heightfield.water_material.set_shader_parameter("wetness", wetness)
	garden.heightfield.water_material.set_shader_parameter("rain_strength", rain_strength)
	garden.heightfield.water_material.set_shader_parameter("water_time", elapsed)
	garden.terrain_material.set_shader_parameter("wetness", wetness)
	rain.emitting = rain_strength > 0.03
	var drop_count := maxi(1, roundi(2400.0 * RAIN_LEVELS[weather_index]))
	if rain.amount != drop_count:
		rain.amount = drop_count
	rain.mesh.material.albedo_color.a = lerpf(0.20, 0.55, rain_strength)
	rain.direction = Vector3(lerpf(0.02, 0.22, rain_strength), -1.0, 0.04)
	lightning.light_energy = lightning_energy
	var minutes := int(floor(fposmod(6.0 + elapsed * 24.0 / FULL_CYCLE, 24.0) * 60.0))
	clock_label.text = "Day %d · %02d:%02d\n%s" % [int(floor((elapsed + 600.0) / FULL_CYCLE)) + 1, minutes / 60, minutes % 60, WEATHER_NAMES[weather_index]]

func _advance_storm(delta: float) -> void:
	lightning_energy = move_toward(lightning_energy, 0.0, delta * 3.5)
	# A distant rumble follows each brief sky flash, and never repeats rapidly.
	if thunder_delay >= 0.0:
		thunder_delay -= delta
		if thunder_delay < 0.0:
			if is_instance_valid(active_ambience): active_ambience.thunder()
			else: garden.ambience.thunder()
	if weather_index == 5 and rain_strength > 0.7:
		storm_wait -= delta
		if storm_wait <= 0.0:
			lightning_energy = 1.1
			thunder_delay = randf_range(1.5, 3.5)
			storm_wait = randf_range(16.0, 32.0)
	else:
		storm_wait = 8.0

```

## valley_landscape.gd

```gd
extends Node3D
## Real geometry at distinct distances creates parallax as the spirit moves.
var garden: Node3D
var rng := RandomNumberGenerator.new()
var terrain_material: ShaderMaterial
var plants_material: ShaderMaterial
var mist_material: ShaderMaterial
var cloud_material: ShaderMaterial
var wisps: Array[MeshInstance3D] = []
var clouds: Array[MeshInstance3D] = []
var pine_count := 0
var deciduous_count := 0
var wild_count := 0

func build(world: Node3D) -> void:
 garden = world
 name = "LayeredValley"
 rng.seed = 1891
 terrain_material = ShaderMaterial.new()
 terrain_material.shader = preload("res://valley_scenery.gdshader")
 plants_material = terrain_material.duplicate()
 plants_material.set_shader_parameter("vegetation", true)
 terrain_material.shader = preload("res://landscape_surface.gdshader")
 terrain_material.set_shader_parameter("color_maps",load("res://assets/textures/terrain_colors.res"))
 _ridge(false)
 _ridge(true)
 _forest()
 _wild_edge()
 mist_material = ShaderMaterial.new()
 mist_material.shader = preload("res://valley_wisp.gdshader")
 cloud_material = mist_material.duplicate()
 cloud_material.set_shader_parameter("softness", 0.6)
 for i in range(18):
  var angle := float(i) * TAU / 18.0
  var radius := rng.randf_range(35,85)
  var position := Vector3(cos(angle)*radius,rng.randf_range(2,6),sin(angle)*radius)
  wisps.append(_wisp(position,Vector2(rng.randf_range(22,40),rng.randf_range(5,9)),mist_material))
 for i in range(14):
  var angle := float(i) * TAU / 14.0
  var radius := rng.randf_range(75,135)
  var cloud := _wisp(Vector3(cos(angle)*radius,rng.randf_range(27,48),sin(angle)*radius),Vector2(rng.randf_range(30,60),rng.randf_range(8,16)),cloud_material)
  cloud.set_meta("origin",cloud.position)
  clouds.append(cloud)
 update_atmosphere()

func _ridge_height(radius: float, angle: float, far: bool) -> float:
 if far:
  var profile := maxf(0.0,1.0-absf(radius-137.0)/59.0)
  var peak := 37.0+16.0*sin(angle*5.0+0.7)+11.0*sin(angle*9.0-0.6)+7.0*cos(angle*13.0)
  return pow(profile,1.05)*peak
 var profile := maxf(0.0,1.0-absf(radius-46.0)/22.0)
 return pow(profile,1.6)*(7.0+3.0*sin(angle*3.0)+2.0*cos(angle*7.0))

func _ridge(far: bool) -> void:
 var segments := 112 if far else 96
 var rows := 12 if far else 9
 var start := 78.0 if far else 24.0
 var end := 196.0 if far else 68.0
 var points: Array[Vector3] = []
 for row in range(rows+1):
  var radius := lerpf(start,end,float(row)/rows)
  for col in range(segments):
   var angle := float(col)*TAU/segments
   var h := _ridge_height(radius,angle,far)
   if row>0 and row<rows:
    h += rng.randf_range(-1.4,1.4) if far else rng.randf_range(-0.25,0.25)
   points.append(Vector3(cos(angle)*radius,maxf(0,h),sin(angle)*radius))
 var builder := SurfaceTool.new()
 builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(rows):
  for col in range(segments):
   var a := row*segments+col
   var b := row*segments+(col+1)%segments
   var c := (row+1)*segments+col
   var d := (row+1)*segments+(col+1)%segments
   for tri in [[a,c,b],[b,c,d]]:
    var normal: Vector3 = (points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
    if normal.y < 0: normal = -normal
    var height: float = (points[tri[0]].y+points[tri[1]].y+points[tri[2]].y)/3.0
    var color := Color("5a7042").lerp(Color("8b8962"),clampf(height/12.0,0,1))
    if far:
     color=Color("526277").lerp(Color("898a9e"),clampf(height/60.0,0,1))
     if height>37.0 and normal.y>0.3:
      color=color.lerp(Color("d7dbd9"),smoothstep(37,60,height)*0.8)
    color *= rng.randf_range(0.88,1.12)
    for index in tri:
     builder.set_color(color.srgb_to_linear())
     builder.set_normal(normal)
     builder.add_vertex(points[index])
 var mesh := MeshInstance3D.new()
 mesh.name = "SnowdoniaPeaks" if far else "WoodedRidges"
 mesh.mesh = builder.commit()
 mesh.material_override = terrain_material
 add_child(mesh)
 preload("res://scenery_grass.gd").plant(self,mesh.mesh,"MountainGrass" if far else "RidgeGrass",0.025 if far else 1.2,26.0 if far else 11.0)

func _append(builder: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
 var data := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
 for i in range(indices.size() if not indices.is_empty() else vertices.size()):
  var index := indices[i] if not indices.is_empty() else i
  builder.set_color(color.srgb_to_linear())
  builder.set_normal((transform.basis.inverse().transposed()*normals[index]).normalized())
  builder.add_vertex(transform*vertices[index])

func _ball(radius: float, height: float) -> SphereMesh:
 var mesh := SphereMesh.new()
 mesh.radius=radius
 mesh.height=height
 mesh.radial_segments=7
 mesh.rings=3
 return mesh

func _prototype(kind: String) -> ArrayMesh:
 var builder := SurfaceTool.new()
 builder.begin(Mesh.PRIMITIVE_TRIANGLES)
 if kind in ["pine","broadleaf"]:
  var trunk := CylinderMesh.new()
  trunk.top_radius=0.10
  trunk.bottom_radius=0.19
  trunk.height=2.4
  trunk.radial_segments=6
  _append(builder,trunk,Transform3D(Basis.IDENTITY,Vector3(0,1.2,0)),Color("64503b"))
  if kind=="pine":
   for i in range(3):
    var cone := CylinderMesh.new()
    cone.top_radius=0
    cone.bottom_radius=1.35-i*0.28
    cone.height=2.4-i*0.25
    cone.radial_segments=7
    _append(builder,cone,Transform3D(Basis.IDENTITY,Vector3(0,2.1+i*0.85,0)),Color("294b38").lightened(i*0.055))
  else:
   for i in range(4):
    var angle := i*TAU/4.0
    _append(builder,_ball(1.25,2.1),Transform3D(Basis.IDENTITY,Vector3(cos(angle)*0.65,2.8+0.3*(i%2),sin(angle)*0.65)),Color("52693b").lightened(i*0.035))
 elif kind=="fern":
  for i in range(7):
   var angle:=i*TAU/7.0
   var direction:=Vector3(cos(angle),0,sin(angle))
   var across:=Vector3(-sin(angle),0,cos(angle))
   for leaf in range(4):
    var t:=float(leaf+1)/5.0
    var center:=direction*t*0.7+Vector3.UP*sin(t*PI)*0.5
    for sign in [-1.0,1.0]:
     for p in [center-direction*0.12,center+across*sign*(1.0-t)*0.32+direction*0.13,center+direction*0.14]:
      builder.set_color(Color("456337").lightened(t*0.12).srgb_to_linear())
      builder.set_normal(Vector3.UP)
      builder.add_vertex(p)
 else:
  var gorse := kind=="gorse"
  for i in range(6):
   var angle:=i*TAU/6.0
   var point:=Vector3(cos(angle)*0.32,0.25+0.08*(i%3),sin(angle)*0.32)
   _append(builder,_ball(0.34,0.6),Transform3D(Basis.IDENTITY,point),Color("4f6031") if gorse else Color("596047"))
   _append(builder,_ball(0.15,0.24),Transform3D(Basis.IDENTITY,point+Vector3.UP*0.25),Color("cfad3a") if gorse else Color("96758f"))
 return builder.commit()

func _instances(mesh: Mesh, placements: Array[Transform3D], label: String) -> void:
 var multi:=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.mesh=mesh
 multi.instance_count=placements.size()
 for i in range(placements.size()): multi.set_instance_transform(i,placements[i])
 var node:=MultiMeshInstance3D.new()
 node.name=label
 node.multimesh=multi
 node.material_override=plants_material
 node.extra_cull_margin=1.0
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)

func _forest() -> void:
 for kind in ["ash","birch"]:
  var placements: Array[Transform3D]=[]
  for i in range(300 if kind=="ash" else 220):
   var angle:=rng.randf()*TAU
   # Angular modulation gathers the trees into irregular woodland clusters.
   var radius:=rng.randf_range(29,64)
   if sin(angle*11.0)+cos(radius*0.3)<-0.6: continue
   var height:=_ridge_height(radius,angle,false)-0.18
   var size:=rng.randf_range(0.65,1.35)
   placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(cos(angle)*radius,height,sin(angle)*radius)))
  preload("res://imported_trees.gd").plant(self,placements,kind)
  if kind=="ash": pine_count=placements.size()
  else: deciduous_count=placements.size()

func _wild_edge() -> void:
 var half: Vector2=Vector2(garden.chunk_count)*garden.CHUNK_SIZE*0.5
 for kind in ["fern","heather","gorse"]:
  var placements: Array[Transform3D]=[]
  for i in range(520):
   var point:=Vector2(rng.randf_range(-32,32),rng.randf_range(-32,32))
   var outside: float=maxf(absf(point.x)-half.x,absf(point.y)-half.y)
   if outside<1.2 or point.length()>33: continue
   if rng.randf()>lerpf(0.12,0.85,smoothstep(1.2,14.0,outside)): continue
   var height: float = _ridge_height(point.length(),atan2(point.y,point.x),false) if point.length()>24 else garden.background_meadow.height_at(point)
   var size:=rng.randf_range(0.6,1.25)
   placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(point.x,maxf(0,height-0.1),point.y)))
  wild_count+=placements.size()
  _instances(_prototype(kind),placements,kind.capitalize()+"Edge")

func _wisp(position: Vector3, size: Vector2, material: ShaderMaterial) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new()
 var quad:=QuadMesh.new()
 quad.size=size
 mesh.mesh=quad
 mesh.position=position
 mesh.material_override=material
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(mesh)
 return mesh

func _process(_delta: float) -> void:
 if is_instance_valid(garden): update_atmosphere()

func update_atmosphere() -> void:
 var cycle=garden.valley_cycle
 var light: float=cycle.sky_material.get_shader_parameter("daylight")
 var rain: float=cycle.rain_strength
 var haze:=Color("28384f").lerp(Color("9cabb6"),light)
 for mat in [terrain_material,plants_material]:
  mat.set_shader_parameter("haze_color",haze)
  mat.set_shader_parameter("daylight",light)
  mat.set_shader_parameter("rain_strength",rain)
  mat.set_shader_parameter("scenery_time",cycle.elapsed)
 mist_material.set_shader_parameter("tint",haze)
 mist_material.set_shader_parameter("opacity",0.16+rain*0.25)
 mist_material.set_shader_parameter("drift_time",cycle.elapsed)
 cloud_material.set_shader_parameter("tint",Color("343c58").lerp(Color("deddd4"),light))
 cloud_material.set_shader_parameter("opacity",0.45+cycle.cloud_cover*0.28)
 cloud_material.set_shader_parameter("drift_time",cycle.elapsed)
 for wisp in wisps:
  wisp.rotation.y=atan2(garden.camera.global_position.x-wisp.global_position.x,garden.camera.global_position.z-wisp.global_position.z)
 for cloud in clouds:
  var origin: Vector3=cloud.get_meta("origin")
  cloud.position=origin+Vector3(sin(cycle.elapsed*0.002+origin.z)*9.0,0,cos(cycle.elapsed*0.0015+origin.x)*5.0)
  cloud.rotation.y=atan2(garden.camera.global_position.x-cloud.global_position.x,garden.camera.global_position.z-cloud.global_position.z)


```

## valley_scenery.gdshader

```gdshader
shader_type spatial;
render_mode cull_disabled;
uniform vec3 haze_color : source_color = vec3(0.53,0.62,0.66);
uniform float daylight = 1.0;
uniform float rain_strength = 0.0;
uniform float scenery_time = 0.0;
uniform bool vegetation = false;
varying vec3 world_point;
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if(vegetation) {
  VERTEX.x += sin(scenery_time*0.7+world_point.x*0.4+world_point.z*0.3)*min(VERTEX.y,5.0)*0.012;
 }
}
void fragment() {
 float distance_to_eye=distance(CAMERA_POSITION_WORLD,world_point);
 float ground_mist=exp(-max(world_point.y,0.0)*0.075);
 float haze=(1.0-exp(-max(distance_to_eye-18.0,0.0)*(0.003+rain_strength*0.006)))*mix(0.35,0.85,ground_mist);
 ALBEDO=mix(COLOR.rgb,haze_color,haze*0.65);
 EMISSION=haze_color*haze*(0.14+daylight*0.12);
 ROUGHNESS=0.95;
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
}

```

## valley_wisp.gdshader

```gdshader
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.8,0.83,0.83);
uniform float opacity = 0.2;
uniform float drift_time = 0.0;
uniform float softness = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void fragment() {
 vec2 q=UV*2.0-1.0;
 float edge=pow(1.0-smoothstep(0.05,1.0,dot(q,q)),max(2.0,softness));
 float cloud=noise(UV*vec2(6,3)+vec2(drift_time*0.004,0))*0.6+noise(UV*vec2(13,5)-vec2(drift_time*0.002,0))*0.4;
 ALBEDO=tint;
 ALPHA=edge*smoothstep(0.26,0.72,cloud)*opacity;
}

```

## village.gd

```gd
extends Node3D
const Stock=preload("res://village_stock.gd")
const SHOPS=["THE ANIMAL KEEPER","THE PLANT NURSERY","THE DECORATOR","THE BUILDER"]
const SUBTITLES=["New companions for your garden","A little more green","Small comforts, made with care","A home in the valley"]
const CHUNK_SIZE=2.0
var chunk_count:=Vector2i(12,12)
var valley_cycle: Node3D
var background_meadow: Node3D
var moon: DirectionalLight3D
var lightning: DirectionalLight3D
var rain: CPUParticles3D
var clock_label: Label
var sun: DirectionalLight3D
var outdoor_environment: Environment
var indoor_environment: Environment
var host: Node3D
var exterior: Node3D
var interior: Node3D
var camera: Camera3D
var spirit: CharacterBody3D
var ring: Node3D
var yaw:=0.0
var pitch:=PI/4.0
var selected_shop:=-1
var current_shop:=-1
var paused:=false
var trigger_held:=false
var hud: Label
var prompt: Label
var shop_panel: PanelContainer
var shop_title: Label
var shop_note: Label
var balance: Label
var stock_list: VBoxContainer
var receipt: Label
var pause_panel: PanelContainer
var showcase: Node3D
var ambience: Node
var purchase_buttons: Array[Button]=[]

func _ready() -> void:
 position=Vector3(1000,0,0)
 exterior=Node3D.new()
 add_child(exterior)
 interior=Node3D.new()
 interior.position=Vector3(0,0,-100)
 add_child(interior)
 interior.hide()
 camera=Camera3D.new()
 camera.near=.05
 camera.far=500
 camera.fov=68
 add_child(camera)
 var world:=WorldEnvironment.new()
 sun=DirectionalLight3D.new()
 add_child(sun)
 preload("res://welsh_sky.gd").apply(world,sun)
 outdoor_environment=world.environment
 outdoor_environment.sky.sky_material.set_shader_parameter("sun_direction",Vector3(.4,.75,.2))
 outdoor_environment.sky.sky_material.set_shader_parameter("cloud_cover",.35)
 sun.light_energy=.65
 camera.environment=outdoor_environment
 indoor_environment=Environment.new()
 indoor_environment.background_mode=Environment.BG_COLOR
 indoor_environment.background_color=Color("30251c")
 indoor_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 indoor_environment.ambient_light_color=Color("f0d9b5")
 indoor_environment.ambient_light_energy=.55
 world.free()
 _build_street()
 _build_room()
 _build_ui()
 var compass_layer:=CanvasLayer.new()
 add_child(compass_layer)
 var compass:=preload("res://garden_compass.gd").new()
 compass_layer.add_child(compass)
 compass.setup(camera)
 ambience=preload("res://valley_ambience.gd").new()
 add_child(ambience)
 ControllerInput.mode_changed.connect(_input_mode)
 ControllerInput.disconnected.connect(func(): if current_shop<0: _pause(true))

func activate(owner_menu: Node3D) -> void:
 host=owner_menu
 valley_cycle=host.garden.valley_cycle
 outdoor_environment=valley_cycle.environment
 camera.environment=outdoor_environment
 background_meadow=preload("res://village_outdoors.gd").new()
 exterior.add_child(background_meadow)
 background_meadow.build(self)
 moon=DirectionalLight3D.new()
 add_child(moon)
 lightning=DirectionalLight3D.new()
 add_child(lightning)
 rain=valley_cycle.rain.duplicate() as CPUParticles3D
 rain.mesh=rain.mesh.duplicate()
 rain.mesh.material=rain.mesh.material.duplicate()
 rain.position=Vector3(0,3.2,0)
 exterior.add_child(rain)
 var weather=preload("res://model_weather.gd").new()
 add_child(weather)
 weather.setup(self)
 valley_cycle.active_ambience=ambience
 _sync_weather(0.0)
 camera.make_current()
 _leave_shop()
 preload("res://diorama_camera.gd").follow(camera,spirit.position,yaw,pitch)

func _solid(parent: Node3D, dimensions: Vector3, at: Vector3, shop: int=-1) -> void:
 var body:=StaticBody3D.new()
 body.collision_layer=1
 parent.add_child(body)
 body.position=at
 if shop>=0: body.set_meta("shop",shop)
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=dimensions
 collision.shape=shape
 body.add_child(collision)

func _build_street() -> void:
 for i in range(4):
  var side: float=-1.0 if i%2==0 else 1.0
  var at:=Vector3(side*7,0,-10 if i<2 else 4)
  var cottage:=preload("res://assets/cottage.glb").instantiate()
  cottage.scale=Vector3.ONE*(5.8/.982788)
  cottage.position=at
  cottage.rotation.y=PI/2 if side<0 else -PI/2
  exterior.add_child(cottage)
  _solid(exterior,Vector3(5.6,4.3,5.8),at+Vector3(0,2.15,0),i)
  var sign:=Label3D.new()
  sign.text=SHOPS[i]
  sign.position=Vector3(side*3.75,2.25,at.z)
  sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  sign.font_size=40
  sign.pixel_size=.008
  sign.modulate=Color("ffe1a2")
  sign.outline_size=9
  exterior.add_child(sign)
  Stock.box(exterior,Vector3(.14,2.2,.14),Color("58422c"),Vector3(side*3.75,1.1,at.z))
  # Broad selectable frontage: the sign and cottage both open the same shop.
  var area:=Area3D.new()
  area.collision_layer=16
  area.set_meta("shop",i)
  area.position=at+Vector3(0,2.2,0)
  var shape:=CollisionShape3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(5.9,4.5,6.1)
  shape.shape=box
  exterior.add_child(area)
  area.add_child(shape)
 var placements: Array[Transform3D]=[]
 for side in [-1,1]:
  for z in range(-27,25,8): placements.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.75),Vector3(side*16,0,z)))
 preload("res://imported_trees.gd").plant(exterior,placements,"birch")
 spirit=CharacterBody3D.new()
 spirit.collision_layer=2
 spirit.collision_mask=1
 exterior.add_child(spirit)
 spirit.position=Vector3(0,0,16)
 var collision:=CollisionShape3D.new()
 var sphere:=SphereShape3D.new()
 sphere.radius=.28
 collision.shape=sphere
 collision.position.y=.4
 spirit.add_child(collision)
 ring=preload("res://gliding_cursor.gd").new()
 exterior.add_child(ring)
 ring.surface_height=func(_point: Vector2) -> float: return 0.0
 ring.follow_feet(spirit.position,Vector2.ONE*0.7,0.0)

func _build_room() -> void:
 Stock.box(interior,Vector3(12,.18,10),Color("584332"),Vector3(0,4,0))
 Stock.box(interior,Vector3(.2,4,10),Color("c7b68e"),Vector3(5.9,2,0))
 Stock.box(interior,Vector3(12,.15,10),Color("79543a"),Vector3(0,-.1,0))
 for x in range(-6,7): Stock.box(interior,Vector3(.018,.015,10),Color("443126"),Vector3(x,0,0))
 Stock.box(interior,Vector3(12,4,.2),Color("e0ceaa"),Vector3(0,2,-4.5))
 Stock.box(interior,Vector3(.2,4,10),Color("c7b68e"),Vector3(-5.9,2,0))
 for x in [-5,-2,2,5]: Stock.box(interior,Vector3(.2,4,.26),Color("493626"),Vector3(x,2,-4.3))
 Stock.box(interior,Vector3(12,.24,.3),Color("493626"),Vector3(0,3.65,-4.3))
 Stock.box(interior,Vector3(5,1.0,1.1),Color("705036"),Vector3(-1.3,.5,-1.4))
 Stock.box(interior,Vector3(5.2,.12,1.3),Color("b88b58"),Vector3(-1.3,1.06,-1.4))
 for y in [1.2,2.2]: Stock.box(interior,Vector3(4,.1,.6),Color("674831"),Vector3(-1.8,y,-4.0))
 for i in range(7):
  var pot:=Stock.model("planter")
  pot.scale=Vector3.ONE*.7
  pot.position=Vector3(-3.4+i*.52,1.25,-4)
  interior.add_child(pot)
 var light:=OmniLight3D.new()
 light.position=Vector3(-1,3,0)
 light.light_color=Color("ffd396")
 light.light_energy=1.2
 light.omni_range=12
 interior.add_child(light)
 showcase=Node3D.new()
 showcase.position=Vector3(-1.6,1.14,-1.4)
 interior.add_child(showcase)

func _label(parent: Node, text: String, size: int=18) -> Label:
 var label:=Label.new()
 label.text=text
 label.add_theme_font_size_override("font_size",size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> Button:
 var button:=Button.new()
 button.text=text
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func _build_ui() -> void:
 var layer:=CanvasLayer.new()
 add_child(layer)
 var root:=Control.new()
 root.theme=preload("res://cwtch_theme.gd").make()
 layer.add_child(root)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var panel:=PanelContainer.new()
 root.add_child(panel)
 panel.position=Vector2(24,24)
 var stack:=VBoxContainer.new()
 panel.add_child(stack)
 _label(stack,"C W T C H  /  THE VILLAGE",21)
 hud=_label(stack,"",15)
 clock_label=_label(stack,"",16)
 prompt=_label(root,"",21)
 prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 prompt.offset_left=-270; prompt.offset_right=270
 prompt.offset_top=-30; prompt.offset_bottom=65
 prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
 prompt.add_theme_constant_override("shadow_offset_y",2)
 prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
 shop_panel=PanelContainer.new()
 root.add_child(shop_panel)
 shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
 shop_panel.offset_left=-440; shop_panel.offset_right=-28
 shop_panel.offset_top=-280; shop_panel.offset_bottom=280
 var shop_stack:=VBoxContainer.new()
 shop_stack.add_theme_constant_override("separation",10)
 shop_panel.add_child(shop_stack)
 shop_title=_label(shop_stack,"",22)
 shop_note=_label(shop_stack,"",15)
 balance=_label(shop_stack,"",19)
 stock_list=VBoxContainer.new()
 stock_list.add_theme_constant_override("separation",8)
 shop_stack.add_child(stock_list)
 receipt=_label(shop_stack,"Purchases are delivered to clear ground\nin your garden.",16)
 receipt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 receipt.custom_minimum_size=Vector2(350,70)
 _button(shop_stack,"Back to the street",_leave_shop)
 shop_panel.hide()
 pause_panel=PanelContainer.new()
 root.add_child(pause_panel)
 pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 pause_panel.offset_left=-210; pause_panel.offset_right=210
 pause_panel.offset_top=-160; pause_panel.offset_bottom=160
 var pause_stack:=VBoxContainer.new()
 pause_stack.add_theme_constant_override("separation",12)
 pause_panel.add_child(pause_stack)
 _label(pause_stack,"A MOMENT IN THE VILLAGE",22)
 _button(pause_stack,"Continue exploring",func(): _pause(false))
 _button(pause_stack,"Return to the garden",func(): host.return_from_village())
 _button(pause_stack,"Save & Quit",func(): host.save_and_quit())
 pause_panel.hide()

func _input_mode() -> void:
 if current_shop>=0: ControllerInput.focus_first.call_deferred(shop_panel)
 elif paused: ControllerInput.focus_first.call_deferred(pause_panel)

func _pause(value: bool) -> void:
 paused=value
 pause_panel.visible=value
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
 if value: ControllerInput.focus_first.call_deferred(pause_panel)
 else:
  var focus:=get_viewport().gui_get_focus_owner()
  if focus: focus.release_focus()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(host): return
 ambience.muted=host.garden.ambience_muted
 _sync_weather(delta)
 hud.text="%d coins  ·  %s"%[host.coins,"Left stick move · Right stick look · Menu pause" if ControllerInput.using_pad else "WASD move · Mouse look · Esc travel menu"]
 if current_shop>=0:
  showcase.rotation.y+=delta*.2
  return
 if paused: return
 var look:=ControllerInput.look()
 yaw-=look.x*delta*1.8
 pitch=clampf(pitch+look.y*delta*1.5,-.55,1.1)
 var move:=(Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))+ControllerInput.movement()).limit_length()
 spirit.velocity=Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)*3.0
 spirit.move_and_slide()
 spirit.position.x=clampf(spirit.position.x,-12,12)
 spirit.position.z=clampf(spirit.position.z,-24,19)
 preload("res://diorama_camera.gd").follow(camera,spirit.position,yaw,pitch)
 var origin:=camera.global_position
 var ray:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*24,1|16)
 ray.collide_with_areas=true
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 selected_shop=int(hit.collider.get_meta("shop",-1)) if not hit.is_empty() else -1
 if selected_shop>=0:
  var side: float=-1.0 if selected_shop%2==0 else 1.0
  ring.follow_object(Vector3(side*7,0,-10 if selected_shop<2 else 4),Vector2(6.4,6.4),delta)
 else: ring.follow_object(spirit.position,Vector2.ONE*0.7,delta)
 prompt.text=(SHOPS[selected_shop]+"\n"+("A / Cross · enter" if ControllerInput.using_pad else "Click / E · enter")) if selected_shop>=0 else "·"

func _unhandled_input(event: InputEvent) -> void:
 if not is_instance_valid(host): return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pad_guide"):
  if current_shop>=0: _leave_shop()
  else: _pause(not paused)
  get_viewport().set_input_as_handled()
  return
 if paused or current_shop>=0: return
 if event is InputEventMouseMotion:
  yaw-=event.relative.x*.004
  pitch=clampf(pitch+event.relative.y*.004,-.55,1.1)
 var enter: bool=event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT or event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E
 if event.is_action("pad_use"):
  enter=event.is_action_pressed("pad_use") and not trigger_held
  trigger_held=event.is_action_pressed("pad_use")
 if enter and selected_shop>=0:
  enter_shop(selected_shop)
  get_viewport().set_input_as_handled()

func enter_shop(index: int) -> void:
 if index<0 or index>=SHOPS.size(): return
 current_shop=index
 camera.environment=indoor_environment
 sun.hide()
 moon.hide()
 lightning.hide()
 exterior.hide()
 interior.show()
 shop_panel.show()
 prompt.hide()
 paused=false
 pause_panel.hide()
 camera.position=Vector3(1.3,2.4,-93.5)
 camera.look_at(to_global(Vector3(0,1.2,-102)))
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 shop_title.text=SHOPS[index]
 shop_note.text=SUBTITLES[index]
 receipt.text="Delivered to clear ground in your garden.\nYou begin with 500 village coins."
 for child in stock_list.get_children(): child.free()
 purchase_buttons.clear()
 for item in Stock.STOCK:
  if item.shop!=index: continue
  var button:=_button(stock_list,"%s  ·  %d coins"%[item.name,item.price],func(): _buy(item.id))
  button.mouse_entered.connect(func(): _display(item.id))
  button.focus_entered.connect(func(): _display(item.id))
  purchase_buttons.append(button)
  button.set_meta("item",item.id)
  var note:=_label(stock_list,item.note,14)
  note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _refresh_balance()
 _display(str(purchase_buttons[0].get_meta("item")))
 ControllerInput.focus_first.call_deferred(shop_panel)

func _display(id: String) -> void:
 for child in showcase.get_children(): child.free()
 var model: Node3D
 if id=="hedgehog": model=host.garden.hedgehog.visual.duplicate(0)
 else: model=Stock.model(id)
 var bounds: AABB=preload("res://floating_tool.gd").bounds(model)
 var factor:=1.6/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
 model.scale*=factor
 model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
 showcase.add_child(model)

func _refresh_balance() -> void:
 balance.text="Your purse: %d coins"%host.coins
 for button in purchase_buttons:
  var entry: Dictionary=Stock.item(button.get_meta("item"))
  button.disabled=host.coins<int(entry.price)

func _buy(id: String) -> void:
 receipt.text=host.purchase_village_item(id)
 _refresh_balance()

func _leave_shop() -> void:
 current_shop=-1
 camera.environment=outdoor_environment
 sun.show()
 if is_instance_valid(moon): moon.show()
 if is_instance_valid(lightning): lightning.show()
 interior.hide()
 exterior.show()
 shop_panel.hide()
 prompt.show()
 for child in showcase.get_children(): child.free()
 _pause(false)
 selected_shop=-1

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause_panel) and current_shop<0: _pause(true)

func _sync_weather(delta: float) -> void:
 if not is_instance_valid(valley_cycle):return
 # Advance the garden's single clock while its scene is inactive.
 if not paused:valley_cycle.advance(delta)
 for pair in [[sun,valley_cycle.sun],[moon,valley_cycle.moon],[lightning,valley_cycle.lightning]]:
  var target: DirectionalLight3D=pair[0]
  var source: DirectionalLight3D=pair[1]
  target.global_rotation=source.global_rotation
  target.light_color=source.light_color
  target.light_energy=source.light_energy
  target.sky_mode=source.sky_mode
  target.visible=current_shop<0
 rain.position=spirit.position+Vector3.UP*3.2
 rain.emitting=valley_cycle.rain_strength>0.03 and current_shop<0
 rain.speed_scale=0.0 if paused else 1.0
 rain.amount=valley_cycle.rain.amount
 rain.direction=valley_cycle.rain.direction
 rain.mesh.material.albedo_color=valley_cycle.rain.mesh.material.albedo_color
 background_meadow.material.set_shader_parameter("wetness",valley_cycle.wetness)
 clock_label.text=valley_cycle.clock_label.text
 var daylight: float=valley_cycle.sky_material.get_shader_parameter("daylight")
 ambience.update_mix(delta,valley_cycle.rain_strength,daylight,paused)

```

## village.tscn

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://village.gd" id="1"]

[node name="Village" type="Node3D"]
script = ExtResource("1")

```

## village_ground.gdshader

```gdshader
shader_type spatial;
uniform sampler2DArray color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness = 0.0;
varying vec2 point;
void vertex(){ point=VERTEX.xz; }
void fragment(){
 float edge=abs(point.x)+sin(point.y*1.7)*0.10+sin(point.y*4.1)*0.035;
 float road=(1.0-smoothstep(2.6,3.4,edge))*(1.0-smoothstep(23.0,31.0,abs(point.y+4.0)));
 vec3 grass=texture(color_maps,vec3(point,1.0)).rgb;
 vec3 gravel=texture(color_maps,vec3(point,3.0)).rgb;
 ALBEDO=mix(grass,gravel,road)*(1.0-wetness*0.28);
 vec3 n=mix(texture(normal_maps,vec3(point,1.0)).xyz,texture(normal_maps,vec3(point,3.0)).xyz,road)*2.0-1.0;
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX*MODEL_MATRIX)*vec3(n.x,0.0,-n.y)*0.45);
 ROUGHNESS=mix(0.98,0.84,wetness);
 SPECULAR=0.1;
}

```

## village_outdoors.gd

```gd
extends Node3D
var material: ShaderMaterial
var noise:=FastNoiseLite.new()
func height_at(p: Vector2) -> float:
 var outside: float=(p.abs()-Vector2(14,28)).max(Vector2.ZERO).length()
 return maxf(0.0,0.35+noise.get_noise_2dv(p)*0.7)*smoothstep(0.0,10.0,outside)
func build(village: Node3D) -> void:
 noise.seed=1891
 noise.frequency=0.10
 var plane:=PlaneMesh.new()
 plane.size=Vector2(440,440)
 plane.subdivide_width=219
 plane.subdivide_depth=219
 var arrays:=plane.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in vertices.size():vertices[i].y=height_at(Vector2(vertices[i].x,vertices[i].z))
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var builder:=SurfaceTool.new()
 builder.create_from(mesh,0)
 builder.generate_normals()
 var ground:=MeshInstance3D.new()
 ground.name='VillageMeadow'
 ground.mesh=builder.commit()
 material=ShaderMaterial.new()
 material.shader=preload('res://village_ground.gdshader')
 material.set_shader_parameter('color_maps',load('res://assets/textures/terrain_colors.res'))
 material.set_shader_parameter('normal_maps',load('res://assets/textures/terrain_normals.res'))
 ground.material_override=material
 add_child(ground)
 # Grass strips frame the street without growing through shop floors or the road.
 for side in [-1,1]:
  for band in [Vector2(19,10),Vector2(3.7,0.5)]:
   var patch:=PlaneMesh.new()
   patch.size=Vector2(band.y,54)
   patch.subdivide_width=maxi(1,ceili(band.y)-1)
   patch.subdivide_depth=26
   var data:=patch.surface_get_arrays(0)
   var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
   for i in points.size():points[i]+=Vector3(side*band.x,0,0)
   data[Mesh.ARRAY_VERTEX]=points
   var strip:=ArrayMesh.new()
   strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
   preload('res://scenery_grass.gd').plant(self,strip,'VillageVerge',3.0,2.0)
 var landscape:=preload('res://valley_landscape.gd').new()
 add_child(landscape)
 landscape.scale=Vector3.ONE*1.5
 landscape.build(village)

```

## village_stock.gd

```gd
extends RefCounted
## Shop stock and deterministic delivery shared by the village and save loader.
const STOCK := [
 {"id":"peacock","shop":0,"name":"Peacock","price":65,"note":"A colourful resident with a magnificent tail."},
 {"id":"chicken","shop":0,"name":"Chicken","price":25,"note":"A busy new companion for your garden."},
 {"id":"hedgehog","shop":0,"name":"Hedgehog","price":40,"note":"Needs 1% grass to visit; 5% to become resident."},
 {"id":"birch","shop":1,"name":"Young birch","price":35,"note":"A pale-trunked tree for an open patch."},
 {"id":"ash","shop":1,"name":"Young ash","price":35,"note":"A leafy addition to the garden."},
 {"id":"planter","shop":2,"name":"Flower planter","price":15,"note":"A terracotta pot of valley flowers."},
 {"id":"bench","shop":2,"name":"Wooden bench","price":30,"note":"A quiet place to watch the valley."},
 {"id":"cottage","shop":3,"name":"Garden cottage","price":180,"note":"Commission a small cottage on clear ground."}
]
static func item(id: String) -> Dictionary:
 for entry in STOCK:
  if entry.id==id: return entry
 return {}

static func footprint(id: String) -> Vector2:
 if id=="cottage": return Vector2(4.2,4.2)
 if id=="bench": return Vector2(1.6,0.9)
 if id in ["birch","ash"]: return Vector2(1.2,1.2)
 return Vector2(0.7,0.7)

static func find_space(garden: Node3D, id: String) -> Vector2i:
 var half: Vector2=footprint(id)*0.5+Vector2.ONE*garden.MICRO_SIZE*0.5
 for z in range(2,garden.grid_size.y-2):
  for x in range(2,garden.grid_size.x-2):
   var cell:=Vector2i(x,z)
   var point: Vector3=garden.cell_center(cell)
   if absf(point.x)+half.x> -garden.grid_min.x or absf(point.z)+half.y> -garden.grid_min.y: continue
   var clear:=true
   for blocked in garden.blocked_cells:
    var at: Vector3=garden.cell_center(blocked)
    if absf(at.x-point.x)<half.x and absf(at.z-point.z)<half.y: clear=false; break
   if not clear: continue
   for crop in garden.crops:
    var at: Vector3=garden.cell_center(crop)
    if absf(at.x-point.x)<half.x and absf(at.z-point.z)<half.y: clear=false; break
   if not clear: continue
   if absf(garden.player.position.x-point.x)<half.x+0.6 and absf(garden.player.position.z-point.z)<half.y+0.6: continue
   for npc in garden.get_tree().get_nodes_in_group("garden_npcs"):
    var reserved: Vector3=garden.cell_center(npc.next_cell)
    if (absf(npc.position.x-point.x)<half.x+0.6 and absf(npc.position.z-point.z)<half.y+0.6) or (absf(reserved.x-point.x)<half.x+0.6 and absf(reserved.z-point.z)<half.y+0.6): clear=false; break
   if clear: return cell
 return Vector2i(-1,-1)

static func deliver(garden: Node3D, record: Dictionary) -> Node3D:
 var id: String=record.id
 var cell:=Vector2i(int(record.x),int(record.z))
 if id in ["chicken","hedgehog","peacock"]:
  var actor: Node3D=load("res://peacock_npc.gd" if id=="peacock" else ("res://chicken_npc.gd" if id=="chicken" else "res://hedgehog_npc.gd")).new()
  garden.add_child(actor)
  actor.setup(garden)
  actor.cell=cell
  actor.next_cell=cell
  actor.position=garden.cell_center(cell)
  actor.destination=actor.position
  preload("res://selection_target.gd").attach(actor,item(id).name,Vector3(0.5,0.5,0.5))
  actor.set_meta("animal_id",id)
  garden.additional_visitors.append(actor)
  garden.wildlife.purchased(id)
  return actor
 var node:=model(id)
 garden.add_child(node)
 node.position=garden.cell_center(cell)
 var size:=footprint(id)
 preload("res://selection_target.gd").attach(node,item(id).name,Vector3(size.x,2.5 if id=="cottage" else 1.0,size.y))
 var body:=StaticBody3D.new()
 body.collision_layer=4
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(size.x,2.5 if id=="cottage" else 1.0,size.y)
 shape.shape=box
 shape.position.y=box.size.y*0.5
 node.add_child(body)
 body.add_child(shape)
 for z in garden.grid_size.y:
  for x in garden.grid_size.x:
   var at: Vector3=garden.cell_center(Vector2i(x,z))
   if absf(at.x-node.position.x)<size.x*0.5+garden.MICRO_SIZE*0.5 and absf(at.z-node.position.z)<size.y*0.5+garden.MICRO_SIZE*0.5:
    garden.blocked_cells[Vector2i(x,z)]=true
 return node

static func part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.mesh=mesh
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 material.roughness=0.85
 node.material_override=material
 node.position=at
 parent.add_child(node)
 return node

static func box(parent: Node3D, size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
 var mesh:=BoxMesh.new()
 mesh.size=size
 return part(parent,mesh,color,at)

static func model(id: String) -> Node3D:
 var root:=Node3D.new()
 var path: String=""
 var width:=1.0
 if id=="cottage": path="res://assets/cottage.glb"; width=3.8
 elif id in ["ash","birch"]: path="res://assets/trees/%s_forest.glb"%id; width=2.2
 elif id=="peacock": path="res://assets/animals/Peacock/Peacock.fbx"; width=0.85
 elif id=="hedgehog": path="res://assets/hedgehog.glb"; width=0.35
 elif id=="chicken": path="res://assets/chicken_rig.glb"; width=0.5
 if path!="":
  var imported: Node3D=load(path).instantiate()
  var bounds: AABB=preload("res://floating_tool.gd").bounds(imported)
  var factor:=width/(bounds.size.y if id in ["ash","birch"] else maxf(bounds.size.x,bounds.size.z))
  imported.scale*=factor
  imported.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
  root.add_child(imported)
 elif id=="bench":
  box(root,Vector3(1.4,.12,.5),Color("795036"),Vector3(0,.48,0))
  box(root,Vector3(1.4,.42,.1),Color("926541"),Vector3(0,.8,-.22))
  for x in [-.52,.52]: box(root,Vector3(.12,.48,.4),Color("443123"),Vector3(x,.24,0))
 elif id=="planter":
  var pot:=CylinderMesh.new()
  pot.top_radius=.3; pot.bottom_radius=.2; pot.height=.4
  part(root,pot,Color("a66549"),Vector3(0,.2,0))
  for i in range(7):
   var at:=Vector3(sin(i*2.4)*.18,.57,cos(i*2.4)*.18)
   box(root,Vector3(.025,.35,.025),Color("52623b"),at-Vector3(0,.15,0))
   var flower:=SphereMesh.new()
   flower.radius=.09; flower.height=.1
   part(root,flower,Color("c994ba") if i%2==0 else Color("e7bf64"),at)
 return root

```

## visiting_hedgehog.gd

```gd
extends "res://hedgehog_npc.gd"
var visit_state := "outside"
var patrol_corner := 1
var entry_cell := Vector2i.ZERO

func setup(world: Node3D) -> void:
 super.setup(world)
 set_meta("animal_id","hedgehog")
 remove_from_group("garden_npcs")
 position=Vector3(-garden.grid_min.x+1.25,0,0)
 position.y=garden.background_meadow.height_at(Vector2(position.x,position.z))

func _entry() -> bool:
 var nearest:=INF
 var found:=false
 for y in range(garden.grid_size.y):
  for x in range(garden.grid_size.x):
   if x!=0 and y!=0 and x!=garden.grid_size.x-1 and y!=garden.grid_size.y-1:continue
   var candidate:=Vector2i(x,y)
   if not _can_reserve(candidate):continue
   var distance: float=position.distance_squared_to(garden.cell_center(candidate))
   if distance<nearest:
    nearest=distance
    entry_cell=candidate
    found=true
 return found

func advance(delta: float) -> void:
 if garden.guide.visible or garden.tool_wheel.visible:return
 if visit_state=="inside":
  super.advance(delta)
  return
 if visit_state=="outside" and garden.wildlife.grass_ratio()>=0.01 and _entry():visit_state="entering"
 var half: Vector2=-garden.grid_min+Vector2.ONE*1.25
 var corners: Array[Vector3]=[Vector3(half.x,0,-half.y),Vector3(half.x,0,half.y),Vector3(-half.x,0,half.y),Vector3(-half.x,0,-half.y)]
 var target: Vector3=corners[patrol_corner] if visit_state=="outside" else garden.cell_center(entry_cell)
 if visit_state=="entering" and not garden.wildlife.records.has("hedgehog") and garden.wildlife.grass_ratio()<0.01:
  visit_state="outside"
  return
 var offset:=Vector3(target.x-position.x,0,target.z-position.z)
 walking=offset.length()>0.02
 if walking:
  visual.rotation.y=lerp_angle(visual.rotation.y,atan2(offset.x,offset.z),1.0-exp(-3.0*delta))
  var hit:=move_and_collide(offset.normalized()*minf(offset.length(),delta*0.32))
  if hit and visit_state=="entering":_entry()
 var inside: bool=garden.contains_cell(garden.local_to_cell(position))
 position.y=garden.heightfield.height_at(Vector2(position.x,position.z)) if inside else garden.background_meadow.height_at(Vector2(position.x,position.z))
 gait+=delta
 body.rotation.z=sin(gait*10.0)*0.045
 body.position.y=absf(sin(gait*8.0))*0.006
 if inside and visit_state=="entering":garden.wildlife.record_visit("hedgehog")
 if offset.length()<0.04:
  if visit_state=="outside":patrol_corner=(patrol_corner+1)%4
  else:
   cell=entry_cell
   next_cell=cell
   destination=garden.cell_center(cell)
   add_to_group("garden_npcs")
   visit_state="inside"

```

## wandering_npc.gd

```gd
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

```

## water.gdshader

```gdshader
shader_type spatial;
uniform sampler2D watered_tiles : filter_linear, repeat_disable;
render_mode cull_disabled;
uniform sampler2D terrain_ids : filter_nearest, repeat_disable;
uniform sampler2D water_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_opacity : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bottom_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bottom_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_min;
uniform vec2 grid_size;
uniform float micro_size;
uniform float wetness = 0.0;
uniform float rain_strength = 0.0;
uniform float water_time = 0.0;
uniform sampler2D bed_heights : filter_linear, repeat_disable;
uniform vec2 height_samples;
varying vec2 ground_position;
void vertex() {
 ground_position = VERTEX.xz;
 vec2 uv=((VERTEX.xz-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
 VERTEX.y += max(0.0,texture(bed_heights,uv).r);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float water_at(vec2 cell) {
 cell=clamp(cell,vec2(0),grid_size-1.0);
 int kind=int(floor(texture(terrain_ids,(cell+0.5)/grid_size).r*255.0+0.5));
 return kind==5 ? 0.65 : (kind==4 ? 0.28 : 0.0);
}
void fragment() {
 vec2 grid=(ground_position-grid_min)/micro_size-0.5;
 vec2 cell=floor(grid);
 vec2 f=smoothstep(vec2(0.30),vec2(0.70),fract(grid));
 float flood=mix(mix(water_at(cell),water_at(cell+vec2(1,0)),f.x),mix(water_at(cell+vec2(0,1)),water_at(cell+vec2(1)),f.x),f.y);
 vec2 height_uv=((ground_position-grid_min)/(grid_size*micro_size)*(height_samples-1.0)+0.5)/height_samples;
 float bed=texture(bed_heights,height_uv).r;
 float depth=max(0.0,-bed);
 bool pond=depth>0.003 && flood>0.01;
 // Fixed low spots expand as rain accumulates, then shrink as the ground dries.
 float low_spot=noise(ground_position*3.8)*0.75+noise(ground_position*9.0)*0.25;
 float moisture=max(wetness,texture(watered_tiles,(ground_position-grid_min)/(grid_size*micro_size)).r);
 float puddle=smoothstep(0.86-moisture*0.12,0.90-moisture*0.12,low_spot)*smoothstep(0.08,0.35,moisture);
 if(!pond && puddle<0.5) { discard; }
 vec2 uv=ground_position*0.7;
 vec2 flow=vec2(water_time*0.008,water_time*0.004);
 vec3 n1=texture(water_normal,uv+flow).xyz*2.0-1.0;
 vec3 n2=texture(water_normal,uv-flow*0.6).xyz*2.0-1.0;
 vec3 surface_color=texture(water_color,uv+flow).rgb;
 vec3 riverbed=texture(bottom_color,ground_position).rgb*mix(0.7,1.0,texture(bottom_ao,ground_position).r);
 float opacity=clamp(texture(water_opacity,uv+flow).r,0.25,0.85);
 vec3 tint=mix(vec3(0.13,0.30,0.28),vec3(0.035,0.13,0.19),smoothstep(0.1,0.65,depth));
 ALBEDO=pond ? tint*0.8+surface_color*0.2 : mix(riverbed,tint,0.72);
 ALPHA=pond ? clamp((1.0-exp(-depth*2.6))*0.7+opacity*0.18,0.34,0.88) : 0.65;
 ROUGHNESS=clamp(texture(water_roughness,uv+flow).r,0.23,0.44);
 SPECULAR=0.4;
 vec2 ripple_uv=fract(ground_position*5.0)-0.5;
 float ripple=sin(length(ripple_uv)*65.0-water_time*12.0)*exp(-length(ripple_uv)*5.0)*rain_strength;
 vec2 slope=(n1.xy+n2.xy)*(pond ? 0.10 : 0.035)+normalize(ripple_uv+vec2(0.0001))*ripple*0.07;
 NORMAL=normalize(mat3(VIEW_MATRIX*MODEL_MATRIX)*normalize(vec3(slope.x,1.0,slope.y)));
}

```

## welsh_sky.gd

```gd
extends RefCounted

static func apply(world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://cosy_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Use the actual perspective lens for a consistent horizon while orbiting.
	environment.sky_custom_fov = 0.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.ambient_light_sky_contribution = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color("c9c5ad")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.08
	# Godot 4.6 supports SSAO in Compatibility as well as Forward+.
	environment.ssao_enabled = true
	environment.ssao_radius = 0.4
	environment.ssao_intensity = 0.8
	environment.ssao_power = 1.2
	world.environment = environment
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	sun.light_color = Color("ffe2ac")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 25.0

static func generate_cloud_cover() -> ImageTexture:
	var image := Image.create(512, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1891
	noise.frequency = 3.0
	noise.fractal_octaves = 5
	for y in range(256):
		var latitude := float(y) / 255.0 * PI
		for x in range(512):
			var longitude := float(x) / 511.0 * TAU
			# Sampling a sphere makes the panorama join without a seam.
			var p := Vector3(sin(latitude) * cos(longitude),
				cos(latitude), sin(latitude) * sin(longitude))
			var cloud := smoothstep(-0.55, 0.55, noise.get_noise_3dv(p))
			var value := cloud * 0.28
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

```

