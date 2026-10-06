extends RefCounted
static func populate(box: VBoxContainer) -> void:
 for bus in ["Master","Music","UI","Ambience","Sound effects","Speech"]:
  var row:=HBoxContainer.new()
  var title:=Label.new();title.text=bus.to_upper();title.custom_minimum_size.x=140
  title.add_theme_font_size_override("font_size",15);row.add_child(title)
  var slider:=HSlider.new()
  slider.name="UISFXVolume" if bus=="UI" else ("Volume" if bus=="Master" else bus.replace(" ","")+"Volume")
  slider.max_value=100;slider.step=1;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  slider.custom_minimum_size=Vector2(180,30);slider.tooltip_text=bus.to_upper()+" VOLUME"
  slider.value=(UISounds.volume if bus=="UI" else float(AudioSettings.levels[bus]))*100.0
  var amount:=Label.new();amount.text=str(roundi(slider.value))+"%";amount.custom_minimum_size.x=48
  amount.add_theme_font_size_override("font_size",15);amount.add_theme_color_override("font_color",Color("e2bf6e"))
  slider.value_changed.connect(func(value: float):
   amount.text=str(roundi(value))+"%"
   if bus=="UI":UISounds.set_volume(value/100.0)
   else:AudioSettings.set_level(bus,value/100.0);UISounds.play("volume-change"))
  row.add_child(slider);row.add_child(amount);box.add_child(row)
static func refresh(box: Node) -> void:
 for bus in ["Master","Music","UI","Ambience","Sound effects","Speech"]:
  var name: String="UISFXVolume" if bus=="UI" else ("Volume" if bus=="Master" else bus.replace(" ","")+"Volume")
  var slider:=box.find_child(name,true,false) as HSlider
  if slider:
   slider.set_value_no_signal((UISounds.volume if bus=="UI" else float(AudioSettings.levels[bus]))*100.0)
   slider.get_parent().get_child(2).text=str(roundi(slider.value))+"%"
