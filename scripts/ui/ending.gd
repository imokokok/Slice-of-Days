extends Control
const INK := Color("31658b")
const MUTED := Color("537890")
const BACKGROUND=preload("res://art/ui/title-screen-background.png")

func _ready() -> void:
	if not bool(ChapterSystem.story().reveal_completed): SceneRouter.town_day(); return
	_label(self,"在同一座小镇，留下不同的日子",Vector2(180,86),Vector2(1240,60),38,INK)
	_label(self,"旅程收束的是相遇，不是两个人各自继续生活的可能。",Vector2(184,145),Vector2(1200,42),21,MUTED)
	var scroll:=ScrollContainer.new()
	scroll.name="ReflectionScroll"
	scroll.position=Vector2(210,205)
	scroll.size=Vector2(1180,500)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.focus_mode=Control.FOCUS_ALL
	add_child(scroll)
	var rows:=VBoxContainer.new()
	rows.custom_minimum_size=Vector2(1130,0)
	rows.add_theme_constant_override("separation",14)
	scroll.add_child(rows)
	var reflections:=ChapterSystem.ending_reflections()
	_section(rows,"两个人留下的生活")
	for trace in reflections.works:
		_line(rows,"Day %02d · %s · %s"%[int(trace.day),str(trace.owner),LocalizationSystem.text(str(trace.title))])
	_section(rows,"小镇怎样重新认识她们")
	for recognition in reflections.recognitions:
		_line(rows,_recognition_text(recognition))
	_section(rows,"交换过的生活方式")
	if reflections.practices.is_empty():
		_line(rows,"这部分仍然留白；它是见面后的可选尝试，不影响这段旅程成立。")
	else:
		for practice in reflections.practices:
			_line(rows,LocalizationSystem.text_with_values("%s 用自己的方式尝试了%s。",[str(practice.role),str(practice.name)]))
	_label(self,"滚动查看完整回响",Vector2(220,716),Vector2(390,32),17,MUTED)
	var back:=preload("res://scripts/ui/components/solmere_button.gd").new()
	back.text=LocalizationSystem.text("返回主菜单")
	back.position=Vector2(670,760)
	back.size=Vector2(260,55)
	back.pressed.connect(SceneRouter.main_menu)
	add_child(back)
	back.grab_focus()

func _recognition_text(row: Dictionary) -> String:
	var name:=str(row.name)
	var source: String={
		"assumes_same_person":"%s 仍把两次相遇当作同一个人的不同状态。",
		"notices_inconsistency":"%s 已经察觉两边的生活细节无法完全重合。",
		"suspects_two_people":"%s 开始把那些差异理解成两个人的生活。",
		"identity_confirmed":"%s 已经把 A 与 B 作为两个人记住。",
	}.get(str(row.stage),"%s 还没有足够的相处去理解这件事。")
	var base:=LocalizationSystem.text_with_values(source,[name])
	var response: Dictionary=row.get("response",{})
	if response.is_empty(): return base
	var echo_source: String="%s 当场说明了误认。" if str(response.choice)=="clarify" else "%s 选择等两个人见面时再说明。"
	var echo:=LocalizationSystem.text_with_values(echo_source,[str(response.role)])
	return base+" "+echo

func _section(parent: VBoxContainer, text_value: String) -> void:
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=10
	parent.add_child(spacer)
	var label:=_label(parent,text_value,Vector2.ZERO,Vector2(1100,42),27,INK)
	label.add_theme_constant_override("outline_size",2)
	label.add_theme_color_override("font_outline_color",Color("faf7ee"))

func _line(parent: VBoxContainer, text_value: String) -> void:
	var line:=_label(parent,text_value,Vector2.ZERO,Vector2(1080,0),22,MUTED)
	line.custom_minimum_size=Vector2(1080,34)
	line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _draw() -> void:
	draw_texture_rect(BACKGROUND,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color("faf7ee",.9))

func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label:=Label.new()
	label.text=LocalizationSystem.text(text_value)
	label.position=at
	label.size=label_size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
