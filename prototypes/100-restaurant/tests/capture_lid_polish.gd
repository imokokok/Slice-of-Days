extends SceneTree
## Short GPU/audio-mixer preview. Controlled preheat, then real-time production
## pressure, impulse, food physics and landing. No injected pressure or char.
var game
var prefix := ""
var force_offscreen_draw := false

func _initialize() -> void:
	# MovieWriter is initialized before _initialize; preserve the project's
	# original viewport size throughout the recording.
	root.size = Vector2i(1440, 851)
	root.gui_disable_input = true
	Engine.max_fps = 60
	# Optional GPU capture when macOS stops presenting a hidden window.
	# MovieWriter still records each simulation frame, so refresh its texture
	# after scene processing rather than accepting a frozen viewport image.
	process_frame.connect(_queue_movie_draw)
	call_deferred("run")

func _queue_movie_draw() -> void:
	if force_offscreen_draw: call_deferred("_draw_movie_frame")

func _draw_movie_frame() -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)

func snapshot(name: String) -> void:
	# GPU readbacks inside MovieWriter can stall/skip its output frames.
	# Capture stills in a separate non-movie run of this same production scene.
	if not Engine.get_write_movie_path().is_empty(): return
	# MovieWriter render callbacks must not await another frame_post_draw.
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(prefix + "-" + name + ".png")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): quit(1); return
	prefix = args[0]
	force_offscreen_draw = args.has("--offscreen-draw") and not Engine.get_write_movie_path().is_empty()
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://lid_polish_capture_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds": 3600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.set_process(false)
	var world = game.world
	world.audio.muted = true
	world.spawn_ingredient(game._definition("chicken"))
	var source: RigidBody2D = world._held
	source.position = Vector2(1220, 723)
	world.drop_held()
	var pieces: Array[RigidBody2D] = world.split_food(source, Vector2.RIGHT)
	if pieces.size() != 2:
		push_error("Preview could not prepare actual cut food")
		quit(1); return
	for i in pieces.size():
		var food := pieces[i]
		food.stop_board_settle()
		food.set_meta("on_board", false)
		food.position = world.pan.point(Vector2(783 + i * 48, 580))
		food.freeze = true
		food.set_meta("enrolled", true)
	world.reactions.set_physics_process(false)
	world.set_cooking(true)
	world.set_heat_level("high")
	world.reactions.pan_c = 235.0
	world.lid.close_lid()
	var elapsed := 0.0
	while world.lid.pressure < 0.975 and world.lid.burst_count == 0 and elapsed < 200.0:
		world.reactions.advance(0.25)
		elapsed += 0.25
	if world.lid.burst_count != 0 or world.lid.pressure < 0.975:
		push_error("Preview preheat did not reach a safe pre-pop fixture")
		quit(1); return
	for food in pieces: food.freeze = false
	world.reactions.set_physics_process(true)
	world.audio.muted = false
	world.audio.focused = true
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var label := Label.new()
	label.text = "锅盖爆锅 · 动作与声音预览"
	label.position = Vector2(580, 176)
	label.add_theme_font_override("font", preload("res://modules/restaurant/ui/paper_ink.gd").font())
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("fff0ce"))
	label.add_theme_color_override("font_shadow_color", Color("4d4c3b"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	overlay.add_child(label)
	snapshot("warning")
	var frames := 0
	while world.lid.burst_count == 0 and frames < 240:
		await process_frame
		frames += 1
	if world.lid.burst_count != 1:
		push_error("Actual hot-pan state did not pop")
		quit(1); return
	print("POP_PREVIEW process_frame=", Engine.get_process_frames(), " warning_frames=", frames)
	var pop_clock: float = world.reactions.clock
	var i := 0
	while world.reactions.clock - pop_clock < 4.0 and i < 480:
		await process_frame
		if i == 10: snapshot("release")
		if i == 50: snapshot("airborne")
		if i == 125: snapshot("landing")
		i += 1
	if world.lid._flight or world.lid._settling > 0.0 or world.lid.position != world.lid.HOME:
		push_error("Preview lid did not finish its support landing")
		quit(1); return
	snapshot("rest")
	print("PASS: GPU lid pop preview, real production animation and recorded audio, preheat=", elapsed)
	game.queue_free()
	overlay.queue_free()
	await process_frame
	quit(0)
