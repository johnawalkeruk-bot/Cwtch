extends RefCounted
const BASE := "res://assets/ui/buttons/"
const XBOX := {"accept":"XBOX_A","back":"XBOX_B","mode":"XBOX_X","use":"XBOX_RT","pause":"XBOX_Start_Alt","move":"XBOX_Left_Stick","look":"XBOX_Right_Stick","left":"XBOX_LB","right":"XBOX_RB"}
const PS := {"accept":"ButtonIcon-PS3-Cross","back":"ButtonIcon-PS3-Circle","mode":"ButtonIcon-PS2-Square","use":"ButtonIcon-PS2-R2","pause":"ButtonIcon-PS2-Start","move":"ButtonIcon-PS2-Left_Stick","look":"ButtonIcon-PS2-Right_Stick","left":"ButtonIcon-PS2-L1","right":"ButtonIcon-PS2-R1"}
static var cache: Dictionary = {}

static func family(name: String) -> String:
	var lower := name.to_lower()
	for token in ["playstation","dualshock","dualsense","sony","ps3","ps4","ps5"]:
		if token in lower:return "playstation"
	return "xbox"

static func texture(action: String, device: int) -> Texture2D:
	var mapping: Dictionary=PS if family(Input.get_joy_name(device))=="playstation" else XBOX
	var path: String=BASE+str(mapping.get(action,mapping.accept))+".png"
	if not cache.has(path):cache[path]=load(path)
	return cache[path]
