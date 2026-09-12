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
	game.configure({"repository_path":"user://pan_input_%s/book.json" % Time.get_ticks_usec(), "shift_seconds":600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	# Grab food directly from a shelf on mouse-down, and release above a GUI panel.
	var button = game.find_child("Ingredient_egg", true, false)
	if button == null:
		for node in game.find_children("*", "Button", true, false):
			if node.get_meta("ingredient_id", "") == "egg": button = node
	_expect(button != null, "find the visible cold-storage ingredient button")
	if button != null:
		var origin: Vector2 = button.get_global_rect().get_center()
		_mouse(origin, "down")
		await process_frame
		_expect(is_instance_valid(game.world._held) and game.world._dragging, "shelf press immediately owns a physical food drag")
		_mouse(Vector2(600, 605), "move")
		await process_frame
		_mouse(Vector2(1350, 250), "up")
		await process_frame
		_expect(game.world._held == null and not game.world._dragging, "release above GUI ends food drag")
		_mouse(origin, "down")
		_mouse(origin, "up")
		await process_frame
		_expect(is_instance_valid(game.world._held), "a simple shelf click still supports click-to-carry")
		game.world.discard_held()
	# Independent loose food can be picked up more than once.
	game.world.spawn_ingredient(game._definition("rice"))
	var rice: RigidBody2D = game.world._held
	game.world.drop_into_pan()
	await create_timer(0.6).timeout
	_expect(rice.get_meta("enrolled", false), "pan fixture really enrolls through physics")
	game.session.set_heating(true)
	await create_timer(0.1).timeout
	_expect(game.world.audio.loops.flame.playing and game.world.audio.loops.sizzle.playing, "burner and dry-pan food trigger different audio loops")
	_mouse(Vector2(1037,654), "down")
	await process_frame
	_expect(game.world.pan.active, "actual pan-handle press starts pan movement")
	var before := rice.position
	_mouse(Vector2(450,654), "move")
	await process_frame
	await physics_frame
	await process_frame
	_expect(rice.position.x < before.x - 490, "moving pan carries the existing ingredient body")
	_mouse(Vector2(450,654), "up")
	await create_timer(0.15).timeout
	_expect(not game.world.pan.active and game.world.pan.under_tap(), "released pan stays under sink faucet")
	_expect(game.session.dish.size() == 1 and rice.get_meta("enrolled", false), "pan transport preserves single recipe enrollment")
	var heat: float = game.session.dish[0].heat
	await create_timer(0.15).timeout
	_expect(is_equal_approx(game.session.dish[0].heat, heat), "pan away from burner stops receiving heat")
	_expect(game.world.audio.loops.flame.playing and not game.world.audio.loops.sizzle.playing, "burner remains audible while moved pan stops sizzling")
	# Pressing alone does not create water. The visible mixer lever must rotate.
	_mouse(Vector2(292,580), "down")
	_mouse(Vector2(292,580), "up")
	await process_frame
	_expect(not game.world.pan.faucet_on and is_zero_approx(game.world.pan.water_ml), "a faucet click alone cannot turn on water")
	_mouse(Vector2(292,580), "down")
	_mouse(Vector2(292,642), "move")
	_mouse(Vector2(292,642), "up")
	await create_timer(0.5).timeout
	_expect(game.world.pan.faucet_amount>0.95,"drag distance controls the visible faucet handle angle and flow amount")
	_expect(game.world.pan.water_ml > 60 and game.world.audio.loops.water.playing, "turning the faucet handle fills pan and starts matching water sound")
	_mouse(Vector2(292,609), "down")
	_mouse(Vector2(292,547), "move")
	_mouse(Vector2(292,547), "up")
	await process_frame
	var water: float = game.world.pan.water_ml
	await create_timer(0.1).timeout
	_expect(is_equal_approx(water, game.world.pan.water_ml) and not game.world.audio.loops.water.playing, "turning the handle back stops both filling and water sound")
	_mouse(Vector2(450,654), "down")
	_mouse(Vector2(1037,654), "move")
	_mouse(Vector2(1037,654), "up")
	await create_timer(0.2).timeout
	_expect(game.world.pan.on_stove() and game.session.dish[0].heat > heat, "returning pan to burner resumes cooking")
	game.world.pan.water_heat = 100
	await process_frame
	await process_frame
	_expect(game.world.audio.loops.boil.playing and not game.world.audio.loops.sizzle.playing, "boiling water has its own sound instead of dry frying")
	game._show_pause()
	await process_frame
	var all_stopped := true
	for player in game.world.audio.loops.values(): all_stopped = all_stopped and not player.playing
	_expect(all_stopped, "modal suspends all continuous kitchen sounds")
	game._close_modal()
	game.world.audio.muted = true
	await process_frame
	for player in game.world.audio.loops.values(): _expect(not player.playing, "mute stops each loop independently of the host bus")
	game.world.audio.muted = false
	_mouse(Vector2(1037,654), "down")
	_mouse(Vector2(450,654), "move")
	_mouse(Vector2(450,654), "up")
	await create_timer(0.15).timeout
	_expect(game.world.pan.under_tap(), "pan settles beneath faucet before draining")
	_mouse(Vector2(200,761), "down")
	_mouse(Vector2(200,761), "up")
	await process_frame
	_expect(is_zero_approx(game.world.pan.water_ml), "sink drain control empties only pan water")
	game.world.pan.faucet_on = true
	game.world.pan.water_ml = 1499
	await create_timer(0.2).timeout
	_expect(game.world.pan.water_ml <= 1500, "pan water remains within physical capacity")
	_expect(game.world.pan.overflow_water_ml > 0, "continued faucet flow becomes visible overflow instead of entering a full pan")
	game.world.pan.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not game.world.pan.faucet_on and not game.world.pan.active, "focus loss stops faucet and releases pan")
	game.world.spawn_ingredient(game._definition("ketchup"))
	_mouse(Vector2(211,633), "idle")
	await process_frame
	_mouse(Vector2(211,633), "down")
	await create_timer(0.7).timeout
	_mouse(Vector2(211,633), "up")
	for frame in range(60):
		if game.session.dish.size() >= 2: break
		await physics_frame
	var moved_pan_received_ketchup := false
	for item in game.session.dish: moved_pan_received_ketchup = moved_pan_received_ketchup or item.id == "ketchup"
	_expect(game.session.dish.size() >= 2 and moved_pan_received_ketchup, "dispensing targets the moved pan instead of old stove coordinates")
	game.world.discard_held()
	game.world.audio.muted = true
	game.world.audio.stop_all()
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: kitchen interactions, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind in ["move", "idle"]:
		var e := InputEventMouseMotion.new()
		e.position = point
		e.global_position = point
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "move" else 0
		Input.parse_input_event(e)
	else:
		var e := InputEventMouseButton.new()
		e.position = point
		e.global_position = point
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = kind == "down"
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if e.pressed else 0
		Input.parse_input_event(e)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
