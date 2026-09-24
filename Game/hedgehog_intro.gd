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
   bubble.visible=not caption.text.is_empty()
   var face:=camera.unproject_position(arthur.global_position+Vector3.UP*1.35)
   var viewport:=get_viewport().get_visible_rect().size
   bubble.position=Vector2(clampf(face.x+140.0,32.0,viewport.x-452.0),clampf(face.y+20.0,40.0,viewport.y-240.0))
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
