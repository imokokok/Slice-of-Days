extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var requested_module := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--module="):
			requested_module = argument.trim_prefix("--module=")
	if requested_module == "archives":
		await _exercise("archives", ["undated_photo", "tide_log", "station_ticket"], "build_cross_index", -1.0)
		print("NATIVE_MODULE_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
		quit(failures)
		return
	await _exercise("cooking", ["lemon", "bread", "tomato"], "careful_menu", 0.58)
	await _exercise("sound_sampling", ["rain_awning", "bus_brake", "distant_flute"], "planned_route", -1.0)
	await _exercise("photography", ["reflection", "people"], "photograph_reflection", 0.5)
	await _exercise("optical_illusion", ["photo_door", "map_door"], "preserve_contradiction", 0.35)
	await _exercise("archives", ["undated_photo", "tide_log", "station_ticket"], "build_cross_index", -1.0)
	print("NATIVE_MODULE_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)


func _exercise(module_id: String, tokens: Array[String], choice_id: String, slider_value: float) -> void:
	var game_state = root.get_node("GameState")
	var gameplay = root.get_node("GameplayModuleSystem")
	game_state.begin_new_game("A")
	game_state.current_location = {
		"cooking": "night_market",
		"sound_sampling": "record_store",
		"photography": "print_shop",
		"optical_illusion": "old_station",
		"archives": "library",
	}.get(module_id, "residence")
	game_state.current_minute = 540
	game_state.commit_active_role_state()
	check(gameplay.begin_session(module_id, "native_test_%s" % module_id), "%s should begin" % module_id)
	var packed = load("res://scenes/native_module_game.tscn")
	check(packed is PackedScene, "%s dedicated scene should parse" % module_id)
	if not packed is PackedScene:
		gameplay.cancel_session()
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.module_id == module_id, "%s scene should resolve its pending module" % module_id)
	for token_id in tokens:
		scene._toggle_token(token_id)
	if slider_value >= 0.0:
		scene.value_slider.value = slider_value
	scene._perform_primary_action()
	if module_id == "sound_sampling":
		await create_timer(2.6).timeout
	check(scene.stage_ready, "%s mechanic should reach its completion gate" % module_id)
	scene._complete_choice(choice_id)
	check(scene.completed, "%s should complete through the gameplay result contract" % module_id)
	check(gameplay.pending_module_id().is_empty(), "%s completion should clear its pending session" % module_id)
	check(bool(gameplay.state_for(module_id).get("completed", false)), "%s result should persist in role state" % module_id)
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/solmere-%s.png" % module_id)
	scene.queue_free()
	await process_frame
