extends SceneTree
var rows: Array=[]
var folder := "res://.runtime/ui-reference-review"
func _initialize(): call_deferred("run")
func settle():
	await process_frame; await process_frame; await create_timer(.3).timeout
func inspect(node: Node, page: String):
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is LineEdit or node is TextEdit or node is RichTextLabel):
		var text_value: String=str(node.text)
		if not text_value.is_empty():
			var c: Color=node.get_theme_color("font_color")
			var entry: Dictionary={"page":page,"path":str(node.get_path()),"text":text_value.left(100),"rect":str(node.get_global_rect()),"font_color":c.to_html(),"font_size":node.get_theme_font_size("font_size"),"minimum":str(node.get_combined_minimum_size())}
			if node is Button:
				var sb=node.get_theme_stylebox("normal")
				entry.style=sb.get_class(); entry.content= str(node.size-sb.get_minimum_size())
			if node is Label: entry.lines=node.get_line_count(); entry.visible_lines=node.get_visible_line_count()
			rows.append(entry)
	for child in node.get_children(): inspect(child,page)
func snap(page: String, target: Node):
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+page+".png"); inspect(target,page)
## Review screenshots and text bounds; this is not an aesthetic pass/fail oracle.
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder="res://.runtime/"+arg.trim_prefix("--folder=")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gs=root.get_node("GameState"); root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("B",2,true)
	gs.current_location="night_market"; gs.current_minute=660; gs.money=500; gs.inventory={"lemon":2,"bread":2,"cheese":2,"herbs":2,"tomato":2,"star_salt":2}
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	var shell=current_scene.get_node("GameplayShell")
	for mode in ["notebook","dossier","bag","day_schedule","gallery","sound_library","fieldbook","map","pause","settings"]:
		shell.open_paper(mode); await settle()
		await snap(mode,shell.overlay); shell.overlay.close(); await settle()
	for mode in ["recipe","recipe_editor","shop","procurement","confirm"]:
		var panel: Control
		if mode.begins_with("recipe"):
			panel=load("res://scripts/ui/recipe_book_panel.gd").new(); panel.ingredients=["lemon","bread","cheese"]
		elif mode=="shop": panel=load("res://scripts/ui/shop_panel.gd").new(); panel.shop_id="grocery"
		elif mode=="procurement": panel=load("res://scripts/ui/economy_paper.gd").new()
		else:
			panel=load("res://scripts/ui/components/confirm_sheet.gd").new(); panel.heading="确认这次操作"; panel.description="这里是一段比较长的操作说明，应该完整显示，而不是被新导入的纸页或按钮遮挡。\n\n这次操作会使用真实食材，并保留出餐记录。"; panel.confirm_text="确认并继续"
		current_scene.add_child(panel); await settle()
		if mode=="recipe_editor": panel._begin_draft(); await settle()
		await snap(mode,panel); panel.queue_free(); await settle()
	current_scene._show_line("居民","海风把门前的纸页吹开了。等我把这一行写完，再陪你去街角看看。".repeat(12)); await snap("long_dialogue",current_scene.event_panel)
	current_scene.event_overlay.hide()
	gs.current_location="record_store"
	var recorder=load("res://scenes/town_sound/Recorder.tscn").instantiate(); recorder.shop_mode=true; current_scene.add_child(recorder); await snap("studio_recorder",recorder)
	recorder.record_button.pressed.emit(); root.get_node("WorldSound").play_detail(); await create_timer(1.0).timeout; await snap("studio_recording",recorder)
	recorder.stop_button.pressed.emit(); await settle(); recorder.name_input.text="海风与街角"; recorder.save_button.pressed.emit(); await snap("studio_saved",recorder)
	var controls=recorder.find_children("*","Button",true,false)
	for b in controls:
		if b.text.contains("STUDIO"): b.pressed.emit(); break
	await snap("studio",recorder)
	for b in recorder.find_children("*","Button",true,false):
		if b.get_script()!=null and b.get_script().resource_path.ends_with("SampleDragButton.gd"): b.pressed.emit(); break
	await snap("studio_filled",recorder)
	recorder.queue_free(); await settle()
	shell.open_paper("sound_library"); await snap("sound_library_saved",shell.overlay); shell.overlay.close(); await settle()
	shell.open_paper("dossier"); await settle(); shell.overlay.find_child("ArchiveSection_days",true,false).pressed.emit(); await snap("collage",shell.overlay)
	shell.overlay.find_child("AddCollageMaterial",true,false).pressed.emit(); await snap("collage_materials",shell.overlay); shell.overlay.close(); await settle()
	var landing=load("res://scripts/ui/components/household_panel.gd").new(); current_scene.add_child(landing); await snap("household",landing); landing.queue_free(); await settle()
	shell.open_tool("recorder"); await snap("mobile_recorder",current_scene)
	if is_instance_valid(shell.tool): shell.tool.queue_free()
	await settle()
	var film=root.get_node("FilmSystem"); film.state().camera_owned=true; film._new_roll("normal",true)
	shell.open_tool("camera"); await snap("camera",current_scene)
	if is_instance_valid(shell.tool): shell.tool.queue_free()
	await settle()
	gs.current_location="port"
	var fishing=load("res://scripts/ui/coastal_fishing_panel.gd").new(); current_scene.add_child(fishing); await snap("fishing",fishing); fishing._open_journal(); await snap("fish_journal",fishing); fishing.queue_free(); await settle()
	gs.current_location="night_market"; root.get_node("GameplayModuleSystem").begin_session("cooking","ui_review")
	change_scene_to_file("res://scenes/native_module_game.tscn"); await settle(); await snap("kitchen",current_scene)
	gs.current_location="handcraft_shop"
	change_scene_to_file("res://extensions/collage_letter/workshop/Workshop.tscn"); await create_timer(2).timeout; await snap("letter_desk",current_scene)
	current_scene.open_browser(); await snap("letter_materials",current_scene)
	for module: String in ["tarot","chess","contemplation"]:
		root.get_node("GameplayModuleSystem").cancel_session()
		gs.switch_to_role("A" if module=="contemplation" else "B",3 if module=="contemplation" else 4,true)
		gs.current_location={"tarot":"tarot_stall","chess":"chess_stall","contemplation":"park"}[module]; gs.current_minute=1320 if module=="contemplation" else 720
		if root.get_node("SceneRouter").gameplay_module(module,"ui_review"):
			await create_timer(2).timeout; await snap(module,current_scene)
			if module=="tarot": current_scene.experience.close_modal(); await snap("tarot_table",current_scene)
		else: push_error("Review entry unavailable: "+module)
	change_scene_to_file("res://scenes/main_menu.tscn"); await settle(); await snap("menu",current_scene)
	current_scene._show_settings(); await snap("menu_settings",current_scene)
	var file=FileAccess.open(folder+"/text.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"  ")); file.close()
	var assets=load("res://scripts/ui/production_assets.gd")
	file=FileAccess.open(folder+"/loaded_assets.json",FileAccess.WRITE); file.store_string(JSON.stringify({"textures":assets.textures.keys(),"sounds":assets.sounds.keys()},"  ")); file.close()
	print("READABILITY_CAPTURE_COMPLETE ", rows.size()); quit()
