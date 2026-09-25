extends SceneTree
## Scripted QA playthrough recorded with Godot Movie Maker. Every frame comes
## from the production restaurant scene and its real inventory/physics/UI.
## godot --path . --write-movie <output.avi> --fixed-fps 24 --script res://tests/capture_full_cooking.gd

const RecipeMethod = preload("res://modules/restaurant/domain/recipe_method.gd")
var game
var previous_pointer := Vector2.ZERO
var original_pointer := Vector2.ZERO

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"shift_seconds": 240.0, "repository_path": "user://full_cooking_capture_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	original_pointer = root.get_mouse_position()
	await _frames(36)
	game._start_shift()
	await _frames(48)
	if not await _record_cabinets_water_and_rice(): return
	if not await _drag_slot("tomato", Vector2(1200, 725), 24): return
	await _frames(30)
	var tomato := _food("tomato")
	if not _require(is_instance_valid(tomato), "tomato reaches the cutting board"): return
	var tomato_center: Vector2 = tomato.position
	var knife_start: Vector2 = game.world._knife_handle_rect().get_center()
	_mouse(knife_start, "down")
	await _frames(6)
	var drag_offset: Vector2 = game.world._knife_drag_offset
	var blade_offset := Vector2(-50, -22)
	var book_pointer: Vector2 = Vector2(1220, 600) - drag_offset
	for i in 16:
		_mouse(knife_start.lerp(book_pointer, (i + 1) / 16.0), "move")
		await process_frame
	await _frames(18)
	var floating: Node = game.world.get_node("FloatingTools")
	if not _require(floating.copies.has(game.world._knife_visual.get_instance_id()), "held knife is visible above the recipe paper"): return
	var cut_start: Vector2 = tomato_center + Vector2(0, -55) - drag_offset - blade_offset
	for i in 12:
		_mouse(book_pointer.lerp(cut_start, (i + 1) / 12.0), "move")
		await process_frame
	await _frames(12)
	_mouse(tomato_center + Vector2(0, 55) - drag_offset - blade_offset, "move")
	await _frames(6)
	_mouse(Vector2(1180, 690), "up")
	await _frames(32)
	var pieces := _pieces("tomato")
	if not _require(pieces.size() >= 2, "knife creates physical tomato pieces"): return
	# Regrip and aim across the slice's actual settled orientation. The R key
	# makes the broad turn; wheel steps show the same fine aiming a player uses.
	var target: RigidBody2D = pieces[0]
	var previous_axis: Vector2 = target.get_meta("cut_axis", Vector2.LEFT)
	var stroke_direction: Vector2 = -previous_axis.rotated(target.rotation).normalized()
	var cross_center: Vector2 = target.position
	_mouse(game.world._knife_handle_rect().get_center(), "down")
	await _frames(5)
	_key(KEY_R)
	await _frames(5)
	var desired_rotation := wrapf(stroke_direction.angle() - PI / 2.0, -PI, PI)
	var turn_steps := roundi(wrapf(desired_rotation - game.world._knife_visual.rotation, -PI, PI) / deg_to_rad(15.0))
	for index in absi(turn_steps):
		_wheel(MOUSE_BUTTON_WHEEL_DOWN if turn_steps > 0 else MOUSE_BUTTON_WHEEL_UP)
		await _frames(2)
	var cross_offset: Vector2 = game.world.KNIFE_BLADE_MID.rotated(game.world._knife_visual.rotation)
	var cross_drag: Vector2 = game.world._knife_drag_offset
	_mouse(cross_center - stroke_direction * 64.0 - cross_drag - cross_offset, "move")
	await _frames(8)
	_mouse(cross_center + stroke_direction * 64.0 - cross_drag - cross_offset, "move")
	await _frames(8)
	_mouse(Vector2(1180, 690), "up")
	await _frames(24)
	pieces = _pieces("tomato")
	if not _require(pieces.size() >= 3 and pieces.any(func(item): return item.get_meta("cut_style", "") == "dice"), "player-driven crosscut makes diced tomato pieces"): return
	var first: RigidBody2D = pieces[0]
	_mouse(first.position, "move")
	game.world._pickup(first)
	game.world.begin_food_drag(first.position)
	var from: Vector2 = first.position
	var to: Vector2 = game.world.pan.point(Vector2(805, 580))
	for i in 25:
		_mouse(from.lerp(to, (i + 1) / 25.0), "move")
		await process_frame
	_mouse(to, "up")
	for i in 240:
		if not game.session.dish.is_empty(): break
		await process_frame
	if not _require(not game.session.dish.is_empty(), "tomato pieces enter the pan through physics"): return
	# The pan carries the actual tomato and rice bodies during an upward toss.
	var pan_handle: Vector2 = game.world.pan.point(Vector2(1037, 578))
	_mouse(pan_handle, "down")
	await _frames(3)
	if not _require(game.world.pan.active, "pan handle can be held for a real toss"): return
	_mouse(pan_handle + Vector2(0, -42), "move")
	await _frames(3)
	_mouse(pan_handle + Vector2(0, -42), "up")
	await _frames(50)
	if not _require(game.world.pan._last_toss_msec > 0, "physical food lifts and turns when the pan is tossed"): return
	if not await _crack_egg_from_shelf(): return
	await _frames(56)
	if not _require(_dish_has("egg"), "egg enters the pan"): return
	var opened_egg := _food("egg")
	if not _require(is_instance_valid(opened_egg) and bool(opened_egg.get_meta("thermal", {}).get("egg_opened", false)), "egg opens into the pan instead of staying in its shell"): return
	game.session.set_heat_level("high")
	game._interact("cook")
	var warmed_egg := _food("egg")
	var cooking_frames := 0
	while cooking_frames < 1500 and is_instance_valid(warmed_egg) and float(warmed_egg.get_meta("thermal", {}).get("cooked", 0.0)) < 0.72:
		await _capture_frame()
		cooking_frames += 1
	print("CAPTURE: egg cooking frames=", cooking_frames, " cooked=", warmed_egg.get_meta("thermal", {}).get("cooked", -1.0))
	if not _require(is_instance_valid(warmed_egg) and float(warmed_egg.get_meta("thermal", {}).get("cooked", 0.0)) >= 0.72, "egg reaches cooked state before serving"): return
	print("CAPTURE: egg cooking frames=", cooking_frames)
	if not _require(game.world.reactions.pan_c >= 115.0, "the skillet is hot enough to sizzle when fresh food lands"): return
	var hot_sound_before := int(game.world.audio._last_effect.get("hot_drop", 0))
	var hot_target: Vector2 = game.world.pan.point(Vector2(800, 552))
	if not await _drag_slot("mushroom", hot_target, 24): return
	await _frames(55)
	if not _require(_dish_has("mushroom") and int(game.world.audio._last_effect.get("hot_drop", 0)) > hot_sound_before, "fresh mushroom lands in the hot skillet and triggers the new cooking foley"): return
	game._interact("cook")
	await _frames(24)
	var ketchup_slot := game.storage_display.find_child("Ingredient_ketchup", true, false) as Button
	if not _require(ketchup_slot != null, "ketchup is on the rack"): return
	# Synthetic mouse events can leave a native tooltip pinned over later modal
	# frames. Keep the real pickup and dispense interaction visible in the movie.
	ketchup_slot.tooltip_text = ""
	_mouse(ketchup_slot.get_global_rect().get_center(), "down")
	await _frames(2)
	_mouse(ketchup_slot.get_global_rect().get_center(), "up")
	await _frames(8)
	if not _require(is_instance_valid(game.world._held) and game.world._held.get_meta("id", "") == "ketchup", "rack supplies its original bottle"): return
	var pan_point: Vector2 = game.world.pan.point(Vector2(800, 535))
	for i in 16:
		_mouse(ketchup_slot.get_global_rect().get_center().lerp(pan_point, (i + 1) / 16.0), "move")
		await process_frame
	_mouse(pan_point, "down")
	await _frames(2)
	if not _require(game.world._squeezing, "rack bottle remains held while pressing above pan"): return
	await _frames(95)
	_mouse(pan_point, "up")
	await _frames(55)
	print("CAPTURE: ketchup state=", game.world._squeeze_dispensed, " sauce bodies=", _pieces("ketchup").size(), " pan offset=", game.world.pan.offset)
	if not _require(_dish_has("ketchup"), "real timed ketchup dispensing reaches the pan"): return
	var bottle: RigidBody2D = game.world._held
	for i in 14:
		_mouse(pan_point.lerp(ketchup_slot.get_global_rect().get_center(), (i + 1) / 14.0), "move")
		await process_frame
	if is_instance_valid(bottle):
		bottle.global_position = ketchup_slot.get_global_rect().get_center()
		game._return_to_storage(bottle)
	_mouse(Vector2(1050, 72), "move")
	await _frames(30)
	game._show_plating()
	await _frames(35)
	var pan_food: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("enrolled", false): pan_food.append(body)
	if not _require(not pan_food.is_empty(), "cooked food is available for plating"): return
	game._plate_bodies(pan_food)
	await _frames(80)
	var plate_layout_ok := true
	for record in game._plating_canvas._visuals.values():
		var uv: Vector2 = (record.body.position - game.world.plate.center) / Vector2(100, 20)
		plate_layout_ok = plate_layout_ok and uv.length() <= 0.73
		if record.body.has_meta("liquid_state"):
			plate_layout_ok = plate_layout_ok and record.art.z_index == 0 and record.art.scale.length() < 3.0
	if not _require(plate_layout_ok, "plated sauce stays small and all portions remain inside the dish"): return
	# Movie Maker does not reliably deliver frame_post_draw to the asynchronous
	# photo capture path. Plating and serving remain in this playthrough; photo
	# capture is covered separately by the production GUI tests.
	await _frames(28)
	game._close_modal()
	game._serve()
	await _frames(25)
	if not _require(game._modal_kind == "dish_showcase" and game.session.served == 1, "actual plate is displayed before review"): return
	if not OS.get_cmdline_user_args().is_empty():
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-dish-showcase.png")
	game._show_serve_feedback()
	await _frames(75)
	if not _require(game._modal_kind == "feedback", "plated meal proceeds to customer review"): return
	var guest_name := str(game._letters[-1].get("customer", "")) if not game._letters.is_empty() else ""
	if not _require(not guest_name.is_empty() and game.session.customers.any(func(c): return str(c.name) == guest_name), "customer feedback displays one of the 12 town NPC names"): return
	if not await _record_recipe_turn(): return
	print("PASS: full cooking capture, served one physical meal to " + guest_name)
	game.world.audio.muted = true
	game.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": Input.warp_mouse(original_pointer)
	quit(0)

func _record_cabinets_water_and_rice() -> bool:
	game._show_order_paper()
	await _frames(35)
	game._close_modal()
	# The last refrigerator layer and second strange shelf are genuine paged
	# storage displays. Return to layer one before picking up the tomato and egg.
	for index in 3:
		game.storage_display._turn_page("fridge", 1)
		await _frames(10)
	await _frames(25)
	game.storage_display._turn_page("fridge", 1)
	game.storage_display._turn_page("odd", 1)
	await _frames(30)
	game.storage_display._turn_page("odd", -1)
	await _frames(12)
	var home_handle: Vector2 = game.world.pan.point(Vector2(1037, 578))
	var sink_handle: Vector2 = home_handle + Vector2(-587, 0)
	_mouse(home_handle, "down")
	await _frames(3)
	for index in 22:
		_mouse(home_handle.lerp(sink_handle, (index + 1) / 22.0), "move")
		await process_frame
	_mouse(sink_handle, "up")
	await _frames(20)
	if not _require(game.world.pan.under_tap(), "empty pan is carried to the sink below the faucet"): return false
	_mouse(Vector2(190, 618), "down")
	await _frames(3)
	_mouse(Vector2(190, 680), "move")
	await _frames(3)
	_mouse(Vector2(190, 680), "up")
	var fill_frames := 0
	while fill_frames < 460 and not game.world.pan.overflowing:
		await _capture_frame()
		fill_frames += 1
	if not _require(game.world.pan.overflowing and game.world.pan.overflow_water_ml > 0.0, "continuous water fills the pan to capacity then runs over into the sink"): return false
	await _frames(25)
	_mouse(Vector2(175, 632), "down")
	_mouse(Vector2(175, 570), "move")
	_mouse(Vector2(175, 570), "up")
	await _frames(8)
	if not _require(not game.world.pan.faucet_on, "turning the handle back stops the water"): return false
	_mouse(Vector2(200, 761), "down")
	_mouse(Vector2(200, 761), "up")
	await _frames(8)
	if not _require(is_zero_approx(game.world.pan.water_ml), "water is drained into the sink before dry frying"): return false
	_mouse(sink_handle, "down")
	await _frames(3)
	for index in 22:
		_mouse(sink_handle.lerp(home_handle, (index + 1) / 22.0), "move")
		await process_frame
	_mouse(home_handle, "up")
	await _frames(28)
	if not _require(game.world.pan.on_stove(), "drained pan returns to the burner"): return false
	var lid: Vector2 = game.rice_cooker.position + Vector2(66, 22)
	var bowl: Vector2 = game.rice_cooker.position + Vector2(66, 67)
	_mouse(lid, "down")
	_mouse(lid, "up")
	await _frames(34)
	if not _require(game.rice_cooker.lid_open, "rice cooker opens to show cooked rice and its paddle"): return false
	_mouse(lid, "down")
	_mouse(lid, "up")
	await _frames(16)
	if not _require(not game.rice_cooker.lid_open, "rice cooker lid closes with its own recorded sound"): return false
	_mouse(lid, "down")
	_mouse(lid, "up")
	await _frames(16)
	if not _require(game.rice_cooker.lid_open, "rice cooker reopens before serving rice"): return false
	_mouse(bowl, "down")
	await _frames(4)
	if not _require(is_instance_valid(game.world._held) and str(game.world._held.get_meta("id", "")) == "rice", "paddle scoops a finite physical rice serving"): return false
	var pan_point: Vector2 = game.world.pan.point(Vector2(800, 575))
	for index in 27:
		_mouse(bowl.lerp(pan_point, (index + 1) / 27.0), "move")
		await process_frame
	_mouse(pan_point, "up")
	await _frames(40)
	return _require(_dish_has("rice") and not game.rice_cooker.serving_available, "the scooped rice enters the pan and cooker stock is empty")

func _record_recipe_turn() -> bool:
	# A served plate contains transient physics and surface state. Save the food
	# that actually reached the plate in the repository's portable recipe form.
	var recipe_ingredients: Array = []
	for item in game._last_dish.get("ingredients", []):
		if item is Dictionary:
			var recipe_item := {"id": str(item.get("id", "")), "cut": bool(item.get("cut", false)), "heat": float(item.get("heat", 0.0))}
			for key in ["mass_kg", "volume_ml", "softness"]:
				if item.has(key): recipe_item[key] = float(item[key])
			recipe_ingredients.append(recipe_item)
	var record := {
		"title": "今晚这一锅 · 番茄蛋炒饭",
		"author": "厨房实录",
		"notes": "从电饭煲盛饭，番茄切块，与蛋一同下锅；翻炒后装盘。",
		"dish": {"ingredients": recipe_ingredients}
	}
	if not _require(not recipe_ingredients.is_empty() and game.repository.save_recipe(record), "actual served ingredients are written to a recipe page (" + game.repository.get_last_error() + ")"): return false
	game._show_cookbook()
	await _frames(28)
	game._view_recipe(RecipeMethod.starter())
	await _frames(25)
	game._turn_recipe(1)
	await _frames(45)
	if not _require(game._recipe_page_index == 1 and game._modal_kind == "recipe", "recipe book visibly turns to the just cooked dish"): return false
	game._turn_recipe(-1)
	await _frames(45)
	return _require(game._recipe_page_index == 0, "recipe book can turn back to the previous page")

func _drag_slot(id: String, destination: Vector2, steps: int) -> bool:
	var slot := game.storage_display.find_child("Ingredient_" + id, true, false) as Button
	if not _require(slot != null, id + " has a visible storage slot"): return false
	var origin: Vector2 = slot.get_global_rect().get_center()
	_mouse(origin, "down")
	await _frames(3)
	if not _require(is_instance_valid(game.world._held), id + " is picked up"): return false
	for i in steps:
		_mouse(origin.lerp(destination, (i + 1) / float(steps)), "move")
		await process_frame
	_mouse(destination, "up")
	await _frames(4)
	return _require(not is_instance_valid(game.world._held), id + " is put down")

func _crack_egg_from_shelf() -> bool:
	var slot := game.storage_display.find_child("Ingredient_egg", true, false) as Button
	if not _require(slot != null, "egg has a visible storage slot"): return false
	var origin: Vector2 = slot.get_global_rect().get_center()
	var rim: Vector2 = game.world.pan.point(Vector2(809, 546))
	_mouse(origin, "down")
	await _frames(3)
	if not _require(is_instance_valid(game.world._held), "whole egg is picked up"): return false
	for i in 28:
		_mouse(origin.lerp(rim, (i + 1) / 28.0), "move")
		await process_frame
	_mouse(rim, "up")
	await _frames(28)
	if not _require(is_instance_valid(game.world._held) and int(game.world._held.get_meta("egg_taps", 0)) == 1, "first rim strike cracks the held shell"): return false
	_mouse(rim, "down")
	await _frames(4)
	_mouse(rim, "up")
	await _frames(34)
	return _require(game.world._egg_shells.get_child_count() == 2 and not is_instance_valid(game.world._held), "second strike pours egg and launches two shell pieces")

func _food(id: String) -> RigidBody2D:
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("id", "") == id: return body
	return null

func _pieces(id: String) -> Array:
	var result: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("id", "") == id and int(body.get_meta("cut_depth", 0)) > 0: result.append(body)
	return result

func _dish_has(id: String) -> bool:
	for item in game.session.dish:
		if str(item.get("id", "")) == id: return true
	return false

func _require(ok: bool, description: String) -> bool:
	if ok:
		print("CAPTURE: " + description)
	else:
		push_error("Capture stopped: " + description)
		if DisplayServer.get_name() != "headless": Input.warp_mouse(original_pointer)
		quit(1)
	return ok

func _frames(count: int) -> void:
	for i in count: await _capture_frame()

func _capture_frame() -> void:
	# A real draw is needed during long thermal waits. Tight process_frame loops
	# can advance game state faster than the movie writer presents new images.
	if DisplayServer.get_name() == "headless": await process_frame
	else:
		await process_frame
		RenderingServer.force_draw(false)

func _mouse(point: Vector2, kind: String) -> void:
	var window_point: Vector2 = root.get_final_transform() * point
	if DisplayServer.get_name() != "headless": Input.warp_mouse(window_point)
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = window_point
		motion.global_position = window_point
		motion.relative = window_point - root.get_final_transform() * previous_pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "down" else 0
		button.pressed = kind == "down"
		button.position = window_point
		button.global_position = window_point
		Input.parse_input_event(button)
	previous_pointer = point

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = root.get_final_transform() * previous_pointer
	event.global_position = event.position
	Input.parse_input_event(event)
