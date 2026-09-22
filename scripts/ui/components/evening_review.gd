extends Control
var reflection: TextEdit
var feedback: Label
func _ready() -> void:
	theme=preload("res://art/ui/solmere_ui.tres")
	add_to_group("meta_modal"); add_to_group("evening_review")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color=Color("16364b",.7); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	var paper := Panel.new(); paper.position=Vector2(320,120); paper.size=Vector2(960,650)
	var face := StyleBoxFlat.new(); face.bg_color=Color("f9f5e9"); face.set_corner_radius_all(12); paper.add_theme_stylebox_override("panel",face); add_child(paper)
	_label(paper,"Day %02d · 灯还亮着"%GameState.current_day,Vector2(45,30),Vector2(800,60),32)
	_label(paper,"今天留下的东西",Vector2(45,112),Vector2(400,35),21)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(45,155); scroll.size=Vector2(400,300); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; paper.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(rows)
	for item in ResidencySystem.state().materials.values():
		if int(item.get("day",0))!=GameState.current_day or str(item.kind)=="official" or str(item.get("source",""))=="walk": continue
		var note := Label.new(); note.text=str(item.title); note.custom_minimum_size=Vector2(370,44); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; rows.add_child(note)
	if rows.get_child_count()==0: _label(paper,"还没有收进来的材料。\n也可以先写下一件小事。",Vector2(45,190),Vector2(390,110),22)
	reflection=TextEdit.new(); reflection.position=Vector2(490,148); reflection.size=Vector2(420,310); reflection.text=str(CoreLoopSystem.day_state().get("reflection_draft",CoreLoopSystem.day_state().reflection)); reflection.placeholder_text="今天，有哪一刻想留住？\n\n未完成的事情可以明天继续。"; paper.add_child(reflection)
	reflection.text_changed.connect(func() -> void: CoreLoopSystem.day_state()["reflection_draft"]=reflection.text)
	feedback=_label(paper,"记录可以自由整理，不影响明天。",Vector2(45,470),Vector2(850,54),19)
	_button(paper,"收好，今晚先休息",Vector2(45,551),Vector2(390,54),_rest)
	_button(paper,"先收起",Vector2(520,551),Vector2(390,54),_dismiss)
	reflection.grab_focus()
func _label(parent: Node, text: String, at: Vector2, bounds: Vector2, size: int) -> Label:
	var label := Label.new(); label.text=text; label.position=at; label.size=bounds; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",size); parent.add_child(label); return label
func _button(parent: Node, text: String, at: Vector2, bounds: Vector2, action: Callable) -> void:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.variant="outlined"; button.text=text; button.position=at; button.size=bounds; parent.add_child(button); button.pressed.connect(action)
func _rest() -> void:
	var check := ChapterSystem.can_end_day()
	if not bool(check.ok): feedback.text=str(check.reason); return
	var result := CoreLoopSystem.review_day(reflection.text)
	feedback.text=str(result.message)
	if not result.ok: return
	queue_free()
	ChapterSystem.sleep_at_home.call_deferred()

func _portfolio() -> void:
	var result := CoreLoopSystem.review_day(reflection.text); feedback.text=str(result.message)
	if not result.ok: return
	var shell := get_tree().current_scene.get_node_or_null("GameplayShell")
	queue_free()
	if shell!=null: shell.open_paper.call_deferred("organize")
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _dismiss(); get_viewport().set_input_as_handled()

func _dismiss() -> void:
	GameState.commit_active_role_state()
	if SaveManager.save_or_report("草稿未能保存，请重试收起"): queue_free()
func _extend() -> void:
	var result := CoreLoopSystem.extend_application(); feedback.text=str(result.message)
	if result.ok: queue_free()
