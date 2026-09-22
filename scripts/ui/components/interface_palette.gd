extends RefCounted
## Shared production tokens. Paper is reserved for records; ink surfaces for tools.
const INK := Color("243e50")
const SEA := Color("315e79")
const DEEP := Color("254b66")
const CREAM := Color("faf7ee")
const LEMON := Color("eed577")
const SAGE := Color("849776")
const MUTED := Color("607887")
const MIST := Color("e8eff0")
const SPEECH := Color("fffdf6")
const SPEECH_INK := Color("26343d")
const SPEECH_MUTED := Color("4f6470")

static func face(color: Color, radius := 8, margin := 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=color; result.set_corner_radius_all(radius); result.set_content_margin_all(margin)
	return result

static func words(parent: Node, value: String, at: Vector2, width: float, point := 20, color := INK) -> Label:
	var result := Label.new()
	result.text=value; result.position=at; result.size.x=width; result.custom_maximum_size.x=width
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font",PaperLanguage.body_font)
	result.add_theme_font_size_override("font_size",point); result.add_theme_color_override("font_color",color)
	result.add_theme_constant_override("line_spacing",5); result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func theme_for_tools() -> Theme:
	var result := Theme.new()
	result.default_font=PaperLanguage.body_font; result.default_font_size=20
	for type in ["Label","LineEdit","TextEdit","CheckBox"]: result.set_color("font_color",type,INK)
	for type in ["LineEdit","TextEdit"]:
		for state in ["normal","focus","read_only"]:
			var field := face(CREAM,5,10)
			field.border_width_bottom=2; field.border_color=SEA if state=="focus" else Color(MUTED,.3)
			result.set_stylebox(state,type,field)
		result.set_color("selection_color",type,Color(LEMON,.65)); result.set_color("caret_color",type,SEA)
	for type in ["HSlider","HScrollBar","VScrollBar"]:
		result.set_stylebox("slider",type,face(Color("587183"),3,3))
		result.set_stylebox("scroll",type,face(Color("315e79",.08),3,3))
		for style in ["grabber_area","grabber_area_highlight","grabber","grabber_highlight","grabber_pressed"]:
			result.set_stylebox(style,type,face(LEMON if "highlight" in style or "pressed" in style else SAGE,3,3))
	return result
