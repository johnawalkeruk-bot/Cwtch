extends Node
## Common mapped controllers: left stick moves, right stick aims.
signal mode_changed
signal disconnected
var using_pad := false
var device := -1

func _ready() -> void:
	for entry in [["pad_left",JOY_AXIS_LEFT_X,-1.0],["pad_right",JOY_AXIS_LEFT_X,1.0],["pad_up",JOY_AXIS_LEFT_Y,-1.0],["pad_down",JOY_AXIS_LEFT_Y,1.0],["look_left",JOY_AXIS_RIGHT_X,-1.0],["look_right",JOY_AXIS_RIGHT_X,1.0],["look_up",JOY_AXIS_RIGHT_Y,-1.0],["look_down",JOY_AXIS_RIGHT_Y,1.0],["pad_use",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		InputMap.add_action(entry[0],0.22)
		var event := InputEventJoypadMotion.new()
		event.axis=entry[1]
		event.axis_value=entry[2]
		InputMap.action_add_event(entry[0],event)
	for entry in [["pad_wheel",JOY_BUTTON_Y],["pad_guide",JOY_BUTTON_START],["pad_tardis",JOY_BUTTON_RIGHT_STICK]]:
		InputMap.add_action(entry[0])
		var event := InputEventJoypadButton.new()
		event.button_index=entry[1]
		InputMap.action_add_event(entry[0],event)
	for entry in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.button_index=entry[1]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	for entry in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis=entry[1]
		event.axis_value=entry[2]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	Input.joy_connection_changed.connect(_connection)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>0.25:
		device=event.device
		_set_mode(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion and event.relative.length()>2.0:
		_set_mode(false)

func _set_mode(pad: bool) -> void:
	if using_pad==pad: return
	using_pad=pad
	mode_changed.emit()

func _connection(id: int, connected: bool) -> void:
	if not connected and id==device:
		device=-1
		_set_mode(false)
		disconnected.emit()

func movement() -> Vector2:
	return Input.get_vector("pad_left","pad_right","pad_up","pad_down",0.22)

func look() -> Vector2:
	return Input.get_vector("look_left","look_right","look_up","look_down",0.22)

func focus_first(parent) -> void:
	if not using_pad or not is_instance_valid(parent): return
	for control in parent.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and control.focus_mode==Control.FOCUS_ALL:
			control.grab_focus()
			return
