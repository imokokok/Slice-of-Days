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
	var router=root.get_node("SceneRouter")
	var wait_frames:=0
	while router.active_space_id!="home_a" or router.transitioning:
		await process_frame; wait_frames+=1
		if wait_frames>1200: check(false,"23:59 curfew reaches the actual home interior"); quit(1); return
	check(state.current_minute==1439 and state.current_day==1,"23:59 arrives home without skipping the last minute")
	state.advance_world_clock(4.0)
	await create_timer(.8).timeout
	check(current_scene.scene_file_path.ends_with("chapter_transition.tscn"),"Next clock minute is midnight and starts the overnight transition")
	await create_timer(3.5).timeout
	check(state.current_day == 2 and state.current_role == "B", "Midnight advances once to Day 2, B's perspective")
	check(state.current_minute < 1320 and not state.shared_state.get("sleep_pending", false), "Next morning clears the rollover latch")
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "Next day resumes playable exploration")
	print("MIDNIGHT ROLLOVER PASS" if failures == 0 else "MIDNIGHT ROLLOVER FAIL")
	quit(failures)
