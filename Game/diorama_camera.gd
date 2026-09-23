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
