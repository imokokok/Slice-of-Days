extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game_state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	game_state.begin_new_game("A")
	game_state.current_location = "record_store"
	game_state.current_minute = 1080
	game_state.commit_active_role_state()
	router.active_space_id = "record_shop"
	var packed = load("res://scenes/interactive_space.tscn")
	check(packed is PackedScene, "Interactive space scene failed to load")
	var interior = packed.instantiate()
	root.add_child(interior)
	await process_frame
	check(str(interior.space.get("id", "")) == "record_shop", "Active interior did not resolve from the router")
	check(interior.objects.size() == 2, "Record shop should expose timeline and pressing-table hotspots")
	check(interior.object_buttons.size() == interior.objects.size(), "Every interior object should have a spatial hotspot")
	interior._select_object(1)
	check(interior.selected_index == 1, "Interior hotspot selection should move between objects")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/solmere-interactive-space.png")
	interior.queue_free()
	await process_frame

	var modules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay/modules.json"))
	for module in modules.get("modules", []):
		var extension_path := str(module.get("extension_scene_path", ""))
		if extension_path.is_empty():
			continue
		var extension = load(extension_path)
		check(extension is PackedScene, "Extension should load: %s" % extension_path)
		if extension is PackedScene:
			var instance = extension.instantiate()
			check(instance != null, "Extension should instantiate: %s" % extension_path)
			instance.free()

	var gameplay = root.get_node("GameplayModuleSystem")
	check(gameplay.begin_session("translation", "space:restaurant:market_memory"), "Extension host session should begin")
	var host = load("res://scenes/extension_host.tscn").instantiate()
	root.add_child(host)
	await process_frame
	await process_frame
	check(host.module_id == "translation", "Extension host should resolve the pending module")
	check(host.experience != null, "Extension host should instantiate the requested playable scene")
	check(host.complete_button != null and host.complete_button.disabled, "Extension completion should remain locked until its own goal is met")
	host.queue_free()
	gameplay.cancel_session()
	await process_frame

	print("INTERACTIVE_SPACE_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
