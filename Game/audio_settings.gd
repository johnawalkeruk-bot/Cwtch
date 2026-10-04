extends Node
## Category gains are independent of the scene's fades and dialogue ducking.
const PATH="user://options.json"
const BUSES=["Master","Music","Ambience","Sound effects","Speech"]
var levels: Dictionary={"Master":0.7,"Music":1.0,"Ambience":1.0,"Sound effects":1.0,"Speech":1.0}
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 for bus in BUSES+["UI"]:
  if AudioServer.get_bus_index(bus)<0:
   AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
   AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
 restore()
func read_options() -> Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
 return data if data is Dictionary else {}
func restore() -> void:
 var data:=read_options()
 var legacy=data.get("volume",70)
 var master_default:=clampf(float(legacy)/100.0,0.0,1.0) if (legacy is int or legacy is float) and is_finite(float(legacy)) else 0.7
 var audio=data.get("audio",{})
 if not audio is Dictionary:audio={}
 for bus in BUSES:
  var value=audio.get(bus,master_default if bus=="Master" else 1.0)
  levels[bus]=clampf(float(value),0.0,1.0) if (value is int or value is float) and is_finite(float(value)) else (0.7 if bus=="Master" else 1.0)
  apply(bus)
func apply(bus: String) -> void:
 var index:=AudioServer.get_bus_index(bus)
 AudioServer.set_bus_mute(index,float(levels[bus])<=0.0)
 AudioServer.set_bus_volume_db(index,linear_to_db(maxf(float(levels[bus]),0.0001)))
func set_level(bus: String, value: float) -> void:
 if not levels.has(bus) or not is_finite(value):return
 levels[bus]=clampf(value,0.0,1.0);apply(bus);save()
func save() -> void:
 var data:=read_options()
 data["audio"]=levels.duplicate()
 data["volume"]=float(levels.Master)*100.0
 var file:=FileAccess.open(PATH,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(data))
