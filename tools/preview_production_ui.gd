extends SceneTree
## A real, separate new game for visual QA. Normal save slots are untouched.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs := root.get_node("GameState")
	gs.current_location="produce_stall"; gs.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.7).timeout
	current_scene.street.player_x=current_scene._world_x(current_scene.street_order.find(gs.current_location),900)
	current_scene._on_walk(current_scene.street.player_x); current_scene._refresh()
	await process_frame; await process_frame
	DisplayServer.window_set_title("Solmere · 生活与回音（最新试玩）")
