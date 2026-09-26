extends SceneTree
## Drawn tools cross the recipe/order paper while held, then return to world depth.
var game
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	Engine.max_fps = 120
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://tool_layer_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.audio.muted = true
	await _draw_frames()
	var world = game.world
	var floating = world.get_node("FloatingTools")
	expect(floating.layer > game.layer.layer, "held tool canvas draws above the recipe and order papers")
	var baseline: Image
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		baseline = root.get_texture().get_image()

	world.pickup_knife()
	world._knife_visual.global_position = Vector2(1220, 600)
	await _draw_frames()
	expect(_fronted(floating, world._knife_visual), "held knife uses a visual-only foreground proxy")
	if baseline != null:
		await RenderingServer.frame_post_draw
		var held_image: Image = root.get_texture().get_image()
		var scale := Vector2(held_image.get_size()) / Vector2(1600, 946)
		var paper_region := Rect2i(Vector2i(Vector2(1135, 555) * scale), Vector2i(Vector2(170, 75) * scale))
		var changed := _changed_pixels(baseline, held_image, paper_region)
		print("recipe paper changed pixels: %d, capture %s, region %s" % [changed, held_image.get_size(), paper_region])
		expect(changed > 250, "GPU shows the knife over the recipe paper")
		var args := OS.get_cmdline_user_args()
		if not args.is_empty():
			expect(held_image.save_png(args[0]) == OK, "save held knife screenshot")
	world.put_knife_back()
	await _draw_frames()
	expect(_restored(floating, world._knife_visual), "knife returns to world depth after release")

	var sponge_home: Vector2 = world.sponge.position
	world.sponge.active = true
	world.sponge.position = Vector2(1220, 600)
	await _draw_frames()
	expect(_fronted(floating, world.sponge), "held sponge stays visible over paper")
	if baseline != null: await _check_gpu(baseline, "sponge", 80)
	world.sponge.release_tool()
	world.sponge.position = sponge_home
	await _draw_frames()
	expect(_restored(floating, world.sponge), "sponge returns to worktop depth")

	world.cloth.active = true
	world.cloth.position = Vector2(1220, 600)
	world.cloth.wetness = 0.8
	world.cloth.absorbed_kg = 0.002
	await _draw_frames()
	expect(_fronted(floating, world.cloth), "held cloth keeps its live wet appearance over paper")
	if baseline != null: await _check_gpu(baseline, "cloth", 150)
	world.cloth.release_tool()
	await _draw_frames()
	expect(_restored(floating, world.cloth), "cloth returns to worktop depth")

	expect(world.spawn_ingredient(game._definition("tomato")), "plate foreground has a real food body")
	var tomato: RigidBody2D = world._held
	world.drop_held(false)
	tomato.freeze = true
	tomato.set_meta("plated", true)
	tomato.position = world.plate.center
	world.plate.active = true
	world.plate.move_to(Vector2(1220, 600))
	await _draw_frames()
	expect(_fronted(floating, world.plate) and _fronted(floating, tomato.get_node("FoodArt")), "moving plate and its food share foreground depth")
	if baseline != null: await _check_gpu(baseline, "plate", 500)
	world.plate.active = false
	await _draw_frames()
	expect(_restored(floating, world.plate) and tomato.get_node("FoodArt").visible, "plate and food return to world depth")

	world.pickup_knife()
	await _draw_frames()
	world.set_controls_enabled(false)
	await _draw_frames()
	expect(not world._knife_held and _restored(floating, world._knife_visual), "modal restores the knife and clears its foreground copy")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: tool foreground, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _draw_frames() -> void:
	await process_frame
	await process_frame

func _fronted(floating: Node, source: Node2D) -> bool:
	var entry: Dictionary = floating.copies.get(source.get_instance_id(), {})
	return not entry.is_empty() and not source.visible and entry.proxy.transform.is_equal_approx(source.get_global_transform_with_canvas()) and (not source.has_method("paint") or entry.proxy.get_script().resource_path.ends_with("/utensil_proxy.gd"))

func _restored(floating: Node, source: Node2D) -> bool:
	return source.visible and not floating.copies.has(source.get_instance_id())

func _changed_pixels(before: Image, after: Image, region: Rect2i) -> int:
	var changed := 0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) > 0.15: changed += 1
	return changed

func _check_gpu(before: Image, label: String, minimum: int) -> void:
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var scale := Vector2(capture.get_size()) / Vector2(1600, 946)
	var region := Rect2i(Vector2i(Vector2(1135, 555) * scale), Vector2i(Vector2(170, 75) * scale))
	expect(_changed_pixels(before, capture, region) > minimum, "GPU shows held %s over the recipe paper" % label)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var path := args[0].get_basename() + "-" + label + ".png"
		expect(capture.save_png(path) == OK, "save held %s screenshot" % label)

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)
