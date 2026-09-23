extends RefCounted

const INK := Color("594c38")
const PAPER := Color("faf1dd")

static func paper_style() -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = PAPER
	face.border_color = Color("a28e68")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.set_content_margin_all(12)
	return face

static func paper_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	result.default_font = font
	result.default_font_size = 25
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "TextEdit", "PopupMenu"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, Color("938877"))
		if type == "Label": continue
		for state in ["normal", "hover", "pressed", "focus", "panel", "read_only"]:
			var face := paper_style()
			if state in ["hover", "pressed"]: face.bg_color = Color("e5dcb6")
			if state == "focus": face.bg_color = Color.TRANSPARENT; face.set_border_width_all(2)
			result.set_stylebox(state, type, face)
	for type in ["LineEdit", "TextEdit"]:
		result.set_color("font_placeholder_color", type, Color("8b7b60"))
		result.set_color("caret_color", type, INK)
		result.set_color("selection_color", type, Color("d6c991"))
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_color("font_color", "RichTextLabel", INK)
	result.set_stylebox("panel", "Panel", paper_style())
	result.set_stylebox("panel", "PanelContainer", paper_style())
	return result

static func panel(parent: Node, rect: Rect2) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	var style := paper_style()
	item.add_theme_stylebox_override("panel", style)
	parent.add_child(item)
	return item

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 26) -> Label:
	var item := Label.new()
	item.text = LocalizationSystem.text(text)
	item.position = rect.position
	item.size = rect.size
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", INK)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var item := preload("res://scripts/ui/components/solmere_button.gd").new()
	item.variant="outlined"
	item.text = LocalizationSystem.text(text)
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", 24)
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(action)
	parent.add_child(item)
	return item

static func rich(parent: Node, rect: Rect2, font_size: int = 24) -> RichTextLabel:
	var item := RichTextLabel.new()
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("normal_font_size", font_size)
	item.add_theme_color_override("default_color", INK)
	item.add_theme_constant_override("line_separation", 7)
	parent.add_child(item)
	return item
