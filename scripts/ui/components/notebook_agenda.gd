extends Control
const AGENDA = preload("res://scripts/core/daily_agenda.gd")
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var owner_ui: Control

func _ready() -> void:
	name="NotebookAgenda"
	PALETTE.words(self,"B 的随身本 · 今日日程",Vector2.ZERO,1000,30,PALETTE.INK)
	PALETTE.words(self,"第 %d 天  /  现在 %s  /  可支配 %d 元" % [GameState.current_day,GameState.clock_text(),GameState.money],Vector2(0,48),1000,20,PALETTE.MUTED)
	var left := _scroll(Vector2(0,108),Vector2(565,399))
	for row in AGENDA.rows():
		_words(left,"%s—%s   %s · %s" % [GuidanceSystem.time_text(int(row.start)),GuidanceSystem.time_text(int(row.end)),str(row.kind),AGENDA.status_text(row)],20,PALETTE.MUTED)
		_words(left,str(row.title),25)
		_words(left,"地点："+str(row.place),21)
		_words(left,str(row.detail),20,PALETTE.MUTED)
		var line := HSeparator.new(); line.custom_minimum_size.y=21; left.add_child(line)
	var right := _scroll(Vector2(606,108),Vector2(387,399))
	var next := AGENDA.next_row()
	_words(right,"接下来",25)
	if not next.is_empty():
		_words(right,"%s · %s\n%s" % [GuidanceSystem.time_text(int(next.start)),str(next.title),str(next.place)],22)
		var map := _button(right,"查看地点与路程",func(): owner_ui.map_selected=str(next.location); owner_ui.mode="map"; owner_ui.build())
		map.name="AgendaRoute"
	_words(right,"还可以安排的时间",24)
	var spans := AGENDA.free_windows()
	for span in spans: _words(right,"%s—%s · %d 分钟" % [GuidanceSystem.time_text(int(span[0])),GuidanceSystem.time_text(int(span[1])),int(span[1])-int(span[0])],20)
	if spans.is_empty(): _words(right,"今天没有剩余空档了。",20)
	_words(right,"这些空档已扣除工作、约定和待做计划；出门还需要路上的时间。",18,PALETTE.MUTED)
	var edit := _button(self,"安排活动 / 调整班次",func(): owner_ui.notebook_section="me"; owner_ui.build())
	edit.position=Vector2(0,534); edit.size=Vector2(400,46); edit.name="AgendaEdit"
	PALETTE.words(self,"完成、取消和错过的安排，都会如实留在这里。",Vector2(435,546),570,18,PALETTE.MUTED)

func _scroll(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var area := ScrollContainer.new(); area.position=at; area.size=dimensions; area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(area)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.custom_minimum_size.x=dimensions.x-22; rows.add_theme_constant_override("separation",10); area.add_child(rows); return rows

func _words(parent: Node,text: String,point: int,color := PALETTE.INK) -> Label:
	var word := Label.new(); word.text=LocalizationSystem.text(text); word.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; word.add_theme_font_override("font",PaperLanguage.handwriting); word.add_theme_font_size_override("font_size",point); word.add_theme_color_override("font_color",color); parent.add_child(word); return word

func _button(parent: Node,text: String,action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(text); button.custom_minimum_size.y=46; parent.add_child(button); button.pressed.connect(action); return button
