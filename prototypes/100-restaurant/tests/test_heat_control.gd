extends SceneTree
const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")

func _run() -> void:
	for level in ["low", "medium", "high"]:
		var model = Session.new()
		model.setup()
		model.add_ingredient("chicken")
		_expect(model.set_heat_level(level), "valid heat level accepted")
		model.set_heating(true)
		model.tick(8.0)
		_expect(is_equal_approx(model.dish[0].heat, 8.0 * model.HEAT_RATES[level]), "actual cooking rate follows selected level")
		if level == "low": _expect(model.plate().raw_count == 1, "low heat takes longer to cook through")
		if level == "medium": _expect(model.plate().raw_count == 0 and not model.plate().burnt, "medium preserves old cooking speed")
		if level == "high":
			model.tick(1)
			_expect(model.plate().burnt, "high heat burns sooner if unattended")
		var prior: float = model.dish[0].heat
		model.set_heating(false)
		model.tick(5)
		_expect(model.dish[0].heat == prior, "switching off stops added cooking dose")
		_expect(not model.set_heat_level("invalid") and model.heat_level == level, "invalid level does not corrupt cooking model")
	var game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.session.add_ingredient("egg")
	for level in ["low", "high", "off"]:
		var button: Button = game._fire_buttons[level]
		var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
		_expect(game.session.heating == (level != "off"), "actual heat button controls stove")
		_expect(button.button_pressed, "selected fire state is visible")
		if level != "off": _expect(game.session.heat_level == level, "actual UI selects requested rate")
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: heat controls, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
