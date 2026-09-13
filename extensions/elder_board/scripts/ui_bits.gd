extends RefCounted

static func panel(parent: Node, rect: Rect2) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303530")
	style.set_corner_radius_all(12)
	item.add_theme_stylebox_override("panel", style)
	parent.add_child(item)
	return item

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 26) -> Label:
	var item := Label.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", 24)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(action)
	parent.add_child(item)
	return item

static func rich(parent: Node, rect: Rect2, font_size: int = 24) -> RichTextLabel:
	var item := RichTextLabel.new()
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("normal_font_size", font_size)
	item.add_theme_constant_override("line_separation", 7)
	parent.add_child(item)
	return item
