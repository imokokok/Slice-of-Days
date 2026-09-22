extends SceneTree
## Isolated preview of the actual street sign and travel flow.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var state=root.get_node("GameState")
	state.current_location="bus_stop"; state.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.7).timeout
	current_scene.street.player_x=1120; current_scene.street.move_player(0,0); current_scene._refresh()
	DisplayServer.window_set_title("Solmere · 小镇出行（最新试玩）")
