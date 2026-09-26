extends Control
var g
var desk
var on_close: Callable
var entries_box: VBoxContainer
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(1440,900)
	var paper=load("res://extensions/collage_letter/scripts/commission_stationery.gd").new();paper.position=Vector2(310,130);paper.size=Vector2(820,650);add_child(paper)
	desk.label("对话记录" if g.L.language=="zh" else "Conversation",Rect2(354,165,725,35),23,self)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(354,240);scroll.size=Vector2(730,446);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	entries_box=VBoxContainer.new();entries_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries_box.add_theme_constant_override("separation",14);scroll.add_child(entries_box)
	var records: Array=g.commission_history.get(str(g.commission_index),[])
	if records.is_empty():
		if g.accepted_commission==g.commission_index:
			var request: Dictionary=g.commissions[g.commission_index%g.commissions.size()]
			add_entry("委托要求" if g.L.language=="zh" else "Request",request["request_"+g.L.language])
		else:add_entry("", "还没有完整的对话。先听听客户怎么说吧。" if g.L.language=="zh" else "No conversation yet. Hear what the client has to say first.")
	else:
		for record in records:add_entry(record.speaker,record.text)
	desk.button("返回" if g.L.language=="zh" else "Back",Rect2(774,713,310,43),func():on_close.call(),false,self)
func add_entry(who: String, text: String) -> void:
	var name_label:=Label.new();name_label.text=who;name_label.add_theme_font_override("font",g.font);name_label.add_theme_font_size_override("font_size",16);name_label.add_theme_color_override("font_color",Color("997150"));entries_box.add_child(name_label)
	var paragraph:=Label.new();paragraph.text=text;paragraph.add_theme_font_override("font",g.font);paragraph.add_theme_font_size_override("font_size",20);paragraph.add_theme_color_override("font_color",Color("4c5d4e"));paragraph.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;paragraph.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries_box.add_child(paragraph)
