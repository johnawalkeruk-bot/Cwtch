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
