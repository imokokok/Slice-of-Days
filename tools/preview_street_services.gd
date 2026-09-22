extends SceneTree
## Isolated, real gameplay review; never replaces the user's normal save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs := root.get_node("GameState")
	var router := root.get_node("SceneRouter")
	gs.current_location="port" if OS.get_cmdline_user_args().has("--fishing") else "cafe" if OS.get_cmdline_user_args().has("--camera") else "bus_stop"
	gs.current_minute=660
	router.town_day(.01)
	await create_timer(.6).timeout
	var town=current_scene
	var local_x := 1190 if gs.current_location=="port" else 680 if gs.current_location=="cafe" else 1390
	town.street.player_x=town._world_x(town.current_index,local_x)
	town.street.move_player(0,0); town._on_walk(town.street.player_x); town._refresh()
	DisplayServer.window_set_title("Solmere · 路牌与海边（已同步最新版）")
