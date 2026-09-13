extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state = root.get_node("GameState")
	state.begin_new_game()
	state.advance_world_clock(60.0)
	check(state.current_minute == 555, "60 real seconds must equal 15 game minutes")
	check(state.clock_text() == "09:15", "Clock must display hours and minutes only")
	state.advance_world_clock(3.5)
	check(state.current_minute == 555, "Partial minute must not change displayed time")
	var saved: Dictionary = state.to_save_data()
	state.begin_new_game()
	state.load_save_data(saved)
	state.advance_world_clock(0.5)
	check(state.current_minute == 556, "Save/load must preserve fractional clock progress")
	state.begin_new_game()
	for i in 3600: state.advance_world_clock(1.0 / 60.0)
	check(state.current_minute == 555, "Frame-sized ticks must retain the exact 15:1 rate")
	state.current_minute = 1259
	state.advance_world_clock(4.0)
	check(state.clock_text() == "21:00", "Natural time must reach the lookout opening")
	print("WORLD CLOCK PASS" if failures == 0 else "WORLD CLOCK FAIL")
	quit(failures)
