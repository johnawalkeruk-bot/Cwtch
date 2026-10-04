extends RefCounted
const VERSION=preload("res://build_version.gd").VERSION
const PATH="user://welcome_history.json"
static func read_history() -> Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
 return data if data is Dictionary else {}
static func should_play(account: String, saved_version: String, version: String=VERSION) -> bool:
 return saved_version!=version and str(read_history().get(account,""))!=version
static func complete(account: String, version: String=VERSION) -> void:
 var history:=read_history();history[account]=version
 var file:=FileAccess.open(PATH,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(history))
