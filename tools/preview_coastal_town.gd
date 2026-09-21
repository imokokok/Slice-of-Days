extends SceneTree
## Real new-game preview, isolated from the player's normal save directory.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs := root.get_node("GameState")
	gs.current_location="produce_stall"; gs.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.7).timeout
	var town = current_scene
	town.street.player_x=town._place_center()+85
	town.street.move_player(0,0)
	town._on_walk(town.street.player_x); town._refresh()
	await process_frame; await process_frame
	DisplayServer.window_set_title("Solmere · 海岸夏日（最新试玩）")
