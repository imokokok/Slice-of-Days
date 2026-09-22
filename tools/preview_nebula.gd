extends SceneTree
## Optional local preview; run with isolated APPDATA and --isolated-save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Nebula preview requires an isolated save"); quit(1); return
	root.get_node("ChapterSystem").start_new_game()
	var state=root.get_node("GameState")
	state.current_location="park"; state.current_minute=1260
	root.get_node("SceneRouter").gameplay_module("contemplation","street:park")
	await create_timer(1.0).timeout
	DisplayServer.window_set_title("Solmere · 真实星云观测（最新试玩）")
