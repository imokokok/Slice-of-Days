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
		elif view=="recipe": root.add_child(load("res://scripts/ui/recipe_book_panel.gd").new())
		elif view=="shop":
			var shop=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="grocery"; root.add_child(shop)
		else: shell.open_paper(view)
