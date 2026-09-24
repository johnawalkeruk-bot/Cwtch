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
	var paused: bool = garden.guide.visible
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
