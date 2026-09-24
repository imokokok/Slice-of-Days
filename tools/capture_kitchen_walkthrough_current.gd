extends SceneTree
## Capture the live kitchen flow as JPEG frames for an MP4 walkthrough.

var capture_fps := 24
var frame_number := 0
var capture_dir := ""
var caption: Label

func _initialize() -> void:
	call_deferred("run")

func pause(seconds: float) -> void:
	for frame in maxi(1,roundi(seconds*float(capture_fps))):
		await process_frame
		RenderingServer.force_draw()
		var path := "%s/frame_%05d.jpg" % [capture_dir,frame_number]
		var error := root.get_texture().get_image().save_jpg(path,0.86)
		if error != OK:
			push_error("Could not save video frame: " + path)
			quit(6)
			return
		frame_number+=1

func set_caption(message: String) -> void:
	caption.text=message

func add_caption(kitchen: Control) -> void:
	var panel := Panel.new()
	panel.position=Vector2(501,28)
	panel.size=Vector2(568,50)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color=Color("fff8e9",0.97)
	style.border_color=Color("8c7363")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",style)
	kitchen.add_child(panel)
	caption=Label.new()
	caption.position=Vector2(8,5)
	caption.size=Vector2(552,40)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",21)
	caption.add_theme_color_override("font_color",Color("39494a"))
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(caption)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-fps="):
			capture_fps=clampi(int(argument.trim_prefix("--capture-fps=")),12,30)
		elif argument.begins_with("--capture-dir="):
			capture_dir=argument.trim_prefix("--capture-dir=")
	if capture_dir.is_empty(): capture_dir=ProjectSettings.globalize_path("res://.runtime/kitchen-video-frames")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("ChapterSystem").start_new_game()
	var state: Node=root.get_node("GameState")
	state.switch_to_role("B",2,true)
	state.current_location="night_market"
	state.current_minute=660
	state.money=500
	state.inventory={"tomato":2,"bread":2,"cheese":2}
	state.commit_active_role_state()
	if not root.get_node("GameplayModuleSystem").begin_session("cooking","kitchen_video"):
		push_error("Kitchen video could not start a cooking session")
		quit(3)
		return
	var kitchen: Control=load("res://scenes/native_module_game.tscn").instantiate()
	root.add_child(kitchen)
	await process_frame
	add_caption(kitchen)
	set_caption("厨房全流程 · 从选材到出餐")
	await pause(2.2)
	set_caption("菜谱默认收起 · 工作台上方只给当前步骤提示")
	await pause(1.5)
	kitchen._open_recipe_book()
	await pause(2.0)
	var intro_books: Array=get_nodes_in_group("recipe_book")
	if intro_books.is_empty():
		push_error("Kitchen video could not open the optional recipe book")
		quit(7)
		return
	intro_books.back()._close()
	await pause(0.8)
	set_caption("① 选材 · 三样材料决定今天的料理")
	for id in ["tomato","bread","cheese"]:
		kitchen.token_buttons[id].pressed.emit()
		await pause(1.0)
	await pause(1.0)
	kitchen.primary_button.pressed.emit()
	set_caption("② 备料 · 完整食材先留在案板上")
	await pause(1.8)
	var preparations := [["tomato",0],["bread",1],["cheese",0]]
	for prep in preparations:
		var id: String=prep[0]
		var option: int=prep[1]
		kitchen.prep_option_buttons[option].pressed.emit()
		set_caption("② 备料 · %s：按所选方式逐步处理" % kitchen._token_label(id))
		await pause(0.9)
		while not kitchen.prep_board.target_id.is_empty():
			kitchen.prep_board.pressed.emit()
			await pause(0.9)
		await pause(1.0)
	set_caption("③ 下锅 · 按食材调整火候和顺序")
	await pause(1.0)
	for id in ["tomato","bread","cheese"]:
		var token: Dictionary=kitchen._prepared_token(id)
		var window: Array=token.get("heat_window",[0.4,0.7])
		kitchen.value_slider.value=(float(window[0])+float(window[1]))*0.5
		kitchen.token_buttons[id].pressed.emit()
		await pause(1.0)
		kitchen.illustrated_pot.pressed.emit()
		await pause(2.0)
	set_caption("④ 看火 · 锅里的食材随温度和时间上色")
	kitchen.value_slider.value=0.78
	await pause(5.0)
	set_caption("⑤ 翻拌 · 两种手法回应当前锅温")
	kitchen.value_slider.value=0.65
	kitchen.stir_buttons.gentle.pressed.emit()
	await pause(2.0)
	kitchen.value_slider.value=0.56
	kitchen.stir_buttons.fold.pressed.emit()
	await pause(3.0)
	kitchen.primary_button.pressed.emit()
	set_caption("⑥ 尝味 · 根据这锅食材决定收尾")
	await pause(2.2)
	var seasoning: String=preload("res://scripts/core/cooking_mechanics.gd").seasoning_target(kitchen._selected_token_data())
	if seasoning!="rest": kitchen.seasoning_buttons["wasabi" if seasoning=="brighten" else seasoning].pressed.emit()
	kitchen.seasoning_buttons.pepper.pressed.emit()
	kitchen.primary_button.pressed.emit()
	await pause(1.8)
	set_caption("⑦ 装盘 · 预览留白、丰盛与分食")
	for mode in ["space","generous","share"]:
		kitchen._preview_plating(mode)
		await pause(1.5)
	kitchen.plating_buttons.share.pressed.emit()
	await pause(2.6)
	set_caption("⑧ 出餐 · 确认后留下本次料理记录")
	kitchen.choice_buttons.improvise.pressed.emit()
	await pause(2.0)
	var sheets: Array=get_nodes_in_group("native_confirmation")
	if sheets.is_empty():
		push_error("Kitchen video did not reach serving confirmation")
		quit(4)
		return
	sheets.back().accepted.emit()
	await pause(3.3)
	if not kitchen.completed:
		push_error("Kitchen video failed to serve its dish")
		quit(5)
		return
	set_caption("⑨ 菜谱 · 本次做法和店主回应被记录")
	kitchen._open_recipe_book()
	await pause(1.5)
	var books: Array=get_nodes_in_group("recipe_book")
	if not books.is_empty():
		books.back()._switch("shared")
		await pause(3.0)
	print("KITCHEN_WALKTHROUGH_COMPLETE frames=",frame_number," fps=",capture_fps)
	quit()
