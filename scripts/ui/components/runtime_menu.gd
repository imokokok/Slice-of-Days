extends Control
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var owner_ui: Control
var settings := false
func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().paused=true
	var box := VBoxContainer.new(); box.position=Vector2(180,170); box.size=Vector2(435,450)
	box.add_theme_constant_override("separation",13); add_child(box)
	if not settings:
		for row in [["继续","resume"],["设置","settings"],["保存","save"],["返回主菜单","menu"]]:
			_add_button(box,str(row[0]),_action.bind(str(row[1])))
	else:
		for row in [["主音量","master_volume"],["音乐","music_volume"],["音效","sound_effects_volume"]]:
			var title := Label.new(); title.text=str(row[0])+"    %d%%"%int(SettingsSystem.values[row[1]]); title.add_theme_color_override("font_color",Color("fffaf0")); box.add_child(title)
			var slider := HSlider.new(); slider.name=str(row[1]); slider.min_value=0; slider.max_value=100; slider.step=1
			slider.value=float(SettingsSystem.values[row[1]]); slider.custom_minimum_size=Vector2(500,35); box.add_child(slider)
			slider.value_changed.connect(func(value: float) -> void: SettingsSystem.call("set_"+str(row[1]),value); title.text=str(row[0])+"    %d%%"%int(value))
		_add_button(box,"显示模式："+("全屏" if SettingsSystem.fullscreen() else "窗口"),func() -> void: SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen()); owner_ui.build())
		_add_button(box,"减弱动效："+("开" if SettingsSystem.reduced_motion() else "关"),func() -> void: SettingsSystem.set_reduced_motion(not SettingsSystem.reduced_motion()); owner_ui.build())
		_add_button(box,"返回",_action.bind("pause"))
	box.get_child(1 if settings else 0).grab_focus()
	var logo := Label.new(); logo.text="Solmere"; logo.position=Vector2(180,48); logo.add_theme_font_size_override("font_size",61)
	var script_font := SystemFont.new(); script_font.font_names=PackedStringArray(["Segoe Script"]); logo.add_theme_font_override("font",script_font); logo.add_theme_color_override("font_color",Color("fffaf0")); add_child(logo)
	PALETTE.words(self,TravelSystem.location_name(GameState.current_location),Vector2(922,589),300,24,PALETTE.CREAM)
	PALETTE.words(self,CoreLoopSystem.day_stamp()+"  ·  "+GameState.clock_text(),Vector2(922,632),300,17,PALETTE.CREAM)
	var coast := preload("res://scripts/ui/components/interface_art.gd").new(); coast.position=Vector2(966,458); coast.size=Vector2(185,94); add_child(coast)
func _add_button(parent: Node, title: String, action: Callable) -> void:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.variant="pause"; b.text=title; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size=Vector2(470,56 if settings else 76); parent.add_child(b); b.add_theme_font_size_override("font_size",23 if settings else 29); b.pressed.connect(action)
func _action(action: String) -> void:
	match action:
		"resume": owner_ui.close()
		"pause","settings": owner_ui.mode=action; owner_ui.build()
		"save":
			if SaveManager.save_or_report("保存失败"):
				owner_ui.feedback.text="已保存"
				var shell := owner_ui.get_parent()
				if shell.has_method("_camera_source") and DisplayServer.get_name()!="headless": SaveManager.save_thumbnail(await shell._camera_source())
			else: owner_ui.feedback.text=SaveManager.last_error
		"menu":
			if SaveManager.save_or_report("保存失败"):
				get_tree().paused=false; SceneRouter.main_menu(); owner_ui.queue_free()
