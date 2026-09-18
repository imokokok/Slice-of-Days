extends PanelContainer
var report: Label
func _ready() -> void:
	position=Vector2(20,80)
	size=Vector2(610,680)
	var stack:=VBoxContainer.new()
	add_child(stack)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(570,450)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	report=Label.new()
	report.custom_minimum_size=Vector2(550,360)
	report.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	report.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	report.add_theme_font_size_override("font_size",16)
	scroll.add_child(report)
	var voice:=Button.new()
	voice.text=LocalizationSystem.text("重试当前心声语境（保留冷却与界面检查）")
	voice.pressed.connect(func()->void:
		MetaExperience.request_thought(MetaExperience.voice_context,MetaExperience.deterministic_test_mode))
	stack.add_child(voice)
	var fixed := CheckBox.new()
	fixed.text = LocalizationSystem.text("验收点固定候选（保留冷却、一次性记录）")
	fixed.button_pressed = MetaExperience.deterministic_test_mode
	fixed.toggled.connect(func(value: bool) -> void: MetaExperience.deterministic_test_mode = value)
	stack.add_child(fixed)
	var burst:=Button.new()
	burst.text=LocalizationSystem.text("Force Marginalia Burst（仍检查占用）")
	burst.pressed.connect(func()->void:
		for layer in get_tree().get_nodes_in_group("marginalia_layers"):
			var stage=layer.stage_node()
			if is_instance_valid(stage) and layer.evaluate(stage).eligible:layer.begin_burst())
	stack.add_child(burst)
	var close:=Button.new()
	close.text=LocalizationSystem.text("关闭 · F8")
	close.pressed.connect(queue_free)
	stack.add_child(close)
func _process(_delta: float) -> void:
	var info: Dictionary=MetaExperience.voice_debug.duplicate(true)
	var now := Time.get_unix_time_from_system()
	info["global_remaining"]=MetaExperience.voice_cooldown_remaining()
	info["faculty_remaining"]={}
	var voice_state := MetaExperience._voice_state()
	for faculty in voice_state.faculties:
		info.faculty_remaining[faculty]=maxf(0,float(MetaExperience.catalog.timing.voice_faculty_seconds)-(now-float(voice_state.faculties[faculty])))
	report.text=LocalizationSystem.text("心声\n"+JSON.stringify(info,"  ")+"\n\n地点留言\n"+JSON.stringify(MetaExperience.marginalia_debug,"  "))
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("GameplayShell"):
		report.text += LocalizationSystem.text("\n\n场景提示\n")+JSON.stringify(scene.get_node("GameplayShell").hint_debug,"  ")
		var audit := ResidencySystem.audit()
		var s := ResidencySystem.state()
		report.text += LocalizationSystem.text("\n\n档案\n")+JSON.stringify({"role":GameState.current_role,"day":GameState.current_day,"pages":audit.pages_complete,"marks":audit.recognitions,"missing":audit.missing,"materials":s.materials.size(),"filed":s.filing.size(),"submitted":not s.submitted.is_empty()},"  ")
