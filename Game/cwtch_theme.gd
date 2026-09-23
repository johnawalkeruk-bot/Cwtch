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
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
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
	theme.set_color("font_color","Label",CREAM)
	theme.set_stylebox("panel","PanelContainer",panel())
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,panel(Color("213c35")))
		theme.set_stylebox("hover",type,panel(Color("355347")))
		theme.set_stylebox("pressed",type,panel(Color("132b26")))
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
