extends SceneTree
var game
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://capture_stock_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	game._take_ingredient(game._definition("tomato"))
	game.world._held.position = Vector2(1225, 755)
	game.world.drop_held()
	game._notify("柜格只备一件：番茄已拿到菜板，原位留空。")
	await capture("-stock")
	game._show_cookbook()
	await capture("-book")
	game._close_modal()
	game.world.set_process(false)
	game.set_process(false)
	game._take_ingredient(game._definition("ketchup"))
	game.world._held.position = game.world.pan.point(Vector2(810, 530))
	game.world._held.rotation = PI
	game.world._sync_held_foreground()
	game.world._dispense_seasoning(5)
	game.world._dispense_seasoning(5)
	for i in range(100): await physics_frame
	game.world._update_landed_seasoning()
	game._notify("两次少量挤酱：10 ml 留在锅内，未达到锅沿。")
	await capture("-small-sauce")
	game.world.pan.water_ml = 1485
	game.world._dispense_seasoning(12)
	for i in range(60): await physics_frame
	game.world._update_landed_seasoning()
	game.world._overflow_until = game.world._time + 1
	game._notify("原有 1495 ml：再挤 12 ml，5 ml 留锅，7 ml 溢出。")
	await capture("-full-pan")
	game.queue_free()
	await process_frame
	quit()
func capture(suffix: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var base: String = OS.get_cmdline_user_args()[0]
	var result := root.get_texture().get_image().save_png(base + suffix + ".png")
	print("CAPTURE %s: %d" % [suffix, result])
