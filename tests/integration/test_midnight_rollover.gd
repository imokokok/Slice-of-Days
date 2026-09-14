extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	state.current_minute = 1438
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.5).timeout
	check(state.current_day == 1 and not state.shared_state.get("sleep_pending", false), "23:58 must remain on the current day")
	state.spend_time(1)
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path.ends_with("chapter_transition.tscn"), "23:59 automatically starts the night transition")
	await create_timer(3.5).timeout
	check(state.current_day == 2 and state.current_role == "B", "Midnight advances once to the authored next role")
	check(state.current_minute < 1439 and not state.shared_state.get("sleep_pending", false), "Next morning clears the rollover latch")
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "Next day resumes playable exploration")
	print("MIDNIGHT ROLLOVER PASS" if failures == 0 else "MIDNIGHT ROLLOVER FAIL")
	quit(failures)
