extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location = "park"
	state.current_minute = 1259
	check(not root.get_node("GameplayModuleSystem").begin_session("contemplation", "street:park"), "Telescope must reject entry before 21:00")
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.5).timeout
	var town = current_scene
	check(is_finite(town.street.walk_limit), "Lookout needs a gate before 21:00")
	state.current_minute = 1260
	town._refresh()
	check(not is_finite(town.street.walk_limit), "Gate must open at exactly 21:00")
	check(town.street._ground_at(2900) == 713 and town.street._ground_at(3200) == 805, "Approach and terrace meet at the correct ground height")
	root.get_node("SceneRouter").gameplay_module("contemplation", "street:park")
	await create_timer(0.8).timeout
	var sky = current_scene.experience
	check(sky is Node3D and sky.camera is Camera3D, "Telescope must directly enter real 3D")
	check(sky.data.positions == sky.source_data.positions, "Authored star depth must remain intact")
	var before: Transform3D = sky.camera.transform
	# Dispatch through the actual viewport and host UI, not directly to the controller.
	var press := InputEventMouseButton.new()
	press.position = Vector2(650, 350)
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(650, 350)
	motion.relative = Vector2(45, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press.pressed = false
	root.push_input(press, true)
	await process_frame
	check(not sky.camera.transform.is_equal_approx(before), "Dragging through the host UI rotates the real 3D camera")
	check(sky.data.positions == sky.source_data.positions, "Mouse dragging preserves world-space star depth")
	check(not sky.has_node("UI/Adjustment"), "Mouse sky has no directional button panel")
	before = sky.camera.transform
	sky.adjust(Vector2i(1, 0))
	check(not sky.camera.transform.is_equal_approx(before), "Telescope controls must rotate the 3D camera")
	sky.adjustment = sky.solution
	sky.look_offset = Vector2.ZERO
	sky.update_layout()
	check(sky.checker.measure(sky.camera, sky.data) < 0.05, "Original star puzzle must remain solvable")
	sky.return_requested.emit()
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "Leaving telescope must return to town")
	var journal = load("res://scenes/journal.tscn").instantiate()
	root.add_child(journal)
	check(journal._today_text().contains("明信片"), "A carries daily inspiration prompts")
	state.current_role = "B"
	check(journal._today_text().contains("今日花钱计划 80元") and journal._today_text().contains("□"), "B carries a daily spending plan and to-do list")
	journal.queue_free()
	print("OBSERVATORY AND NOTEBOOK PASS" if failures == 0 else "FAIL: %d" % failures)
	quit(failures)
