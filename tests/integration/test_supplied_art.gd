extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	state.begin_new_game("A")
	state.current_minute = 700
	var view := SubViewport.new()
	view.size = Vector2i(1600,900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage = load("res://scripts/ui/walk_stage.gd").new()
	stage.enabled = false
	stage.world_width = 1600
	stage.player_x = 650
	view.add_child(stage)
	var folder := OS.get_environment("TEMP") + "/solmere-supplied-art"
	DirAccess.make_dir_recursive_absolute(folder)
	for place in ["bus_stop","chess_stall"]:
		stage.places.assign([{"id":place,"x":800,"width":1600}])
		stage.hotspots.assign([{"id":"zhou_xiaoliu","kind":"person","x":880,"label":"周晓六"}])
		stage.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(folder+"/"+place+".png")
		assert(stage.original_resident.visible)
		assert(is_equal_approx(stage.original_resident.region_rect.size.y * stage.original_resident.scale.y,184))
	stage.player_x = 1100
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(folder+"/zhou-side.png")
	assert(stage.original_resident.region_rect.position.x == 695)
	stage.route_id = "lookout_route"
	stage.hotspots.clear()
	stage.world_width = 4800
	stage.places.assign([{"id":"park","x":4000,"width":1600}])
	for x in [800,2300,3150]:
		stage.player_x = x
		stage.move_player(0,0)
		stage.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(folder+"/coast-%d.png" % x)
	state.current_minute = 1260
	stage.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(folder+"/coast-night.png")
	view.queue_free()
	await create_timer(0.3).timeout
	print("SUPPLIED ART PASS")
	quit(0)
