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
