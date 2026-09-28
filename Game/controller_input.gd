extends Node
## Common mapped controllers: left stick moves, right stick aims.
signal mode_changed
signal disconnected
signal players_changed
var players: Array[int] = []
var using_pad := false
var device := -1

func _ready() -> void:
	for entry in [["pad_left",JOY_AXIS_LEFT_X,-1.0],["pad_right",JOY_AXIS_LEFT_X,1.0],["pad_up",JOY_AXIS_LEFT_Y,-1.0],["pad_down",JOY_AXIS_LEFT_Y,1.0],["look_left",JOY_AXIS_RIGHT_X,-1.0],["look_right",JOY_AXIS_RIGHT_X,1.0],["look_up",JOY_AXIS_RIGHT_Y,-1.0],["look_down",JOY_AXIS_RIGHT_Y,1.0],["pad_use",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		InputMap.add_action(entry[0],0.22)
		var event := InputEventJoypadMotion.new()
		event.device=-1
		event.axis=entry[1]
		event.axis_value=entry[2]
		InputMap.action_add_event(entry[0],event)
	for entry in [["pad_guide",JOY_BUTTON_START],["pad_tardis",JOY_BUTTON_RIGHT_STICK]]:
		InputMap.add_action(entry[0])
		var event := InputEventJoypadButton.new()
		event.device=-1
		event.button_index=entry[1]
		InputMap.action_add_event(entry[0],event)
	for entry in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.device=-1
		event.button_index=entry[1]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	for entry in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device=-1
		event.axis=entry[1]
		event.axis_value=entry[2]
		if not InputMap.action_has_event(entry[0],event): InputMap.action_add_event(entry[0],event)
	Input.joy_connection_changed.connect(_connection)
	_assign_devices(Input.get_connected_joypads())

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>0.25:
		device=primary_device()
		_set_mode(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion and event.relative.length()>2.0:
		_set_mode(false)

func _set_mode(pad: bool) -> void:
	if using_pad==pad: return
	using_pad=pad
	mode_changed.emit()

func _connection(id: int, connected: bool) -> void:
	var was_playing := id in players.slice(0,2)
	_assign_devices(Input.get_connected_joypads())
	if not connected and was_playing:
		_set_mode(not players.is_empty())
		disconnected.emit()

func _assign_devices(connected: Array[int]) -> void:
	var previous := players.duplicate()
	players.assign(players.filter(func(id): return id in connected))
	for id in connected:
		if id not in players: players.append(id)
	device=primary_device()
	if players!=previous: players_changed.emit()

func primary_device() -> int:
	return players[0] if not players.is_empty() else -1

func secondary_device() -> int:
	return players[1] if players.size()>1 else -1

func _stick(id: int, x: int, y: int) -> Vector2:
	if id<0: return Vector2.ZERO
	var value := Vector2(Input.get_joy_axis(id,x),Input.get_joy_axis(id,y))
	var length := value.length()
	return Vector2.ZERO if length<=0.22 else value.normalized()*minf(1.0,(length-0.22)/0.78)

func movement(id: int=-2) -> Vector2:
	return _stick(primary_device() if id==-2 else id,JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)

func look(id: int=-2) -> Vector2:
	return _stick(primary_device() if id==-2 else id,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y)

func use_held(id: int=-2) -> bool:
	if id==-2: id=primary_device()
	return id>=0 and Input.get_joy_axis(id,JOY_AXIS_TRIGGER_RIGHT)>0.25

func focus_first(parent) -> void:
	if not using_pad or not is_instance_valid(parent): return
	for control in parent.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and control.focus_mode==Control.FOCUS_ALL:
			control.grab_focus()
			return
