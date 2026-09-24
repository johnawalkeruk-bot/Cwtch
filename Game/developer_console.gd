extends CanvasLayer
var garden: Node3D
var backdrop: ColorRect
var panel: PanelContainer
var output: RichTextLabel
var command: LineEdit
var history: Array[String]=[]
var history_index := 0
var opened := false

func setup(world: Node3D) -> void:
 garden=world
 layer=100
 backdrop=ColorRect.new()
 add_child(backdrop)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color=Color(0,0,0,0.22)
 backdrop.hide()
 panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 panel.offset_left=32
 panel.offset_right=-32
 panel.offset_top=96
 panel.offset_bottom=390
 panel.add_theme_stylebox_override("panel",garden._panel_style(Color(0.06,0.11,0.10,0.97)))
 var stack:=VBoxContainer.new()
 panel.add_child(stack)
 stack.add_child(garden._label("DEVELOPER CONSOLE   ·   ` / ESC to close",18,Color("ebce8b")))
 output=RichTextLabel.new()
 output.custom_minimum_size.y=170
 output.size_flags_vertical=Control.SIZE_EXPAND_FILL
 output.scroll_following=true
 output.selection_enabled=true
 output.add_theme_font_size_override("normal_font_size",16)
 stack.add_child(output)
 command=LineEdit.new()
 command.placeholder_text="help • time 18:30 • weather heavy rain • tardis land"
 command.add_theme_font_size_override("font_size",18)
 command.text_submitted.connect(_submit)
 stack.add_child(command)
 panel.hide()
 _write("Time, weather and the TARDIS. Type help for commands. ↑ / ↓ recalls commands.")

func toggle(value: bool) -> void:
 opened=value
 panel.visible=value
 backdrop.visible=value
 garden._clear_use()
 garden.player.velocity=Vector3.ZERO
 if value:
  if garden.tool_wheel.visible:garden._set_wheel(false)
  garden.aiming=false
  garden.aim_dot.hide()
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  command.grab_focus()
 else:
  command.release_focus()
  garden.aiming=not garden.guide.visible
  garden.aim_dot.visible=garden.aiming
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if garden.aiming else Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
 if is_instance_valid(garden.hedgehog_intro) and garden.hedgehog_intro.active:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_QUOTELEFT or event.keycode==KEY_QUOTELEFT:
   if not garden.field_book.visible:toggle(not opened)
   get_viewport().set_input_as_handled()
   return
  if opened and event.keycode==KEY_ESCAPE:
   toggle(false)
   get_viewport().set_input_as_handled()
   return
  if opened and event.keycode in [KEY_UP,KEY_DOWN]:
   history_index=clampi(history_index+(-1 if event.keycode==KEY_UP else 1),0,history.size())
   command.text=history[history_index] if history_index<history.size() else ""
   command.caret_column=command.text.length()
   get_viewport().set_input_as_handled()
 if opened and (event is InputEventMouseMotion or event is InputEventJoypadButton or event is InputEventJoypadMotion):
  get_viewport().set_input_as_handled()

func _write(text: String) -> void:
 output.add_text(text+"\n")
 if output.get_line_count()>180:output.clear()

func _submit(text: String) -> void:
 var clean:=text.strip_edges()
 if clean.is_empty():return
 history.append(clean)
 if history.size()>50:history.pop_front()
 history_index=history.size()
 _write("> "+clean)
 _write(execute(clean))
 command.clear()

func execute(text: String) -> String:
 var words:=text.strip_edges().to_lower().split(" ",false)
 if words.is_empty():return "Type help."
 var args: String=" ".join(words.slice(1))
 match words[0]:
  "help":return "time HH:MM | weather fair / cloudy / light rain / rain / heavy rain / thunderstorm / clearing\ntardis land | tardis takeoff | tardis visit | tardis status\nVisit lands, stays for 20 seconds, then takes off. Time and weather continue cycling."
  "time":
   var parts:=args.split(":")
   if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():return "Use time HH:MM (24-hour clock)."
   var hour:=int(parts[0])
   var minute:=int(parts[1])
   if hour<0 or hour>23 or minute<0 or minute>59:return "Use an hour from 00–23 and minutes from 00–59."
   var cycle: Node3D=garden.valley_cycle
   cycle.elapsed=floor(cycle.elapsed/cycle.FULL_CYCLE)*cycle.FULL_CYCLE+fposmod(float(hour*60+minute-360),1440.0)/1440.0*cycle.FULL_CYCLE
   cycle._update_visuals()
   return "Time set to %02d:%02d."%[hour,minute]
  "weather":
   var cycle: Node3D=garden.valley_cycle
   var index: int=-1
   for i in cycle.WEATHER_NAMES.size():
    if cycle.WEATHER_NAMES[i].to_lower()==args.replace("_"," "):index=i
   if index<0:return "Weather: fair, cloudy, light rain, rain, heavy rain, thunderstorm, clearing."
   cycle.weather_index=index
   cycle.weather_elapsed=0.0
   cycle.rain_strength=cycle.RAIN_LEVELS[index]
   cycle.cloud_cover=cycle.CLOUD_LEVELS[index]
   cycle.lightning_energy=0.0
   cycle.thunder_delay=-1.0
   cycle.storm_wait=3.0
   cycle._update_visuals()
   return "Weather set to "+cycle.WEATHER_NAMES[index]+"."
  "tardis":
   match args:
    "land":return garden.tardis.land(false)
    "visit":return garden.tardis.land(true)
    "takeoff", "take off":return garden.tardis.takeoff()
    "status":return "TARDIS: "+garden.tardis.state+"."
   return "Use tardis land, tardis takeoff, tardis visit or tardis status."
 return "Unknown command. Type help."
