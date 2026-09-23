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
