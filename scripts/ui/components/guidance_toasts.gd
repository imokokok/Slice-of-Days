extends Control
## Short, non-blocking feedback, fed exclusively by real GuidanceSystem deltas.
var pending: Array=[]
var visible_cards: Array=[]
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	GuidanceSystem.notification.connect(enqueue)
func enqueue(kind: String, message: String) -> void:
	for row in pending:
		if row.text==message: return
	pending.append({"kind":kind,"text":message})
	# Group bursts into one notice instead of flooding the screen.
	if pending.size()>3:
		var count := pending.size()-2
		pending=pending.slice(0,2)
		pending.append({"kind":"FOUND","text":"另有 %d 条进展，已记入随身本。" % count})
	_pump()
func _pump() -> void:
	while visible_cards.size()<2 and not pending.is_empty():
		var row: Dictionary=pending.pop_front()
		var card := PanelContainer.new(); card.mouse_filter=MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new(); style.bg_color=Color("f8f6ee",.96); style.set_corner_radius_all(5); style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=7; style.content_margin_bottom=7
		style.border_width_left=3; style.border_color=PaperLanguage.YELLOW; card.add_theme_stylebox_override("panel",style)
		card.position=Vector2(1332,22+visible_cards.size()*62); card.custom_minimum_size=Vector2(252,52); add_child(card)
		var words := Label.new(); words.text=str(row.kind)+" · "+str(row.text); words.custom_minimum_size=Vector2(225,38); words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; words.max_lines_visible=2; words.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; words.add_theme_font_size_override("font_size",14); words.add_theme_color_override("font_color",PaperLanguage.BLUE); words.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(words)
		visible_cards.append(card); card.modulate.a=0
		var tween := create_tween(); tween.set_parallel(true); tween.tween_property(card,"position:x",1320,.18); tween.tween_property(card,"modulate:a",1,.18); tween.chain(); tween.set_parallel(false); tween.tween_interval(2.8); tween.tween_property(card,"modulate:a",0,.25)
		tween.tween_callback(func() -> void:
			visible_cards.erase(card); card.queue_free()
			for i in visible_cards.size(): visible_cards[i].position.y=22+i*62
			_pump())

func _process(_delta: float) -> void:
	var shell := get_parent()
	visible=not is_instance_valid(shell.get("overlay")) and not is_instance_valid(shell.get("tool"))
