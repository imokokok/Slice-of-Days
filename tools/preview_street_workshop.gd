extends SceneTree
## Opens the actual street or hosted workshop in a separate review save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs := root.get_node("GameState")
	gs.current_location="produce_stall"; gs.current_minute=660
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.7).timeout
	var town = current_scene
	town.street.player_x=town._place_center()+75
	town.street.move_player(0,0)
	town._on_walk(town.street.player_x); town._refresh()
	if OS.get_cmdline_user_args().has("--workshop"):
		root.get_node("SceneRouter").gameplay_module("ghostwriting")
		await create_timer(.7).timeout
		DisplayServer.window_set_title("Solmere · 手绘书写台（最新试玩）")
	else: DisplayServer.window_set_title("Solmere · 街道与步行（最新试玩）")
