extends SceneTree
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://spatula_test_%s/cookbook.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var world = game.world
	world.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D = world._held
	world.drop_into_pan()
	await create_timer(0.7).timeout
	_expect(game.session.dish.size() == 1, "fixture ingredient actually lands in pan")
	var tool = world._spatula
	_expect(tool.visible and not tool.active, "spatula rests visibly next to stove")
	var mass := tomato.mass
	var home: Vector2 = tool.position
	_mouse(home + Vector2(55, 3), "down")
	await process_frame
	_expect(tool.active and world.get_held_name() == "锅铲", "actual handle press grabs spatula")
	_expect(is_equal_approx(tool.rotation, -PI/3), "picked up spatula is held diagonally with head below the grip")
	_expect(not world.spawn_ingredient(game._definition("egg")) and not world.pickup_knife(), "spatula occupies the hand exclusively")
	var center: Vector2 = tomato.global_position
	_mouse(center + Vector2(-45, -68), "move")
	await process_frame
	_mouse(center + Vector2(20, -76), "move")
	await physics_frame
	await process_frame
	_expect(world.audio.effects.stir_wet.playing, "tomato contact selects the wet-food stir sound")
	_expect(absf(tomato.angular_velocity) > 1.0, "head contact rotates actual rigid body")
	_expect(tomato.linear_velocity.y < -20, "head contact lifts actual rigid body")
	await physics_frame
	await process_frame
	_expect(tomato.global_position.distance_to(center) > 0.1, "food position changes through physics")
	_expect(tomato.mass == mass and not tomato.get_meta("cut"), "stirring preserves mass and does not cut ingredients")
	_expect(world._foods.get_child_count() == 1, "stirring never duplicates ingredients")
	await create_timer(0.16).timeout
	_expect(tomato.position.y < center.y - 8, "actual stir arc visibly raises food more than 8 pixels without an exaggerated launch")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	Input.parse_input_event(key)
	await process_frame
	_expect(not game.session.heating, "held spatula E never toggles stove")
	_mouse(Vector2(1400, 300), "up")
	await process_frame
	_expect(not tool.active and tool.position.is_equal_approx(home), "release over customer GUI puts spatula back")
	_mouse(Vector2(900, 580), "idle")
	await process_frame
	_expect(tool.position.is_equal_approx(home), "released spatula never follows mouse")
	_expect(tool.stir_sweep(Vector2(740, 600), Vector2(870, 600)) == 0, "idle tool cannot apply impulses")
	_expect(world.audio.stir_profile(game._definition("beef"))=="meat", "meat has a heavier contact profile")
	_expect(world.audio.stir_profile(game._definition("rice"))=="dry", "grain has a dry brushing profile")
	_expect(world.audio.stir_profile(game._definition("rock"))=="hard", "strange hard objects have a restrained knock profile")
	await create_timer(0.8).timeout
	_expect(game.session.dish.size() == 1, "flipped ingredient remains in recipe after settling")
	_mouse(home + Vector2(55, 3), "down")
	await process_frame
	var poster_key := InputEventKey.new()
	poster_key.pressed = true
	poster_key.physical_keycode = KEY_P
	poster_key.keycode = KEY_P
	Input.parse_input_event(poster_key)
	await process_frame
	_expect(game.modal.visible and not tool.active, "actual poster shortcut opens editor and releases spatula")
	_mouse(home + Vector2(55, 3), "down")
	await process_frame
	_expect(not tool.active, "modal prevents tool pickup through UI")
	_mouse(home, "up")
	game._close_modal()
	await process_frame
	_mouse(home + Vector2(55, 3), "down")
	await process_frame
	tool.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not tool.active, "window focus loss releases tool")
	_mouse(home, "up")
	# The wooden spoon has an actual open U collision instead of a visual-only
	# overlap. A small ingredient can sit between its two sides and bottom.
	var spoon=world.utensils[2]
	var spoon_home: Vector2=spoon.position
	_mouse(spoon_home+Vector2(55,3),"down")
	await physics_frame
	await process_frame
	_expect(spoon.active and spoon._bowl_shapes.size()==3,"wooden spoon enables three physical bowl edges")
	var enabled:=true
	for shape in spoon._bowl_shapes: enabled=enabled and not shape.disabled
	_expect(enabled,"spoon bowl collisions are active only while held")
	tomato.global_position=spoon.to_global(Vector2(-25,-5))
	tomato.linear_velocity=Vector2.ZERO
	tomato.angular_velocity=0
	await physics_frame
	await physics_frame
	var spoon_food_start:=tomato.global_position
	for i in range(10):
		_mouse(spoon_home+Vector2(60+i*5,3),"move")
		await physics_frame
	for i in range(8): await physics_frame
	await process_frame
	_expect(tomato.global_position.x>spoon_food_start.x+8 and spoon.bowl_contains(tomato),"food is physically carried inside the spoon depression")
	for i in range(7): _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await physics_frame
	await physics_frame
	_expect(spoon.rotation>0.72 and not spoon.bowl_contains(tomato),"tilting the spoon past its rim releases food to gravity")
	world.spawn_ingredient(game._definition("shrimp"))
	_expect(world._held==null,"held spoon prevents creating an unrelated hand-held item")
	_mouse(spoon_home,"up")
	await physics_frame
	await process_frame
	_expect(spoon._bowl_body.collision_mask==0,"putting the spoon down immediately removes hidden collision response")
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: spatula input and physics, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind in ["move", "idle"]:
		var e := InputEventMouseMotion.new()
		e.position = point
		e.global_position = point
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "move" else 0
		Input.parse_input_event(e)
	else:
		var e := InputEventMouseButton.new()
		e.position = point
		e.global_position = point
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = kind == "down"
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if e.pressed else 0
		Input.parse_input_event(e)

func _wheel(direction: MouseButton) -> void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*Vector2(500,580)
	e.global_position=e.position
	e.button_index=direction
	e.pressed=true
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
