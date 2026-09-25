extends SceneTree
## Scripted QA playthrough recorded with Godot Movie Maker. Every frame comes
## from the production restaurant scene and its real inventory/physics/UI.
## godot --path . --write-movie <output.avi> --fixed-fps 24 --script res://tests/capture_full_cooking.gd

var game
var previous_pointer := Vector2.ZERO
var original_pointer := Vector2.ZERO

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
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
	_mouse(tomato_center + Vector2(0, -55) - drag_offset - blade_offset, "move")
	await _frames(12)
	_mouse(tomato_center + Vector2(0, 55) - drag_offset - blade_offset, "move")
	await _frames(6)
	_mouse(Vector2(1180, 690), "up")
	await _frames(32)
	var pieces := _pieces("tomato")
	if not _require(pieces.size() >= 2, "knife creates physical tomato pieces"): return
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
	if not _require(is_instance_valid(warmed_egg) and float(warmed_egg.get_meta("thermal", {}).get("cooked", 0.0)) >= 0.72, "egg reaches cooked state before serving"): return
	print("CAPTURE: egg cooking frames=", cooking_frames)
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
	await _frames(49)
	_mouse(pan_point, "up")
	await _frames(36)
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
	await _frames(100)
	if not _require(game._modal_kind == "feedback" and game.session.served == 1, "plated meal is served and reviewed"): return
	print("PASS: full cooking capture, served one physical meal")
	game.world.audio.muted = true
	game.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": Input.warp_mouse(original_pointer)
	quit(0)

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
	else: await create_timer(0.02).timeout

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
