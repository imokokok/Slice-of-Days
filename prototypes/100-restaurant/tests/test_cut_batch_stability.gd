extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://cut_stability_%s/book.json" % Time.get_ticks_usec(), "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var world = game.world
	world.audio.muted = true

	# Put one intact ingredient on the real board, then move the board through
	# the same pointer path used by a player.  Its station and cargo must agree.
	world.spawn_ingredient(game._definition("tomato"))
	var whole: RigidBody2D = world._held
	whole.position = world.cutting_board.rect().get_center()
	world.drop_held(false)
	await process_frame
	var old_board: Vector2 = world.cutting_board.position
	var old_food: Vector2 = whole.position
	_mouse(old_board + Vector2(14, 14), "down")
	_mouse(old_board + Vector2(-76, -16), "move")
	_mouse(old_board + Vector2(-76, -16), "up")
	await process_frame
	var board_delta: Vector2 = world.cutting_board.position - old_board
	_expect(board_delta.length() > 50.0, "cutting board is physically draggable from an empty area")
	_expect(world._stations.chop == world.cutting_board.rect(), "moved cutting board updates its real cutting station")
	_expect(whole.position.distance_to(old_food + board_delta) < 1.0 and whole.get_meta("on_board", false), "food rides with the moved cutting board")

	# Make eight pieces from one lineage.  A single drag must enroll all of them
	# without any shared spawn position or solver ejection.
	var generation: Array[RigidBody2D] = [whole]
	for depth in range(3):
		var next: Array[RigidBody2D] = []
		for piece in generation:
			var normal := Vector2.RIGHT if depth % 2 == 0 else Vector2.DOWN
			next.append_array(world.split_food(piece, normal, Vector2.INF, 4))
		generation = next
		await process_frame
	_expect(generation.size() == 8, "three real cuts produce eight independent pieces")
	var batch_uid := str(generation[0].get_meta("batch_uid", "")) if not generation.is_empty() else ""
	for piece in generation:
		_expect(str(piece.get_meta("batch_uid", "")) == batch_uid and piece.freeze, "every cut piece keeps lineage and stays stable on the board")

	if not generation.is_empty():
		var first: RigidBody2D = generation[0]
		world._pickup(first)
		world.begin_food_drag(first.position)
		world._move_dragged_food(world.pan.point(Vector2(810, 560)))
		world._finish_food_drag()
	await create_timer(1.4).timeout
	_expect(game.session.dish.size() == generation.size(), "one cut-piece drag enrolls the complete eight-piece batch")
	var occupied: Dictionary = {}
	for piece in generation:
		_expect(is_instance_valid(piece) and piece.get_meta("enrolled", false), "every batch fragment is accepted by the pan")
		_expect(world.pan.contains(piece.position), "every batch fragment remains inside the pan")
		_expect(piece.position.is_finite() and piece.position.y < 760.0, "no cut fragment is thrown off the worktop")
		var cell := Vector2i(roundi(piece.position.x), roundi(piece.position.y))
		occupied[cell] = true
	_expect(occupied.size() > 5, "batch fragments start at distributed pan positions")

	# Capacity is conserved and excess tap water is tracked as overflow.
	world.pan.move_to(Vector2(world.pan.SINK_X - 809.0, world.pan.HOME.y))
	world.pan.water_ml = 1499.0
	world.pan.overflow_water_ml = 0.0
	world.pan.faucet_on = true
	await create_timer(0.25).timeout
	_expect(world.pan.water_ml <= 1500.0, "pan cannot contain more than its physical water capacity")
	_expect(world.pan.overflow_water_ml > 0.0, "water after capacity is recorded as overflow")
	world.pan.faucet_on = false
	world.pan.water_ml = 500.0
	world.pan.angle = 0.0
	world.pan.active = true
	world.pan._grab_point = world.pan.PIVOT
	world.pan._pointer = world.pan.PIVOT + world.pan.offset
	world.pan.set_angle(deg_to_rad(110.0))
	_expect(is_zero_approx(world.pan.water_ml), "tilting a water-filled pan past its rim removes water from the vessel")
	world.pan.active = false
	world.clear_workspace()
	await process_frame
	_expect(is_zero_approx(world.pan.overflow_water_ml) and world._foods.get_child_count() == 0, "clean workspace removes loose food, spills and residual overflow state")

	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: cut-batch stability, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind == "move":
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = kind == "down"
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		Input.parse_input_event(event)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
