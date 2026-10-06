extends RefCounted
const INK := Color("172d2a")
const GOLD := Color("e5c17c")
const CREAM := Color("f3ead4")
const MUTED := Color("b2c6bb")

static func panel(color: Color = Color(0.06,0.13,0.12,0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.76,0.65,0.42,0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0,0.025,0.02,0.22)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0,4)
	return style

static func make() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Arial"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_constant("separation","VBoxContainer",10)
	theme.set_constant("separation","HBoxContainer",12)
	theme.set_color("font_color","Label",CREAM)
	theme.set_stylebox("panel","PanelContainer",panel())
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,button_style(Color("213c35")))
		theme.set_stylebox("hover",type,button_style(Color("355347")))
		theme.set_stylebox("pressed",type,button_style(Color("132b26")))
		var focus := panel(Color(0,0,0,0))
		focus.border_color = GOLD
		focus.set_border_width_all(2)
		theme.set_stylebox("focus",type,focus)
		theme.set_color("font_color",type,CREAM)
		theme.set_color("font_hover_color",type,GOLD)
		theme.set_color("font_pressed_color",type,GOLD)
	theme.set_stylebox("panel","PopupMenu",panel())
	theme.set_color("font_color","PopupMenu",CREAM)
	return theme

static func button_style(color: Color) -> StyleBoxFlat:
	var style := panel(color)
	style.set_corner_radius_all(8)
	style.content_margin_top=12
	style.content_margin_bottom=12
	style.shadow_size=0
	return style

static func compact_card() -> StyleBoxFlat:
	var style := panel()
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

static func decorate_menu(node: PanelContainer) -> void:
	var theme:=make()
	theme.default_font=preload("res://petal_shapes.gd").serif()
	theme.set_color("font_color","Label",INK)
	var paper:=panel(Color("f3e6c9"))
	paper.border_color=INK
	paper.set_border_width_all(3)
	theme.set_stylebox("panel","PanelContainer",paper)
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,button_style(Color("dfcca2")))
		theme.set_stylebox("hover",type,button_style(Color("f4d03f")))
		theme.set_stylebox("pressed",type,button_style(Color("d8ab37")))
		var focus:=StyleBoxFlat.new()
		focus.bg_color=Color(1,0.75,0.1,0.12)
		focus.border_color=Color("c3912b")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(8)
		theme.set_stylebox("focus",type,focus)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:theme.set_color(state,type,INK)
	node.theme=theme
	for label in node.find_children("*","Label",true,false):label.add_theme_color_override("font_color",INK)
	var petals:=preload("res://petal_frame.gd").new()
	node.add_child(petals)

static func uppercase_menu(node: Node) -> void:
	# Display transformation only: never modify typed values or category IDs.
	if node is Label:node.uppercase=true
	if node is Button:node.text=node.text.to_upper()
	if node is OptionButton:
		for index in node.item_count:node.set_item_text(index,node.get_item_text(index).to_upper())
	for child in node.get_children():uppercase_menu(child)
