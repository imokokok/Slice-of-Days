extends RefCounted
static func build() -> Theme:
	var skin: Theme = preload("res://art/ui/solmere_ui.tres").duplicate()
	skin.default_font_size = 18
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "Noto Sans CJK SC"])
	skin.default_font = font
	for kind in ["Label", "Button", "OptionButton"]: skin.set_color("font_color", kind, Color("31658b"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("faf7ee") if state == "normal" else Color("eed577")
		style.border_color=Color("31658b"); style.border_width_bottom=1
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		skin.set_stylebox(state, "Button", style)
	return skin

static func icon(kind: String) -> ImageTexture:
	var strokes := {
		"recorder": '<rect x="9" y="3" width="10" height="15" rx="5"/><path d="M5 13v2a9 9 0 0 0 18 0v-2M14 24v5M8 29h12"/>',
		"camera": '<path d="M3 10h6l3-5h8l3 5h6v18H3z"/><circle cx="16" cy="19" r="6"/>',
		"album": '<rect x="6" y="3" width="23" height="24" rx="2"/><path d="M3 8v22h21M8 23l6-8 5 5 4-4 4 7"/><circle cx="23" cy="10" r="2"/>',
		"wallet": '<circle cx="16" cy="16" r="11"/><circle cx="16" cy="16" r="7"/><path d="M13 12h5a2 2 0 0 1 0 4h-4a2 2 0 0 0 0 4h5M16 9v14"/>'}
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#654b38" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + str(strokes.get(kind, "")) + '</g></svg>')
	return ImageTexture.create_from_image(image)
