extends Control
var mode := "notes"
var page := 0
var content: Control

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("263a3b",0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = {"notes":"书店 · 便利贴墙","newspaper":"小镇报纸","zines":"寄售的小刊","revisions":"手账 · 改过的记忆","coverage":"开发检查 · 投稿覆盖"}.get(mode,mode)
	title.position = Vector2(100,50)
	title.add_theme_font_size_override("font_size",32)
	add_child(title)
	var close := Button.new()
	close.text = "收起"
	close.position = Vector2(1380,50)
	close.size = Vector2(120,45)
	add_child(close)
	close.pressed.connect(queue_free)
	content = Control.new()
	add_child(content)
	if mode == "notes":
		var more := Button.new()
		more.text = "看看底下还有什么"
		more.position = Vector2(1150,800)
		more.size = Vector2(350,50)
		add_child(more)
		more.pressed.connect(func() -> void: page += 1; _refresh())
		var input := LineEdit.new()
		input.position = Vector2(100,800)
		input.size = Vector2(690,50)
		input.max_length = 80
		input.placeholder_text = "留一句话，或一个书名"
		add_child(input)
		var submit := Button.new()
		submit.position = Vector2(810,800)
		submit.size = Vector2(150,50)
		submit.text = "贴上去"
		add_child(submit)
		submit.pressed.connect(func() -> void:
			var value := input.text.strip_edges()
			if value.is_empty(): return
			var rows: Array = GameState.shared_state.get("bookstore_notes",[]).duplicate(true)
			rows.append({"text":value,"byline":GameState.current_role,"kind":"留言","date":"第%d天" % GameState.current_day})
			GameState.shared_state["bookstore_notes"] = rows
			SaveManager.save_or_report("留言保存失败")
			page = floori((MetaExperience.catalog.notes.size()+rows.size()-1)/9.0)
			input.clear()
			_refresh())
	_refresh()

func _refresh() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	if mode == "notes":
		var rows := MetaExperience.notes_page(page)
		for i in rows.size():
			var note: Dictionary = rows[i]
			var card := Panel.new()
			card.position = Vector2(120+(i%3)*445,160+floori(i/3.0)*195)
			card.size = Vector2(455,205)
			card.rotation = [-0.018,0.012,-0.006][i%3]
			var style := StyleBoxFlat.new()
			style.bg_color = Color(["ded2b3","bac7ba","c2cdd3"][i%3])
			style.shadow_size = 7
			style.shadow_color = Color(0,0,0,0.22)
			card.add_theme_stylebox_override("panel",style)
			content.add_child(card)
			var label := Label.new()
			label.position = Vector2(24,20)
			label.size = Vector2(393,160)
			label.text = str(note.get("text",""))+"\n\n"+str(note.get("byline","匿名"))+" · "+str(note.get("date",""))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_color_override("font_color",Color("304144"))
			var handwriting := SystemFont.new()
			handwriting.font_names = PackedStringArray([["KaiTi"],["SimSun"],["Microsoft YaHei"]][i%3])
			label.add_theme_font_override("font",handwriting)
			label.add_theme_font_size_override("font_size",[21,20,19][i%3])
			card.add_child(label)
	else:
		var text := RichTextLabel.new()
		text.position = Vector2(150,160)
		text.size = Vector2(1270,570)
		text.add_theme_font_size_override("normal_font_size",24)
		text.bbcode_enabled = true
		text.scroll_active = true
		content.add_child(text)
		if mode == "coverage":
			var report := MetaExperience.coverage_report()
			text.text = "主角：%d\n现有核心 NPC：%d\n已核实真实投稿者：%d\n等待投稿的席位：%d\n\n匿名示例用于测试排版，独立保留。" % [report.protagonists,report.existing_npcs,report.verified_contributors,report.unassigned]
		elif mode == "revisions":
			for fact in KnowledgeSystem.facts():
				for revision in fact.get("revisions",[]):
					text.append_text("[color=#aebdb3][s]"+_escape(str(revision.text))+"[/s][/color]\n")
				text.append_text(_escape(str(fact.get("text","")))+(" ？" if float(fact.get("confidence",1)) < 0.8 else "")+"\n\n")
			if KnowledgeSystem.facts().is_empty(): text.text = "这里留给后来改过的记录。"
		else:
			for row in MetaExperience.catalog.get("newspaper" if mode == "newspaper" else "zines",[]):
				text.append_text("[b]"+_escape(str(row.get("kind",row.get("title",""))))+"[/b]\n"+_escape(str(row.text))+"\n\n")

func _escape(value: String) -> String:
	return value.replace("[","[lb]")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
