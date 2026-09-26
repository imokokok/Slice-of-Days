extends RefCounted
## Bright camera-tool language; handwriting stays on the physical print.
const INK := Color("304967")
const BLUE := Color("709dcd")
const MINT := Color("b9dfd1")
const PAPER := Color("fffdf4")
const SUN := Color("ffe08e")
const CORAL := Color("efa17e")
const HAND := preload("res://art/ui/fonts/xiaolai/Xiaolai-Regular.ttf")

static func surface(color: Color, radius := 18) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color=color
	face.set_corner_radius_all(radius)
	face.set_content_margin_all(12)
	return face

static func theme(point := 20) -> Theme:
	var skin := Theme.new()
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","Arial Rounded MT Bold"])
	font.fallbacks=[HAND]
	skin.default_font=font; skin.default_font_size=point
	for kind in ["Label","Button","TextEdit"]: skin.set_color("font_color",kind,INK)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var face := surface(SUN if state=="pressed" else (Color("edf5e4") if state=="hover" else PAPER),16)
		face.border_color=Color("adc2d3") if state!="focus" else BLUE
		face.set_border_width_all(2)
		if state=="disabled": face.bg_color=Color("e5e9df")
		skin.set_stylebox(state,"Button",face)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: skin.set_color(state,"Button",INK)
	skin.set_color("font_disabled_color","Button",Color("9faeae"))
	return skin
