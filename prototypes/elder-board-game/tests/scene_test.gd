extends SceneTree
const Memory = preload("res://scripts/elder_memory.gd")

func _initialize() -> void:
	Memory.directory = "user://test-scene-%d" % Time.get_ticks_usec()
	call_deferred("run")

func snapshot(path: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.buttons.size() == 3)
	var greeting: String = scene.dialogue.text
	scene._chat()
	assert(scene.dialogue.text != greeting)
	await snapshot("res://../menu-preview.png")
	for index in range(3):
		scene.buttons[index].pressed.emit()
		await process_frame
		assert(is_instance_valid(scene.setup_view))
		await snapshot("res://../setup-%d-preview.png" % index)
		scene.setup_view.start_requested.emit(9)
		await process_frame
		var match_view = scene.match_view
		assert(is_instance_valid(match_view))
		if index == 2:
			match_view.play_chess(match_view.legal_moves[0])
		else:
			assert(match_view.play_stone(int(match_view.board.size() / 2), 1))
		match_view.ai_turn()
		await create_timer(0.7).timeout
		assert(not match_view.busy and match_view.turn == 1)
		var saved_board: Array = match_view.board.duplicate()
		match_view.show_rules()
		await process_frame
		assert(is_instance_valid(match_view.rules_view))
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = match_view.origin
		match_view._gui_input(event)
		assert(match_view.board == saved_board)
		await snapshot("res://../rules-%d-preview.png" % index)
		match_view.rules_view.closed.emit()
		await process_frame
		assert(match_view.board == saved_board)
		await snapshot("res://../%s-preview.png" % match_view.game_id)
		# Restart cancels a pending AI response.
		match_view.ai_turn()
		match_view.restart()
		await create_timer(0.5).timeout
		assert(match_view.turn == 1 and not match_view.busy and match_view.last_move == -1)
		if index == 0:
			match_view.human_pass()
			await create_timer(0.5).timeout
			assert(match_view.scoring)
			match_view.finish_score()
			assert(match_view.ended)
			await process_frame
			if is_instance_valid(scene.story_view): scene._close_story()
		scene._close_match()
		await process_frame
		assert(scene.selected_game == &"")
	for board_size in [13, 19]:
		scene._select_game(0)
		await process_frame
		scene.setup_view.size_choice.select([9, 13, 19].find(board_size))
		scene.setup_view.size_choice.item_selected.emit([9, 13, 19].find(board_size))
		assert(scene.setup_view.go_size == board_size)
		scene.setup_view.start_requested.emit(scene.setup_view.go_size)
		await process_frame
		var match_view = scene.match_view
		assert(match_view.n == board_size and match_view.board.size() == board_size * board_size)
		# Click the lower right intersection using the displayed board coordinates.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = match_view.origin + Vector2(608, 608)
		match_view._gui_input(click)
		await create_timer(0.7).timeout
		assert(match_view.board[-1] == 1 and match_view.turn == 1 and not match_view.busy)
		await snapshot("res://../go-%d-preview.png" % board_size)
		match_view.restart()
		assert(match_view.n == board_size and match_view.board.count(0) == board_size * board_size)
		scene._close_match()
		await process_frame
	# Board size preference persists, and canceling setup does not launch a match.
	scene._select_game(0)
	await process_frame
	assert(scene.setup_view.go_size == 19)
	scene.setup_view.closed.emit()
	await process_frame
	assert(not is_instance_valid(scene.match_view) and scene.selected_game == &"")
	# Resizing preserves the whole original artwork.
	scene.size = Vector2(800, 800)
	scene._fit_stage()
	assert(is_equal_approx(scene.stage.scale.x, scene.stage.scale.y))
	assert(scene.stage.position.y > 0)
	print("SCENE TESTS: PASS")
	quit()
