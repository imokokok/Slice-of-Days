extends Control
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var owner_ui: Control
var settings := false

func _ready() -> void:
	name="CassetteMenu"
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().paused=true
	var art := TextureRect.new(); art.name="CassetteArtwork"
	art.texture=preload("res://art/ui/reference_paper/cassette.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.position=Vector2(0,-70); art.size=Vector2(1340,893.33)
	art.mouse_filter=MOUSE_FILTER_IGNORE; add_child(art)
	PALETTE.words(self,"声音与显示" if settings else "稍作停留",Vector2(133,133),355,30,PALETTE.INK)
	var title := PALETTE.words(self,"Solmere",Vector2(687,179),275,36,PALETTE.INK)
	var script_font := SystemFont.new(); script_font.font_names=PackedStringArray(["Segoe Script"]); title.add_theme_font_override("font",script_font)
	PALETTE.words(self,TravelSystem.location_name(GameState.current_location)+"  /  "+GameState.clock_text(),Vector2(990,179),220,18,PALETTE.INK)
	PALETTE.words(self,CoreLoopSystem.day_stamp()+" · 旅途磁带",Vector2(990,211),220,16,PALETTE.MUTED)
	var box := VBoxContainer.new(); box.position=Vector2(133,211); box.size=Vector2(348,410)
	box.add_theme_constant_override("separation",13); add_child(box)
	if not settings:
		for row in [["继续旅程","resume"],["设置","settings"],["保存进度","save"],["返回主菜单","menu"]]:
			_add_button(box,str(row[0]),_action.bind(str(row[1])),str(row[1]))
	else:
		for row in [["主音量","master_volume"],["音乐","music_volume"],["音效","sound_effects_volume"]]:
			var label := PALETTE.words(box,str(row[0])+"    %d%%"%int(SettingsSystem.values[row[1]]),Vector2.ZERO,348,19,PALETTE.INK)
			var slider := HSlider.new(); slider.name=str(row[1]); slider.min_value=0; slider.max_value=100; slider.step=1
			slider.value=float(SettingsSystem.values[row[1]]); slider.custom_minimum_size=Vector2(348,28); box.add_child(slider)
			slider.accessibility_name=LocalizationSystem.text(str(row[0]))
			slider.value_changed.connect(func(value: float) -> void: SettingsSystem.call("set_"+str(row[1]),value); label.text=LocalizationSystem.text(str(row[0]))+"    %d%%"%int(value))
		_add_button(box,"显示："+("全屏" if SettingsSystem.fullscreen() else "窗口"),func() -> void: SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen()); owner_ui.build(),"display")
		_add_button(box,"减弱动效："+("开" if SettingsSystem.reduced_motion() else "关"),func() -> void: SettingsSystem.set_reduced_motion(not SettingsSystem.reduced_motion()); owner_ui.build(),"motion")
		_add_button(box,"返回",_action.bind("pause"),"back")
	box.get_child(1 if settings else 0).grab_focus()
	owner_ui.feedback.position=Vector2(133,655)
	owner_ui.feedback.size=Vector2(355,48)
	owner_ui.feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	owner_ui.feedback.add_theme_color_override("font_color",PALETTE.INK)
	owner_ui.feedback.get_parent().move_child(owner_ui.feedback,-1)

func _add_button(parent: Node, title: String, action: Callable, id: String) -> void:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.name="Cassette_"+id; b.variant="outlined"; b.text=LocalizationSystem.text(title)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size=Vector2(348,45 if settings else 67)
	parent.add_child(b); b.add_theme_font_size_override("font_size",20 if settings else 24); b.pressed.connect(action)

func _action(action: String) -> void:
	match action:
		"resume": owner_ui.close()
		"pause","settings": owner_ui.mode=action; owner_ui.build()
		"save":
			if SaveManager.save_or_report("保存失败"):
				owner_ui.feedback.text=LocalizationSystem.text("已保存，可以安心歇一会。")
				var shell := owner_ui.get_parent()
				if shell.has_method("_camera_source") and DisplayServer.get_name()!="headless": SaveManager.save_thumbnail(await shell._camera_source())
			else: owner_ui.feedback.text=SaveManager.last_error
		"menu":
			if SaveManager.save_or_report("保存失败"):
				get_tree().paused=false; SceneRouter.main_menu(); owner_ui.queue_free()
