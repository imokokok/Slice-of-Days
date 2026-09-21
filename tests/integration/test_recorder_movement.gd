extends SceneTree
## Run with the rendered, focused game window and --isolated-save.
## Movement must pass through Input.parse_input_event and the normal frame loop.
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if ok:
		print("PASS ", title)
	else:
		failures += 1
		push_error(title)

func send_key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	send_key(code, true)
	await create_timer(0.05).timeout
	send_key(code, false)
	await process_frame

func dismiss_meta_modals() -> void:
	# Recorder/camera milestones may intentionally surface a narrative memory card.
	# Dismiss that card before measuring the underlying walking state.
	for node in get_nodes_in_group("meta_modal"):
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		if node.has_method("_close"): node.call("_close")
		else: node.queue_free()
	await process_frame
	await process_frame

func hold_right(stage: Control, should_move: bool, title: String) -> void:
	await create_timer(0.15).timeout
	# Long journeys can legitimately leave the actor at the edge of a segment.
	# Re-center before measuring input so the assertion tests the walking lock,
	# rather than the collision boundary.
	if should_move:
		stage.player_x = minf(stage.player_x, minf(stage.world_width - 260.0, stage.walk_limit - 180.0))
		stage.player_x = maxf(stage.player_x, 120.0)
		stage.velocity = 0.0
	var before: float = stage.player_x
	send_key(KEY_D, true)
	check(Input.get_axis("move_left", "move_right") > 0.9, title + " / real key reaches InputMap")
	await create_timer(0.45).timeout
	send_key(KEY_D, false)
	await create_timer(0.15).timeout
	var distance: float = stage.player_x - before
	if should_move and distance <= 45.0:
		print("MOVEMENT_DEBUG title=", title, " enabled=", stage.enabled, " sitting=", stage.sitting, " velocity=", stage.velocity, " player=", stage.player_x, " limit=", stage.walk_limit, " width=", stage.world_width, " focused=", DisplayServer.window_is_focused(), " modal=", root.get_node("MetaExperience").modal_open(), " tools=", get_nodes_in_group("world_tool").size())
	check(distance > 45.0 if should_move else absf(distance) < 0.5, title + " / distance %.2f" % distance)

func exercise_scene(indoor: bool) -> void:
	var gs = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var label := "Indoor" if indoor else "Outdoor"
	gs.current_location = "residence" if indoor else "town_entrance"
	gs.current_minute = 600
	router.active_space_id = "home_a" if indoor else ""
	change_scene_to_file("res://scenes/interactive_space.tscn" if indoor else "res://scenes/town_day.tscn")
	await create_timer(0.5).timeout
	await dismiss_meta_modals()
	var host = current_scene
	var shell = host.get_node("GameplayShell")
	var stage: Control = host.stage if indoor else host.street
	check(stage.enabled, label + " starts with walking enabled")
	await hold_right(stage, true, label + " normal walking")

	var before_samples: int = gs.artifacts.get("samples", []).size()
	await tap(KEY_R)
	await create_timer(0.15).timeout
	check(is_instance_valid(shell.tool), label + " R opens recorder through input routing")
	if not is_instance_valid(shell.tool):
		return
	var recorder = shell.tool
	recorder.store_path = "user://recorder_movement_test_samples"
	check(recorder.is_in_group("mobile_recorder"), label + " recorder declares mobile behavior")
	check(not shell.blocks_walking(), label + " idle recorder does not block walking")
	check(stage.enabled, label + " idle recorder leaves host walking enabled")
	await hold_right(stage, true, label + " walking with idle recorder")

	if not recorder.recorder.capturing:
		await tap(KEY_R)
	await create_timer(0.2).timeout
	check(recorder.recorder.capturing, label + " R starts real TownWorld capture")
	check(stage.enabled and not shell.blocks_walking(), label + " capture does not lock host")
	await hold_right(stage, true, label + " walking during capture")
	await tap(KEY_SPACE)
	await create_timer(0.7).timeout
	check(recorder.marks.size() == 1, label + " recording accepts a timestamp while mobile")
	await tap(KEY_R)
	await create_timer(0.2).timeout
	check(is_instance_valid(recorder) and recorder.saved, label + " stop saves real audio")
	check(gs.artifacts.get("samples", []).size() == before_samples + 1, label + " saved audio enters materials once")
	check(stage.enabled, label + " saved confirmation leaves walking enabled")
	await create_timer(1.0).timeout
	check(is_instance_valid(shell.tool), label + " saved recording remains available for playback")
	await tap(KEY_ESCAPE)
	await create_timer(.2).timeout
	check(not is_instance_valid(shell.tool), label + " Esc puts the saved recorder away")
	check(get_nodes_in_group("mobile_recorder").is_empty(), label + " recorder releases scene ownership")
	await dismiss_meta_modals()
	await hold_right(stage, true, label + " walking after recorder dismissal")

	await tap(KEY_F)
	await create_timer(0.15).timeout
	check(is_instance_valid(shell.overlay) and shell.overlay.mode == "dossier", label + " F opens dossier after recording")
	check(not stage.enabled, label + " dossier still pauses walking")
	await hold_right(stage, false, label + " dossier prevents movement")
	await tap(KEY_ESCAPE)
	await create_timer(0.15).timeout
	check(not is_instance_valid(shell.overlay), label + " Esc closes dossier")
	check(stage.enabled, label + " closing dossier resumes movement")

	await tap(KEY_C)
	await create_timer(0.35).timeout
	check(is_instance_valid(shell.tool), label + " C opens camera")
	if not is_instance_valid(shell.tool):
		return
	check(shell.blocks_walking() and not stage.enabled, label + " full-screen camera enters its actual viewfinder")
	await create_timer(0.35).timeout
	check(shell.blocks_walking() and not stage.enabled, label + " viewfinder retains its movement lock")
	await hold_right(stage, false, label + " camera prevents movement")
	await tap(KEY_C)
	await create_timer(0.15).timeout
	check(not is_instance_valid(shell.tool), label + " C puts camera away")
	await dismiss_meta_modals()
	check(stage.enabled, label + " camera close restores walking")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Recorder movement regression requires --isolated-save")
		quit(1)
		return
	if DisplayServer.get_name().contains("headless"):
		push_error("Recorder movement regression needs a rendered, focused game window")
		quit(1)
		return
	await create_timer(0.4).timeout
	check(DisplayServer.window_is_focused(), "Real keyboard movement test has window focus")
	if not DisplayServer.window_is_focused():
		quit(1)
		return
	root.get_node("GameState").begin_new_game("A")
	var state=root.get_node("GameState"); state.current_location="cafe"; state.money=500
	root.get_node("FilmSystem").notice_camera()
	check(root.get_node("FilmSystem").acquire_camera(false).ok,"Fixture acquires a real camera before testing its input")
	await exercise_scene(false)
	await exercise_scene(true)
	for code in [KEY_D, KEY_R, KEY_SPACE, KEY_F, KEY_C, KEY_ESCAPE]:
		send_key(code, false)
	print("RECORDER_MOVEMENT ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
