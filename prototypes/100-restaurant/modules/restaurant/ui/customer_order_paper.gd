extends Control
signal opened
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
var heading: Label
var body: Label
var footer: Label
var mood: Control
var full_text := ""

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var paper = preload("res://modules/restaurant/ui/paper_surface.gd").new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	paper.z_index=-1
	heading = _label(Vector2(19,20),Vector2(size.x-87,34),24)
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body = _label(Vector2(19,70),Vector2(size.x-38,size.y-116),20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_setup_footer()
	mood = preload("res://modules/restaurant/ui/mood_icon.gd").new()
	mood.position = Vector2(size.x-64,17)
	add_child(mood)
	tooltip_text = "拿近一点，读完整的叮嘱"

func _setup_footer() -> void:
	footer = _label(Vector2(19,size.y-32),Vector2(size.x-36,25),14)
	footer.modulate = Color("978565")

func _label(point: Vector2, box: Vector2, font_size: int) -> Label:
	var value := Label.new()
	value.position = point
	value.size = box
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override("font",Ink.font())
	value.add_theme_font_size_override("font_size",font_size)
	value.add_theme_color_override("font_color",Color("5b4935"))
	add_child(value)
	return value

func update_order(npc: Dictionary, wait: float, preference: String) -> void:
	mood.visible = not npc.is_empty()
	if npc.is_empty():
		heading.text = "留给主厨"
		body.text = "今天，慢慢来。\n\n先做一道你喜欢的菜，等街坊们来坐坐。"
		footer.text = "100饭店 · 今日的小纸条"
	else:
		heading.text = str(npc.get("name","这位客人")) + " 的一餐"
		heading.add_theme_font_size_override("font_size",20 if heading.text.length()>6 else 24)
		var words := str(npc.get("quote","今天想吃点什么？"))
		if npc.has("ordered_recipe"): words += "\n\n想点《%s》。" % str(npc.ordered_recipe.get("title",""))
		if npc.get("preferences_known",false): words += "\n\n小叮嘱：" + preference
		body.text = words
		mood.mood = float(npc.get("mood_before",50))
		footer.text = "还能等 %d:%02d · 拿近读" % [int(ceil(wait))/60,int(ceil(wait))%60]
	full_text = heading.text + "\n\n" + body.text

func _draw() -> void:
	# A short pencilled rule and an off-centre translucent tape tab.
	draw_polyline(PackedVector2Array([Vector2(18,57),Vector2(size.x*.48,58),Vector2(size.x-22,56)]),Color("b59570",0.5),1.2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(77,-7),Vector2(150,-4),Vector2(148,10),Vector2(79,8)]),Color("bcad7c",0.6))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		opened.emit()
		accept_event()
