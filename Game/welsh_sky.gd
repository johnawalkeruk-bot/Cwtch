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
