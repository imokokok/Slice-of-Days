extends Control
## One compact card. The queue survives scene changes in GuidanceSystem.
var card: PanelContainer
var words: Label
var age := 0.0
var current: Dictionary={}
func _ready() -> void:
	name="GuidanceToast"
	mouse_filter=MOUSE_FILTER_IGNORE
	card=PanelContainer.new(); card.position=Vector2(1155,162); card.custom_minimum_size=Vector2(395,68); card.mouse_filter=MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new(); face.bg_color=Color("faf7ee"); face.set_corner_radius_all(6); face.set_content_margin_all(12); face.border_width_left=3; face.border_color=PaperLanguage.YELLOW; card.add_theme_stylebox_override("panel",face); add_child(card)
	words=Label.new(); words.custom_minimum_size=Vector2(367,50); words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; words.max_lines_visible=3; words.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; words.add_theme_font_size_override("font_size",17); words.add_theme_color_override("font_color",PaperLanguage.BLUE); words.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(words); card.hide()
func _process(delta: float) -> void:
	var clear := bool(UIStateSystem.policy().notify)
	visible=clear
	if not clear: return
	if current.is_empty():
		current=GuidanceSystem.take_feedback()
		if current.is_empty(): return
		words.text=str(current.text); age=0; card.show()
	age+=delta; card.modulate.a=minf(1,age/.15)*clampf((2.9-age)/.25,0,1)
	if age>=2.9: current={}; card.hide()
func _exit_tree() -> void:
	# Carry an interrupted notification over the travel/scene boundary.
	if not current.is_empty() and age<2.5:
		for entry in current.entries:
			for text in entry.texts: GuidanceSystem.queue_feedback(str(entry.kind),str(text))
