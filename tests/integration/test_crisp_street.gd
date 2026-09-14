extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	state.begin_new_game("A")
	state.current_minute = 540
	var atlas = load("res://scripts/ui/scene_atlas.gd")
	var cached: Dictionary = atlas.textures.duplicate()
	for sample in [["town_entrance",Color.RED],["cafe",Color.BLUE]]:
		var flat := Image.create(160,90,false,Image.FORMAT_RGBA8)
		flat.fill(sample[1])
		atlas.textures[int(atlas.street(sample[0]).pages[0])] = ImageTexture.create_from_image(flat)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage = load("res://scripts/ui/walk_stage.gd").new()
	stage.world_width = 3200
	stage.composition_anchor = 800
	stage.player_x = 1600
	stage.camera_x = 800
	stage.enabled = false
	stage.places.assign([{"id":"town_entrance","x":800,"width":1600},{"id":"cafe","x":2400,"width":1600}])
	viewport.add_child(stage)
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	for x in range(725, 800):
		check(pixels.get_pixel(x,850).is_equal_approx(Color.RED), "Left picture remains opaque at the seam")
	for x in range(800, 875):
		check(pixels.get_pixel(x,850).is_equal_approx(Color.BLUE), "Right picture remains opaque at the seam")
	state.current_minute = 1140
	await process_frame
	await RenderingServer.frame_post_draw
	var night_pixels := viewport.get_texture().get_image()
	check(not night_pixels.get_pixel(300,300).is_equal_approx(Color.RED), "Stationary disabled stage redraws when the light phase changes")
	viewport.queue_free()
	await process_frame
	atlas.textures = cached
	state.begin_new_game("B")
	state.switch_to_role("B",2,true)
	state.current_location = "cafe"
	state.current_minute = 700
	state.spend_money(18,"奶酪")
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.8).timeout
	var folder := OS.get_environment("TEMP") + "/solmere-bug-audit"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in range(1,current_scene.street_order.size()):
		current_scene.street.player_x = current_scene._world_x(i, 0)
		current_scene.street.move_player(0,0)
		current_scene._on_walk(current_scene.street.player_x)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/street-seam-%d.png" % i)
	current_scene.street.player_x = current_scene._world_x(1,420)
	current_scene.street.move_player(0,0)
	current_scene._on_walk(current_scene.street.player_x)
	current_scene._open_shop("grocery")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/b-daily-budget-shop.png")
	check(current_scene.pocket_panel.budget_label.text.contains("还可安排 62元"),"Real shop renders the current remaining plan")
	current_scene.queue_free()
	await create_timer(0.3).timeout
	print("CRISP STREET PASS" if failures == 0 else "CRISP STREET FAIL")
	quit(failures)
