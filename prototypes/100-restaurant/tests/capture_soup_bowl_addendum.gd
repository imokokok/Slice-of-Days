extends SceneTree
## Supplemental Movie Maker shot for the real broth-to-bowl serving path.
var game

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"shift_seconds": 720.0, "repository_path": "user://soup_bowl_movie_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.audio.muted = true
	# Prepare through the production faucet path before the supplemental shot.
	game.world.pan.offset = Vector2(-612, 110)
	game.world.pan.faucet_on = true
	game.world.pan._process(1.4)
	game.world.pan.faucet_on = false
	game.world.pan.offset = game.world.pan.HOME
	if game.world.pan.water_ml < 200.0:
		push_error("Soup shot: faucet did not supply enough tracked water")
		quit(1)
		return
	game.world.spawn_ingredient(game._definition("tomato"))
	game.world.drop_into_pan()
	for i in 65: await process_frame
	if game.session.dish.is_empty():
		push_error("Soup shot: physical tomato did not enter pan")
		quit(1)
		return
	game._notify("补充镜头：把锅里的汤实际盛进碗里")
	await frames(75)
	game._show_plating()
	await frames(30)
	var portions: Array = []
	for body in game.world._foods.get_children():
		if body.get_meta("enrolled", false): portions.append(body)
	game._plate_bodies(portions)
	game._set_serving_vessel("bowl")
	var amount: float = game._transfer_broth_to_bowl(100.0)
	if not is_equal_approx(amount, 100.0) or not is_equal_approx(game.world.pan.water_ml + amount, 252.0):
		push_error("Soup shot: broth volume was not conserved")
		quit(1)
		return
	await frames(155)
	game._close_modal()
	game._serve()
	if game._modal_kind != "dish_showcase":
		push_error("Soup shot: served bowl showcase missing")
		quit(1)
		return
	await frames(130)
	print("PASS: tracked soup bowl addendum, 100 ml served")
	game.queue_free()
	await process_frame
	quit(0)

func frames(count: int) -> void:
	for i in count:
		await process_frame
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
