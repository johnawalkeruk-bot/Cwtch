extends Node
## Original synthesized environmental loops; independent from NPC dialogue.
var layers: Dictionary = {}
var muted := false
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
			var level: float = levels[sound]
			player.volume_db = lerpf(player.volume_db, linear_to_db(maxf(level, 0.0001)), 1.0-exp(-delta*2.0))

func thunder() -> void:
	var player: AudioStreamPlayer = layers["thunder"]
	player.volume_db = -6.0
	player.pitch_scale = randf_range(0.8, 1.05)
	player.play()
