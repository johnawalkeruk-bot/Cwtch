extends Node
## Native UI SFX service. One-shots only: existing music covers loading and waiting.
signal cue_played(cue: String)
const BASE="res://assets/ui/sfx/"
const OPTIONS="user://options.json"
const PACKS=["minimal","soft","glass","arcade","mechanical","organic","dreamy","scifi","rubber","cinematic","studio","zen"]
var enabled:=true
var volume:=0.35
var pack:="organic"
var typing:=false
var unlocked:=false
var catalog: Dictionary={}
var cache: Dictionary={}
var recent: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
 for asset in manifest.assets:catalog[asset.pack+"/"+asset.cue]=asset
 restore()
 get_tree().node_added.connect(_node_added)
func _input(event: InputEvent) -> void:
 if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):unlocked=true
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  stop_all();unlocked=false
func _node_added(node: Node) -> void:
 if node is LineEdit:_bind_text.call_deferred(node.get_instance_id())
func _bind_text(field_id: int) -> void:
 var field:=instance_from_id(field_id) as LineEdit
 if not is_instance_valid(field) or field.has_meta("uisfx_bound"):return
 field.set_meta("uisfx_bound",true)
 field.text_changed.connect(func(_text: String):
  if typing and field.has_focus() and not field.secret:play("typing"))
func play(cue: String) -> AudioStreamPlayer:
 if not enabled or not unlocked or volume<=0:return null
 var key:=pack+"/"+cue
 if not catalog.has(key) or bool(catalog[key].loop):return null
 var now:=Time.get_ticks_msec()
 if cue=="notification" and now-int(recent.get("purchase",-100000))<1200:return null
 var delay: int={"volume-change":220,"notification":2000,"progress-step":400,"hover":250,"seek":200}.get(cue,90)
 if cue!="typing" and now-int(recent.get(cue,-100000))<delay:return null
 voices=voices.filter(func(v):return is_instance_valid(v) and not v.is_queued_for_deletion())
 if voices.size()>=6:
  var oldest: AudioStreamPlayer=voices.pop_front();oldest.stop();oldest.queue_free()
 if not cache.has(key):
  var stream:=load(BASE+key+".mp3") as AudioStreamMP3
  if not stream:return null
  stream=stream.duplicate();stream.loop=false;cache[key]=stream
 var player:=AudioStreamPlayer.new()
 add_child(player);voices.append(player)
 player.stream=cache[key]
 player.volume_db=linear_to_db(maxf(0.0001,volume*float(catalog[key].defaultVolume)))
 player.finished.connect(func():
  voices.erase(player);player.queue_free())
 recent[cue]=now
 player.play();cue_played.emit(cue)
 return player
func stop_all() -> void:
 for voice in voices:
  if is_instance_valid(voice):voice.stop();voice.queue_free()
 voices.clear()
func set_enabled(value: bool) -> void:
 if enabled==value:return
 stop_all();enabled=value;save()
 if enabled:play("toggle-on")
func set_volume(value: float) -> void:
 volume=clampf(value,0,1);stop_all();save();play("volume-change")
func set_pack(value: String) -> void:
 if value not in PACKS or pack==value:return
 stop_all();cache.clear();recent.clear();pack=value;save();play("select")
func set_typing(value: bool) -> void:
 if typing==value:return
 typing=value;save();play("toggle-on" if value else "toggle-off")
func preferences() -> Dictionary:
 return {"enabled":enabled,"volume":volume,"pack":pack,"typing":typing}
func restore() -> void:
 var data=JSON.parse_string(FileAccess.get_file_as_string(OPTIONS)) if FileAccess.file_exists(OPTIONS) else {}
 if not data is Dictionary:return
 var prefs=data.get("ui_sfx",{})
 if not prefs is Dictionary:return
 enabled=prefs.get("enabled",true)==true
 typing=prefs.get("typing",false)==true
 var level=prefs.get("volume",0.35)
 volume=clampf(float(level),0,1) if (level is float or level is int) and is_finite(float(level)) else 0.35
 pack=str(prefs.get("pack","organic"))
 if pack not in PACKS:pack="organic"
func save() -> void:
 var data=JSON.parse_string(FileAccess.get_file_as_string(OPTIONS)) if FileAccess.file_exists(OPTIONS) else {}
 if not data is Dictionary:data={}
 data["ui_sfx"]=preferences()
 var file:=FileAccess.open(OPTIONS,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(data))
func _exit_tree() -> void:
 stop_all()
