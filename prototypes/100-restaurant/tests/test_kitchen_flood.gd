extends SceneTree
## A running tap has a conserved path through sink storage, room flood and drain.
var game: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://flood_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	check(is_equal_approx(game.session.duration, 720.0), "a full shift lasts twelve real minutes")
	game.session.phase = "service"
	game.session.elapsed = 360.0
	game._update_hud()
	check("12:00" in game.clock_label.text, "halfway through the shift the visible clock has advanced two game hours")
	game.session.elapsed = 0.0
	game.session.phase = "prep"
	game.world.pan.faucet_on = true
	game.world.pan._process(10.0)
	check(is_equal_approx(game.world.sink_water_ml, 1200.0) and is_equal_approx(game.world.flood_water_ml, 600.0), "running tap fills sink then puts its overflow on the kitchen floor")
	check(game.world.flood_ratio() > 0.0 and game.world.flood_ratio() < 0.1, "waterline starts at the floor and rises continuously")
	game.world.pan._process(40.0)
	check(is_equal_approx(game.world.flood_water_ml, game.world.KITCHEN_FLOOD_ML) and is_equal_approx(game.world.drained_flood_ml, 0.0), "continued running water reaches the full-room flood height")
	game.world.pan._process(10.0)
	check(is_equal_approx(game.world.drained_flood_ml, 1800.0), "water beyond the room capacity is recorded rather than disappearing")
	game.world.pan.faucet_on = false
	game.world._process(12.0)
	check(is_equal_approx(game.world.flood_water_ml, 6600.0) and is_equal_approx(game.world.drained_flood_ml, 3000.0), "closing the tap drains standing room water without resetting it instantly")
	check(is_equal_approx(game.world.sink_water_ml + game.world.flood_water_ml + game.world.drained_flood_ml, 10800.0), "tap water remains conserved across sink, floor and drain")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		game.world.flood_water_ml = game.world.KITCHEN_FLOOD_ML * 0.72
		game.world.flood_art.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]) == OK, "GPU shows a room-wide rising waterline")
	for failure in failures: push_error(failure)
	print("%s: kitchen flood, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)
