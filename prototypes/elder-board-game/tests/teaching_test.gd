extends SceneTree
const Memory = preload("res://scripts/elder_memory.gd")
const Rules = preload("res://scripts/teaching_rules.gd")
const AI = preload("res://scripts/teaching_ai.gd")
const Room = preload("res://scripts/teaching_room.gd")
var failed := false

func verify(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func _initialize() -> void:
	Memory.directory = "user://teaching-test-%d" % Time.get_ticks_usec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--memory="): Memory.directory = arg.trim_prefix("--memory=")
	call_deferred("run")

func capture(path: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if "--verify-reopen" in OS.get_cmdline_user_args():
		Memory.role = "B"
		verify(Memory.read().profiles.size() == 2, "Both roles' lessons survive a process restart")
		verify(Memory.read().profiles[0].taught_by == "A" and Memory.read().profiles[1].taught_by == "B", "Teaching attribution survives")
		print("REOPEN TEST: ", "FAIL" if failed else "PASS")
		quit(1 if failed else 0)
		return
	AI.enabled = false
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await capture("res://../shared-menu-preview.png")
	Memory.role = "A"
	main._open_teaching()
	await process_frame
	var room = main.teaching_view
	room.input.text = "我教您井字棋，3×3，横竖斜连成3子就赢，长连也算，我先下。"
	await room.send_message()
	verify(room.ready_to_confirm, "A teaching reaches explicit confirmation")
	verify(Memory.read().profiles.is_empty(), "Unconfirmed rules are not in shared library")
	await capture("res://../teaching-preview.png")
	room.confirm_lesson()
	verify(Memory.read().profiles.size() == 1 and Memory.read().profiles[0].taught_by == "A", "A profile persisted")
	verify(not room.play_button.disabled, "Confirmed learned game is playable")
	room.play_lesson()
	await process_frame
	var game = main.match_view
	verify(game.board.size() == 9, "Learned rules initialize the board")
	game.play(game.moves[0])
	game.ai_turn()
	await create_timer(0.6).timeout
	verify(game.board.count(1) == 1 and game.board.count(-1) == 1, "Learned AI responds with a legal move")
	await capture("res://../learned-game-preview.png")
	game.return_requested.emit()
	await process_frame
	room.input.text = "A还没讲完的草稿"
	room.save_draft()
	main._close_teaching()
	await process_frame
	Memory.role = "B"
	main._open_teaching()
	await process_frame
	room = main.teaching_view
	verify(room.input.text != "A还没讲完的草稿", "B does not inherit A's draft")
	verify(room.profiles.size() == 1, "B sees A's confirmed teaching")
	room.load_lesson(1)
	verify(room.confirmed_profile.taught_by == "A" and not room.play_button.disabled, "B can play A's lesson")
	room.new_lesson()
	room.input.text = "这棋叫四连棋，7×6，横竖斜连成4子，超过也算，我先下。"
	await room.send_message()
	verify(room.ready_to_confirm, "B custom line rule is understood")
	room.confirm_lesson()
	verify(Memory.read().profiles.size() == 2, "B teaching added without replacing A")
	main._close_teaching()
	await process_frame
	Memory.role = "A"
	main._open_teaching()
	await process_frame
	room = main.teaching_view
	verify(room.profiles.size() == 2, "A sees B's learned game")
	room.load_lesson(2)
	verify(room.confirmed_profile.taught_by == "B", "Shared authorship preserved")
	room.input.text = "改一条还没发送的规则"
	room.input.text_changed.emit()
	await process_frame
	verify(room.confirm_button.disabled and room.play_button.disabled, "Unsent edits invalidate old confirmation")
	# Imported picture + ink are exportable and an image is never 'understood' offline.
	var sample := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	sample.fill(Color.BLUE)
	sample.save_png(Memory.directory + "/source.png")
	room.import_picture(Memory.directory + "/source.png")
	verify(room.pad.has_art(), "Image import")
	room.pad.strokes.append({"color": "ff0000", "points": [[10, 10], [90, 90]]})
	var exported: Image = room.pad.picture()
	verify(exported.get_pixel(50, 50).r > 0.9, "Ink is included in exported attachment")
	room.pad.undo()
	verify(room.pad.strokes.is_empty(), "Undo only removes last stroke")
	room.input.text = "看这张图"
	room.attach.button_pressed = true
	await room.send_message()
	verify(not room.ready_to_confirm, "Offline image cannot falsely confirm")
	main._close_teaching()
	await process_frame
	main._select_game(1)
	main._start_match(9)
	await process_frame
	main.match_view.finish("你赢了！")
	await process_frame
	verify(is_instance_valid(main.story_view), "Match end opens elder's story")
	await capture("res://../elder-story-preview.png")
	for beat in range(6): main.story_view.advance()
	await process_frame
	verify(Memory.story_index() == 1, "Story progresses only after listening")
	Memory.role = "B"
	verify(Memory.story_index() == 0, "Story listening progress is role-specific")
	# Data contract rejects model output that cannot actually be executed.
	var line := {"name": "三连", "kind": "line", "width": 3, "height": 3, "target": 3, "directions": ["horizontal", "vertical", "diagonal"], "exact": false, "first": "player"}
	verify(Rules.validate(line).is_empty(), "Valid rules")
	var invalid := line.duplicate(true)
	invalid["code"] = "anything"
	verify(not Rules.validate(invalid).is_empty(), "Model code is rejected")
	invalid = line.duplicate(true)
	invalid.capture = "landing"
	verify(not Rules.validate(invalid).is_empty(), "Ignored mechanics cannot silently pass")
	verify(Rules.won([1, 1, 1, 0, 0, 0, 0, 0, 0], 1, line), "Learned victory rule")
	var movement := {"name": "过河棋", "kind": "capture", "width": 5, "height": 5, "first": "player", "moves": [[0, 1], [1, 0], [-1, 0]], "capture": "landing", "goal": "reach_edge", "start_rows": 1}
	verify(Rules.validate(movement).is_empty(), "Movement rules accepted")
	verify(Rules.initial(movement).count(1) == 5, "Custom setup")
	var board := Rules.initial(movement)
	board[0] = 1
	verify(Rules.won(board, 1, movement), "Custom goal")
	var response := {"reply": "我还没明白", "rules": line, "ready": true, "questions": ["谁先？"], "unsupported": []}
	var decoded := AI.decode(JSON.stringify({"choices": [{"message": {"content": JSON.stringify(response)}}]}).to_utf8_buffer())
	verify(not decoded.ready, "Unresolved questions override model ready=true")
	verify(AI.decode("not json".to_utf8_buffer()).has("error"), "Malformed model reply handled")
	print("TEACHING TESTS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
