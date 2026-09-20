extends SceneTree

# Run with a rendering display and -- --fresh; no player saves are written.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--fresh"):
		push_error("Use a rendering display and -- --fresh for this test.")
		quit(2)
		return
	root.get_node("GameState").begin_new_game("A")
	var gameplay = root.get_node("GameplayModuleSystem")
	check(gameplay.begin_session("ghostwriting", "space:test:collage"), "Letter session should begin")
	var host = load("res://scenes/extension_host.tscn").instantiate()
	root.add_child(host)
	var letter = host.experience
	letter.smoke = true
	for frame in range(300):
		if letter.ready_done:
			break
		await process_frame
	check(letter.ready_done, "Letter should finish rendering its materials")
	check(letter.get_viewport() == host.letter_viewport, "Drawing must use the isolated viewport")
	check(letter.ui.get_viewport() == host.letter_viewport, "CanvasLayer controls must use the same viewport")
	check(letter.position == Vector2.ZERO, "Letter coordinates must not be offset")
	for dimensions in [Vector2(1600, 900), Vector2(1280, 720), Vector2(1920, 1080)]:
		host.size = dimensions
		host._fit_experience()
		var bounds := Rect2(host.letter_container.position, Vector2(1600, 900) * host.letter_container.scale)
		check(Rect2(Vector2.ZERO, dimensions).encloses(bounds), "Letter must fit inside host at %s" % dimensions)
		check(bounds.position.y >= host.host_panel.size.y, "Host buttons must not cover the letter")
		check(host.letter_viewport.size == Vector2i(1600, 900), "Capture coordinates must remain stable")
	host.size = Vector2(1600, 900)
	host._fit_experience()
	letter.stage = "WORKBENCH"
	letter.build_ui()
	await process_frame
	# Send a root-viewport click through the container, not directly to the button.
	var click_at: Vector2 = host.letter_container.position + Vector2(80, 200) * host.letter_container.scale
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = click_at
		event.global_position = click_at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	check(letter.mode == letter.Mode.MATERIAL_BROWSER, "Root mouse coordinates must open the visible materials button")
	letter.take_material()
	letter.active.position = letter.main_paper.position
	await letter.begin_folding()
	check(letter.letter_preview != null and letter.letter_preview.get_size() == Vector2(440, 390), "Capture must contain only the native letter canvas")
	letter.return_desk()
	await RenderingServer.frame_post_draw
	var screenshot := OS.get_environment("COLLAGE_TEST_SCREENSHOT")
	if not screenshot.is_empty(): root.get_texture().get_image().save_png(screenshot)
	letter.mode = letter.Mode.WAX_SEALING
	letter.wax_step = 1
	letter.candle_lit = true
	letter.papers.hide()
	letter.tools_root.hide()
	letter.build_ui()
	await process_frame
	for sample in [[Vector2(600, 322), true], [Vector2(390, 330), false]]:
		var at: Vector2 = host.letter_container.position + sample[0] * host.letter_container.scale
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = sample[1]
		root.push_input(event, true)
		await process_frame
	check(letter.wax_step == 2 and letter.spoon_filled, "Spoon must collect wax through the scaled host viewport")
	letter.audio.shutdown()
	host.queue_free()
	gameplay.cancel_session()
	await create_timer(0.3).timeout
	print("COLLAGE_VIEWPORT_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
