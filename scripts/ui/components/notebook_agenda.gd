extends Control
const AGENDA = preload("res://scripts/core/daily_agenda.gd")
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
const PEN = preload("res://art/ui/fonts/xiaolai/Xiaolai-Regular.ttf")
const ITEM = preload("res://scripts/ui/components/notebook_todo.gd")
var owner_ui: Control

func _ready() -> void:
	name="NotebookAgenda"
	_heading("B 的随身本 · 今天要做的事",Vector2.ZERO,1000,30)
	_heading("第 %d 天  /  现在 %s" % [GameState.current_day,GameState.clock_text()],Vector2(0,48),1000,21,PALETTE.MUTED)
	var left := _scroll(Vector2(0,100),Vector2(395,407))
	for row in AGENDA.rows():
		var item := ITEM.new(); item.entry=row; left.add_child(item)
	var right := _scroll(Vector2(506,100),Vector2(487,407))
	var next := AGENDA.next_row()
	_words(right,"接下来，记得……",26)
	if not next.is_empty():
		_words(right,"%s · %s\n地点：%s" % [GuidanceSystem.time_text(int(next.start)),AGENDA.todo_title(next),str(next.place)],24)
		_words(right,AGENDA.note_text(next),22,PALETTE.MUTED)
		var map := _button(right,"看看怎么过去",func(): owner_ui.map_selected=str(next.location); owner_ui.mode="map"; owner_ui.build())
		map.name="AgendaRoute"
	_words(right,"这些时间还空着",25)
	var spans := AGENDA.free_windows()
	for span in spans: _words(right,"%s—%s · %d 分钟" % [GuidanceSystem.time_text(int(span[0])),GuidanceSystem.time_text(int(span[1])),int(span[1])-int(span[0])],22)
	if spans.is_empty(): _words(right,"今天没有剩余空档了。",22)
	_words(right,"出门的话，别忘了留点时间在路上。",21,PALETTE.MUTED)
	var edit := _button(self,"安排活动 / 调整班次",func(): owner_ui.notebook_section="me"; owner_ui.build())
	edit.position=Vector2(0,534); edit.size=Vector2(400,46); edit.name="AgendaEdit"
	_heading("做完的事会打勾。取消和错过，也留一笔。",Vector2(435,545),570,20,PALETTE.MUTED)

func _heading(text: String, at: Vector2, width: float, point: int, color := PALETTE.INK) -> Label:
	var word := _words(self,text,point,color); word.position=at; word.size.x=width; return word

func _scroll(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var area := ScrollContainer.new(); area.position=at; area.size=dimensions; area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(area)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.custom_minimum_size.x=dimensions.x-22; rows.add_theme_constant_override("separation",16); area.add_child(rows); return rows

func _words(parent: Node,text: String,point: int,color := PALETTE.INK) -> Label:
	var word := Label.new(); word.text=LocalizationSystem.text(text); word.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; word.add_theme_font_override("font",PEN); word.add_theme_font_size_override("font_size",point); word.add_theme_color_override("font_color",color); word.add_theme_constant_override("line_spacing",4); parent.add_child(word); return word

func _button(parent: Node,text: String,action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(text); button.custom_minimum_size.y=46; parent.add_child(button); button.add_theme_font_override("font",PEN); button.pressed.connect(action); return button
