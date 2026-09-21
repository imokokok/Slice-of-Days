extends SceneTree
## A real playable new game; never touches the user's normal save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs := root.get_node("GameState")
	gs.current_location="park" if OS.get_cmdline_user_args().has("--fishing") else "cafe"
	gs.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.8).timeout
	var town=current_scene
	var kind := "fishing" if OS.get_cmdline_user_args().has("--fishing") else "shop"
	for spot in town.street.hotspots:
		if str(spot.get("kind",""))==kind:
			town.street.player_x=float(spot.x); break
	town.street.move_player(0,0); town._on_walk(town.street.player_x); town._refresh()
	await process_frame; await process_frame
	if OS.get_cmdline_user_args().has("--fishing"):
		town._show_pocket_panel(load("res://scripts/ui/coastal_fishing_panel.gd").new())
	else:
		var shop=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="grocery"
		town._show_pocket_panel(shop)
	DisplayServer.window_set_title("Solmere · 手绘生活（最新试玩）")
