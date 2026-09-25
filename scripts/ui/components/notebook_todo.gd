extends VBoxContainer
## A written record, not a button that can complete an activity without doing it.
const AGENDA = preload("res://scripts/core/daily_agenda.gd")
const PEN = preload("res://art/ui/fonts/xiaolai/Xiaolai-Regular.ttf")
const INK := Color("40534c")
const FADED := Color("72796b")
var entry: Dictionary
var title_line: Label

func _ready() -> void:
	name="Todo_"+str(entry.id)
	add_theme_constant_override("separation",5)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	set_meta("completed",str(entry.status)=="done")
	set_meta("agenda_status",str(entry.status))
	var heading := HBoxContainer.new(); heading.add_theme_constant_override("separation",10); add_child(heading)
	var mark := Control.new(); mark.custom_minimum_size=Vector2(26,31); mark.mouse_filter=Control.MOUSE_FILTER_IGNORE; heading.add_child(mark)
	mark.draw.connect(func():
		var ink := FADED if str(entry.status) in AGENDA.CLOSED else INK
		mark.draw_polyline(PackedVector2Array([Vector2(2,7),Vector2(23,6),Vector2(24,27),Vector2(3,28),Vector2(2,7)]),ink,1.5,true)
		if str(entry.status)=="done": mark.draw_polyline(PackedVector2Array([Vector2(6,15),Vector2(13,22),Vector2(25,5)]),INK,2.3,true)
		elif str(entry.status)=="cancelled": mark.draw_line(Vector2(7,12),Vector2(19,23),FADED,1.6,true); mark.draw_line(Vector2(19,12),Vector2(7,23),FADED,1.6,true)
		elif str(entry.status)=="missed": mark.draw_line(Vector2(7,18),Vector2(20,18),FADED,1.7,true))
	title_line=_words(heading,AGENDA.todo_title(entry),25)
	title_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if str(entry.status) in ["done","cancelled"]:
		title_line.draw.connect(func():
			for line in title_line.get_line_count():
				var y := line*title_line.get_line_height()+title_line.get_line_height()*.55
				title_line.draw_line(Vector2(0,y),Vector2(minf(title_line.size.x,PEN.get_string_size(title_line.text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x),y-1),Color(FADED,.6),1.0,true))
	var inset := MarginContainer.new(); inset.add_theme_constant_override("margin_left",36); add_child(inset)
	var notes := VBoxContainer.new(); notes.add_theme_constant_override("separation",5); inset.add_child(notes)
	_words(notes,"%s—%s   ·   %s" % [GuidanceSystem.time_text(int(entry.start)),GuidanceSystem.time_text(int(entry.end)),AGENDA.status_text(entry)],21)
	_words(notes,"地点："+str(entry.place),22)
	_words(notes,AGENDA.note_text(entry),20,true)
	var rule := Control.new(); rule.custom_minimum_size.y=9; add_child(rule)
	rule.draw.connect(func(): rule.draw_line(Vector2(35,7),Vector2(rule.size.x-5,6),Color(INK,.16),1.0,true))

func _words(parent: Node, text: String, point: int, muted := false) -> Label:
	var word := Label.new(); word.text=LocalizationSystem.text(text); word.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	word.add_theme_font_override("font",PEN); word.add_theme_font_size_override("font_size",point); word.add_theme_constant_override("line_spacing",3)
	word.add_theme_color_override("font_color",FADED if muted or str(entry.status) in AGENDA.CLOSED else INK); parent.add_child(word); return word
