extends SceneTree
## Actual hosted UI clicks, board hit areas, AI responses and result handoff.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	await process_frame
	while root.get_node("SceneRouter").transitioning: await process_frame
	await process_frame
func click_at(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = at; event.global_position = at; event.pressed = down
		root.push_input(event, true); await process_frame
	await settle()
func click(node: Control) -> void:
	await click_at(node.get_global_transform_with_canvas() * (node.size * .5))
func button(node: Node, text: String) -> Button:
	if node is Button and node.text == root.get_node("LocalizationSystem").text(text): return node
	for child in node.get_children():
		var found := button(child, text)
		if found: return found
	return null
func snap(label: String) -> void:
	if "--english" in OS.get_cmdline_user_args(): scan_english(current_scene)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/chess-captures")
	root.get_texture().get_image().save_png("res://.runtime/chess-captures/" + ("en-" if "--english" in OS.get_cmdline_user_args() else "") + label + ".png")
func scan_english(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is RichTextLabel or node is BaseButton:
		var cjk := RegEx.new(); cjk.compile("[㐀-鿿]")
		check(cjk.search(TranslationServer.translate(str(node.text))) == null, "English chess surface has no untranslated text: " + node.name)
	for child in node.get_children(): scan_english(child)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size = Vector2i(1280, 720); root.content_scale_size = Vector2i(1600, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("SettingsSystem").values.language = "en" if "--english" in OS.get_cmdline_user_args() else "zh_CN"
	root.get_node("SettingsSystem").apply_settings()
	check(TranslationServer.translate("围棋") == ("Go" if "--english" in OS.get_cmdline_user_args() else "围棋"), "Native control translation respects the selected language")
	var gs = root.get_node("GameState"); var router = root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	gs.switch_to_role("B", 4, true); gs.current_minute = 720; gs.current_location = "chess_stall"
	check(router.gameplay_module("chess", "street:chess_stall"), "Production chess host opens")
	if failures: quit(1); return
	await settle()
	var host = current_scene; var game = host.experience
	check(game.position.y >= host.host_panel.size.y, "Host controls reserve their own space above the board")
	await snap("selection")
	for index in range(3):
		await click(game.buttons[index])
		check(is_instance_valid(game.setup_view), "Real game choice opens its rules")
		if not is_instance_valid(game.setup_view): quit(1); return
		await snap("rules-" + str(index))
		await click(button(game.setup_view, "准备好了，开始对弈"))
		check(is_instance_valid(game.match_view), "Start button opens a playable board")
		var board = game.match_view
		if not is_instance_valid(board): quit(1); return
		var prior: Array = board.board.duplicate()
		await click_at(board.get_global_transform_with_canvas() * Vector2(940, 410))
		check(board.board == prior, "Paper gutter never places a piece")
		if index == 2:
			await click_at(board.get_global_transform_with_canvas() * (board.origin + Vector2(4.5, 6.5) * board.cell))
			check(board.selected == 52, "Mouse picks the white e2 pawn under the new cutout")
			await click_at(board.get_global_transform_with_canvas() * (board.origin + Vector2(4.5, 4.5) * board.cell))
			check(board.board[36] == 1 and board.board[52] == 0, "e2-e4 changes the real chess state")
		else:
			await click_at(board.get_global_transform_with_canvas() * (board.origin + Vector2(2, 2) * board.cell))
			check(board.board[board.n * 2 + 2] == 1, "Click lands on the visible grid intersection")
		await create_timer(.7).timeout
		check(not board.busy and board.turn == 1, "Local opponent responds and returns control")
		await click(button(board, "规则说明"))
		check(is_instance_valid(board.rules_view), "Rules can reopen during the actual match")
		await click(button(board.rules_view, "明白了，继续下棋"))
		check(not is_instance_valid(board.rules_view), "Rules dismiss without trapping board input")
		await snap("board-" + str(index))
		if index < 2:
			await click(button(board, "返回棋类选择"))
			check(not is_instance_valid(game.match_view), "Return releases the previous board")
		else:
			await click(button(board, "认输"))
			check(board.ended and host._experience_completed(), "Real result unlocks host completion")
			await snap("story")
			game._close_story(); await settle()
			game._close_match(); await settle()
	await click(button(game, "教棋 / 共享棋谱"))
	check(is_instance_valid(game.teaching_view), "Shared lesson screen remains reachable")
	await snap("teaching")
	game._close_teaching(); await settle()
	await click(host.complete_button)
	check(current_scene != host, "Completed chess result returns to the town")
	print("CHESS_PRESENTATION: ", checks, " checks / ", failures, " failures")
	quit(failures)
