extends SceneTree
## Interactive review of the production chess host using an isolated save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "--isolated-save" in OS.get_cmdline_user_args():
		push_error("Chess preview requires -- --isolated-save so it cannot change a player's journey.")
		quit(2); return
	var settings = root.get_node("SettingsSystem")
	settings.values.language = "zh_CN"; settings.apply_settings()
	root.get_node("ChapterSystem").start_new_game()
	var state = root.get_node("GameState")
	state.switch_to_role("B", 4, true)
	state.current_minute = 720; state.current_location = "chess_stall"
	var router = root.get_node("SceneRouter")
	if not router.gameplay_module("chess", "street:chess_stall"):
		push_error("Could not open the production chess host.")
		quit(1); return
	await process_frame
	while router.transitioning: await process_frame
	DisplayServer.window_set_title("Solmere · 棋桌与手绘界面（试玩）")
