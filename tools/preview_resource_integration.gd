extends SceneTree
## Native-window review fixture. Requires isolated saves; never edits a player's journey.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var view := "menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view=arg.trim_prefix("--view=")
	root.title="Solmere · 资源适配验收 · "+view
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if view=="menu": change_scene_to_file("res://scenes/main_menu.tscn"); return
	var gs=root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	gs.switch_to_role("B",2,true); gs.current_location="night_market"; gs.current_minute=660
	gs.inventory={"lemon":2,"bread":2,"cheese":2,"herbs":2,"tomato":2,"star_salt":2}
	if view=="kitchen":
		root.get_node("GameplayModuleSystem").begin_session("cooking","resource_review")
		change_scene_to_file("res://scenes/native_module_game.tscn")
	else:
		change_scene_to_file("res://scenes/town_day.tscn")
		await create_timer(.7).timeout
		var shell=current_scene.get_node("GameplayShell")
		if view=="recorder": shell.open_tool("recorder")
		elif view=="studio_intake":
			gs.current_location="record_store"
			var recorder=load("res://scenes/town_sound/Recorder.tscn").instantiate(); recorder.shop_mode=true; current_scene.add_child(recorder)
		elif view=="household": current_scene.add_child(load("res://scripts/ui/components/household_panel.gd").new())
		elif view=="confirmation":
			var sheet=load("res://scripts/ui/components/confirm_sheet.gd").new()
			sheet.heading="确认这次操作"; sheet.description="很长的操作说明也应当完整留在纸页里面。可以向下滚动，确认和取消的位置始终不变。\n\n".repeat(10)+"这是最后一行。"; sheet.confirm_text="确认并继续"
			root.add_child(sheet); sheet.accepted.connect(sheet.queue_free)
		elif view=="recipe": root.add_child(load("res://scripts/ui/recipe_book_panel.gd").new())
		elif view=="shop":
			var shop=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="grocery"; root.add_child(shop)
		else: shell.open_paper(view)
