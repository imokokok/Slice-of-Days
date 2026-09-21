extends Control
var owner_ui: Control
var settings := false
func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().paused=true
	var box := VBoxContainer.new(); box.position=Vector2(410,155); box.size=Vector2(520,440)
	box.add_theme_constant_override("separation",18); add_child(box)
	if not settings:
		for row in [["继续","resume"],["设置","settings"],["保存","save"],["返回主菜单","menu"]]:
			_add_button(box,str(row[0]),_action.bind(str(row[1])))
	else:
		for row in [["主音量","master_volume"],["音乐","music_volume"],["音效","sound_effects_volume"]]:
			var title := Label.new(); title.text=str(row[0]); box.add_child(title)
			var slider := HSlider.new(); slider.name=str(row[1]); slider.min_value=0; slider.max_value=100; slider.step=1
			slider.value=float(SettingsSystem.values[row[1]]); slider.custom_minimum_size=Vector2(500,35); box.add_child(slider)
			slider.value_changed.connect(func(value: float) -> void: SettingsSystem.call("set_"+str(row[1]),value))
		_add_button(box,"返回",_action.bind("pause"))
	box.get_child(1 if settings else 0).grab_focus()
func _add_button(parent: Node, title: String, action: Callable) -> void:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.text=title; b.custom_minimum_size=Vector2(500,55); parent.add_child(b); b.pressed.connect(action)
func _action(action: String) -> void:
	match action:
		"resume": owner_ui.close()
		"pause","settings": owner_ui.mode=action; owner_ui.build()
		"save": owner_ui.feedback.text="已保存" if SaveManager.save_or_report("保存失败") else SaveManager.last_error
		"menu":
			if SaveManager.save_or_report("保存失败"):
				get_tree().paused=false; SceneRouter.main_menu(); owner_ui.queue_free()
