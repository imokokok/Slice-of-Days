extends SceneTree
## Regression: real input press / motion / release, including release over GUI.
var world
var failures: Array[String] = []
var checks := 0
var previous_pointer := Vector2.ZERO

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	world = preload("res://modules/restaurant/world/kitchen_world.gd").new()
	root.add_child(world)
	await process_frame
	world.set_controls_enabled(true)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var blocking_panel := Panel.new()
	blocking_panel.position = Vector2(50, 160)
	blocking_panel.size = Vector2(340, 580)
	blocking_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocking_panel)
	await process_frame
	var initial: Vector2 = world._knife_visual.global_position
	_press(world._knife_handle_rect().get_center())
	await process_frame
	_expect(world._knife_held and world._knife_cutting, "actual handle press starts held drag and cutting")
	_expect(world._knife_visual.global_position.is_equal_approx(initial), "pickup preserves the grabbed offset and never jumps")
	_motion(initial+Vector2(83,17), true)
	await process_frame
	var dragged: Vector2 = world._knife_visual.global_position
	_expect(dragged.is_equal_approx(initial+Vector2(32.5,-16.5)), "held motion preserves exact cursor-to-handle offset")
	_release(Vector2(210, 330))
	await process_frame
	_expect(not world._knife_held and not world._knife_cutting, "mouse release over blocking GUI always ends tool drag")
	_expect(world._knife_visual.global_position.is_equal_approx(dragged), "release puts knife at its last valid board location")
	_motion(Vector2(970, 280), false)
	await process_frame
	_expect(world._knife_visual.global_position.is_equal_approx(dragged), "mouse movement after release cannot move the knife")
	_expect(world._knife_visual.visible, "released knife remains visibly resting on board")
	# A moved knife's handle must remain grabbable at its new position.
	_press(dragged + Vector2(40,24))
	await process_frame
	_expect(world._knife_held, "resting knife hitbox follows its new rendered position")
	_motion(Vector2(220, 350), true)
	await process_frame
	_release(Vector2(220, 350))
	await process_frame
	_expect(world._knife_visual.global_position.is_equal_approx(dragged), "release outside board returns to last valid board position")
	var return_key := InputEventKey.new()
	return_key.physical_keycode = KEY_Q
	return_key.keycode = KEY_Q
	return_key.pressed = true
	Input.parse_input_event(return_key)
	await process_frame
	_expect(world._knife_visual.global_position.is_equal_approx(Vector2(1407,730)), "Q returns a released knife to its home rest")
	var def := {"id":"tomato", "name":"番茄", "color":"d95034", "mass":0.18, "friction":0.6, "bounce":0.1}
	_expect(world.spawn_ingredient(def), "whole food is available for input-driven cut test")
	var original: RigidBody2D = world._held
	world.drop_held(false)
	original.global_position = Vector2(1210,735)
	original.set_deferred("position", original.position)
	original.freeze = true
	_motion(Vector2(420, 630), false)
	await process_frame
	_expect(_fragments().is_empty(), "idle mouse motion never cuts food")
	world._perform_knife_sweep(Vector2(1210,695), Vector2(1210,775))
	_expect(_fragments().is_empty(), "cutting helper refuses an idle released knife")
	_press(world._knife_handle_rect().get_center())
	await process_frame
	_expect(_fragments().is_empty(), "press without a blade sweep does not cut")
	_motion(Vector2(1210,680)-world._knife_drag_offset-Vector2(-50,-22),true)
	await process_frame
	_motion(Vector2(1210,775)-world._knife_drag_offset-Vector2(-50,-22),true)
	await process_frame
	var fragments := _fragments()
	_expect(fragments.size() == 2, "actual held mouse motion drives blade sweep and splits food")
	if fragments.size() == 2:
		_expect(is_equal_approx(fragments[0].mass + fragments[1].mass, 0.18), "input-driven split conserves food mass")
	_release(Vector2(210, 330))
	await process_frame
	var released: Vector2 = world._knife_visual.global_position
	_motion(Vector2(400, 580), false)
	_motion(Vector2(430, 640), false)
	await process_frame
	_expect(not world._knife_held and not world._knife_cutting, "post-cut UI release also clears both drag states")
	_expect(world._knife_visual.global_position.is_equal_approx(released), "released knife stays still after further mouse travel")
	_expect(_fragments().size() == 2, "mouse-up movement cannot make accidental extra cuts")
	_press(world._knife_visual.global_position + Vector2(40,24))
	await process_frame
	world.set_controls_enabled(false)
	_expect(not world._knife_held and not world._knife_cutting, "opening a modal terminates an active knife drag")
	_release(Vector2(800, 200))
	world._sound.stop()
	# Let the audio mixer retire the just-played knife transient before process exit.
	await create_timer(0.08).timeout
	world.audio.muted = true
	await create_timer(0.14).timeout
	world.queue_free()
	ui.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real knife mouse drag, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: real knife mouse drag, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	# Input.parse_input_event uses window pixels; account for the headless 64px window.
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

func _motion(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.relative = (root.get_final_transform() * point) - (root.get_final_transform() * previous_pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	previous_pointer = point
	Input.parse_input_event(event)

func _fragments() -> Array:
	var result := []
	for body in world._foods.get_children():
		if not body.is_queued_for_deletion() and int(body.get_meta("cut_depth", 0)) > 0:
			result.append(body)
	return result

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
