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
	var schedule = root.get_node("ScheduleSystem")
	root.get_node("ChapterSystem").start_new_game()
	for day in range(1, 8):
		for minute in [1320, 1380, 1438]:
			for place in ["town_entrance", "bus_stop", "record_store", "park"]:
				check(not schedule.residents_at(place, day, minute).is_empty(), "Late-night encounter at " + place)
	state.current_minute = 1350
	state.current_location = "record_store"
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.6).timeout
	var spots: Array = current_scene.street.hotspots
	check(spots.any(func(h): return h.kind == "person" and h.id == "xanni"), "Xanni remains outside the closed record shop")
	check(spots.any(func(h): return h.kind == "shop_closed"), "Late conversation does not reopen the store")
	check(not spots.any(func(h): return h.kind == "door"), "Shop interior stays closed")
	check(root.get_node("DialogueSystem").invitation_for("xanni").is_empty(), "After closing, Xanni chats without inviting the player into the shop game")
	var lines = root.get_node("DialogueSystem").reply("xanni", "greeting")
	check("".join(lines).contains("耳机"), "Night greeting reflects the current activity")
	print("LATE NIGHT PEOPLE PASS" if failures == 0 else "LATE NIGHT PEOPLE FAIL")
	quit(failures)
