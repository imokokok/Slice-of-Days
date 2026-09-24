extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	if OS.get_cmdline_user_args().has("--screenshots"):
		root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.size=Vector2i(1600,900)
	var requested_module := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--module="):
			requested_module = argument.trim_prefix("--module=")
	if requested_module == "archives":
		await _exercise("archives", ["undated_photo", "tide_log", "station_ticket"], "build_cross_index", -1.0)
		print("NATIVE_MODULE_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
		quit(failures)
		return
	# The standalone kitchen fixture uses the restaurant pantry. Procurement
	# ingredients such as tomato are only available after the real buy/deliver
	# chain, which is covered by test_v3_economy.
	await _exercise("cooking", ["lemon", "bread", "cheese"], "careful_menu", 0.58)
	# Sound uses the real recorder and studio; see test_music_source_route.gd.
	await _exercise("photography", ["reflection", "people"], "photograph_reflection", 0.5)
	await _exercise("optical_illusion", ["photo_door", "map_door"], "preserve_contradiction", 0.35)
	await _exercise("archives", ["undated_photo", "tide_log", "station_ticket"], "build_cross_index", -1.0)
	print("NATIVE_MODULE_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)


func _exercise(module_id: String, tokens: Array[String], choice_id: String, slider_value: float) -> void:
	var game_state = root.get_node("GameState")
	var gameplay = root.get_node("GameplayModuleSystem")
	game_state.begin_new_game("B" if module_id=="cooking" else "A")
	game_state.current_location = {
		"cooking": "night_market",
		"sound_sampling": "record_store",
		"photography": "print_shop",
		"optical_illusion": "old_station",
		"archives": "library",
	}.get(module_id, "residence")
	game_state.current_minute = 600 if module_id=="cooking" else 540
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
	if module_id=="cooking":
		scene._perform_primary_action()
		check(scene.cooking_phase=="prep","Cooking should begin with hands-on preparation")
		for _step in tokens.size():
			scene._choose_prep_option(_step%2)
			while not scene.prep_board.target_id.is_empty(): scene.prep_board.pressed.emit()
		check(scene.cooking_phase=="cook","Prepared ingredients should move to the pan")
		for token_id in tokens:
			var token: Dictionary=scene._token_data(token_id)
			var window: Array=token.get("heat_window",[.42,.7])
			scene.value_slider.value=(float(window[0])+float(window[1]))*.5
			scene._toggle_token(token_id)
			scene._perform_primary_action()
		for style in ["gentle","fold"]:
			scene.value_slider.value=.58
			scene._stir(style)
		scene._perform_primary_action()
		check(scene.cooking_phase=="taste","The cook should decide when to taste after enough stirring")
		var seasoning: String=load("res://scripts/core/cooking_mechanics.gd").seasoning_target(scene._selected_token_data())
		if seasoning!="rest": scene._choose_seasoning("wasabi" if seasoning=="brighten" else seasoning)
		scene._finish_seasoning()
		scene._choose_plating("space")
	else:
		if slider_value >= 0.0:
			scene.value_slider.value = slider_value
		scene._perform_primary_action()
	if module_id == "sound_sampling":
		await create_timer(2.6).timeout
	check(scene.stage_ready, "%s mechanic should reach its completion gate" % module_id)
	if module_id=="cooking":
		var mechanic: Dictionary=scene._interaction_record().get("mechanic",{})
		check(int(mechanic.get("stir_count",0))==2,"Cooking should store the player-chosen stir count")
		check(str(mechanic.get("seasoning",""))!="","Cooking should store the tasting decision")
		check(str(mechanic.get("plating",""))!="","Cooking should store the plating decision")
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://.runtime/handmade-captures")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/handmade-captures/module-%s.png" % module_id)
	scene._complete_choice(choice_id)
	check(scene.completed, "%s should complete through the gameplay result contract" % module_id)
	check(gameplay.pending_module_id().is_empty(), "%s completion should clear its pending session" % module_id)
	check(bool(gameplay.state_for(module_id).get("completed", false)), "%s result should persist in role state" % module_id)
	scene.queue_free()
	await process_frame
