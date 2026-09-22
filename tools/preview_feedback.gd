extends SceneTree
## Real production panels in a disposable save, for visual QA.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var mode := "produce"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="): mode=arg.get_slice("=",1)
	root.get_node("ChapterSystem").start_new_game("A")
	var gs=root.get_node("GameState"); gs.current_location="produce_stall"; gs.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.6).timeout
	current_scene.street.player_x=current_scene._world_x(current_scene.street_order.find(gs.current_location),900)
	current_scene._on_walk(current_scene.street.player_x); current_scene._refresh()
	if mode in ["produce","grocery"]:
		var shop=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="produce_stall" if mode=="produce" else "grocery"; current_scene.add_child(shop)
	elif mode=="recipe":
		var book=load("res://scripts/ui/recipe_book_panel.gd").new(); current_scene.add_child(book); book._begin_draft()
	elif mode=="fish":
		gs.current_location="port"
		var fish=load("res://scripts/core/coastal_fishing.gd")
		var cast: Dictionary=fish.begin_cast()
		if cast.ok: fish.land(cast.fish); fish.resolve(false)
		current_scene.add_child(load("res://scripts/ui/fish_journal.gd").new())
	elif mode=="map":
		var panel=load("res://scripts/residency/map_paper.gd").new(); panel.position=Vector2(158,125); current_scene.add_child(panel)
	DisplayServer.window_set_title("Solmere · 反馈验收 · "+mode)
