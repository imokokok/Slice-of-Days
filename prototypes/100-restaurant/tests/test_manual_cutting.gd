extends SceneTree
## Real mouse/key input: contact, return stroke, and crosscut all use the visible knife.
var world
var failures: Array[String] = []
var checks := 0
var previous_pointer := Vector2.ZERO

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")

func _run() -> void:
	world = preload("res://modules/restaurant/world/kitchen_world.gd").new()
	root.add_child(world)
	await process_frame
	world.set_controls_enabled(true)
	var definition := {"id":"tomato", "name":"番茄", "color":"d95034", "mass":0.18, "friction":0.6, "bounce":0.1}
	_check(world.spawn_ingredient(definition), "whole tomato is available")
	var original: RigidBody2D = world._held
	world.drop_held(false)
	original.global_position = Vector2(1250, 735)
	original.set_deferred("position", original.position)
	original.freeze = true
	_press(world._knife_handle_rect().get_center())
	await process_frame
	_check(world._knife_held and world._knife_visual.cutting_guide, "grabbing the handle exposes the blade and direction")
	_move_blade_to(Vector2(1150, 680))
	await process_frame
	_move_blade_to(Vector2(1150, 775))
	await process_frame
	_check(_fragments().is_empty(), "the handle passing over food does not cut")
	_move_blade_to(Vector2(1250, 680))
	await process_frame
	_check(_fragments().is_empty(), "lifting the knife across food does not cut")
	_move_blade_to(Vector2(1250, 775))
	await process_frame
	var slices := _fragments()
	_check(slices.size() == 2, "downstroke under the steel blade creates two actual slices")
	if slices.size() == 2:
		_check(is_equal_approx(slices[0].mass + slices[1].mass, 0.18), "slice mass is conserved")
		_check(slices.all(func(item): return str(item.get_meta("cut_style")) == "slice"), "first stroke gives slice appearance")
	_release(Vector2(200, 300))
	await process_frame
	_check(not world._knife_visual.cutting_guide and is_zero_approx(world._knife_visual.rotation), "released knife rests without cutting guide")
	if slices.size() == 2:
		await create_timer(0.36).timeout
		var target: RigidBody2D = slices[0]
		target.global_position = Vector2(1250, 735)
		target.set_deferred("position", target.position)
		target.freeze = true
		target.rotation = 0.0
		slices[1].global_position = Vector2(1390, 735)
		slices[1].set_deferred("position", slices[1].position)
		slices[1].freeze = true
		_press(world._knife_handle_rect().get_center())
		await process_frame
		_key(KEY_R)
		await process_frame
		_check(is_equal_approx(world._knife_visual.rotation, -PI / 2.0), "R turns the visible blade for a crosscut")
		_check(_fragments().size() == 2, "rotation alone never cuts")
		_wheel(MOUSE_BUTTON_WHEEL_UP)
		await process_frame
		_check(is_equal_approx(world._knife_visual.rotation, -PI / 2.0 - PI / 12.0), "mouse wheel finely aims the held knife")
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
		await process_frame
		_check(is_equal_approx(world._knife_visual.rotation, -PI / 2.0), "reverse wheel restores crosscut angle")
		_move_blade_to(Vector2(1190, 735))
		await process_frame
		_move_blade_to(Vector2(1310, 735))
		await process_frame
		var pieces := _fragments()
		_check(pieces.size() == 3, "rightward crosscut splits one slice")
		_check(pieces.filter(func(item): return str(item.get_meta("cut_style")) == "dice").size() == 2, "crosscut pieces use diced appearance")
		var total_mass := 0.0
		for piece in pieces: total_mass += piece.mass
		_check(is_equal_approx(total_mass, 0.18), "crosscut conserves total ingredient mass")
		_release(Vector2(200, 300))
		await process_frame
	world.put_knife_back()
	var second_definition := {"id":"tomato", "name":"番茄", "color":"d95034", "mass":0.15, "friction":0.6, "bounce":0.1}
	_check(world.spawn_ingredient(second_definition), "another whole ingredient can be prepared after dicing")
	var second: RigidBody2D = world._held
	world.drop_held(false)
	second.global_position = Vector2(1110, 735)
	second.set_deferred("position", second.position)
	second.freeze = true
	var batch: String = str(second.get_meta("batch_uid"))
	var outline: PackedVector2Array = second.get_meta("fragment_polygon")
	var leftmost := INF
	for vertex in outline: leftmost = minf(leftmost, vertex.x)
	_press(world._knife_handle_rect().get_center())
	await process_frame
	_move_blade_to(Vector2(second.position.x + leftmost + 6.0, 680))
	await process_frame
	_move_blade_to(Vector2(second.position.x + leftmost + 6.0, 790))
	await process_frame
	var thin_slices := _fragments().filter(func(item): return str(item.get_meta("batch_uid")) == batch)
	_check(thin_slices.size() == 2, "off-centre blade path makes a real thin slice")
	if thin_slices.size() == 2:
		_check(minf(thin_slices[0].mass, thin_slices[1].mass) < second_definition.mass * 0.25, "cut position controls slice thickness and mass")
	_release(Vector2(200, 300))
	await process_frame
	world._sound.stop()
	await create_timer(0.1).timeout
	world.audio.muted = true
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: manual knife cutting, %d checks" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: manual knife cutting, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _move_blade_to(point: Vector2) -> void:
	var local_mid: Vector2 = world.KNIFE_BLADE_MID.rotated(world._knife_visual.rotation)
	_motion(point - world._knife_drag_offset - local_mid)

func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	previous_pointer = point
	Input.parse_input_event(event)

func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.pressed = false
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.relative = root.get_final_transform() * (point - previous_pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	previous_pointer = point
	Input.parse_input_event(event)

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

func _fragments() -> Array:
	var result := []
	for body in world._foods.get_children():
		if not body.is_queued_for_deletion() and int(body.get_meta("cut_depth", 0)) > 0:
			result.append(body)
	return result

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)
