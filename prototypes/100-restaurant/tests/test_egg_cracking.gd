extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://egg_crack_%s/book.json" % Time.get_ticks_usec(), "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var world = game.world
	var rim: Vector2 = world.pan.point(Vector2(809, 546))
	_check(world.spawn_ingredient(game._definition("egg")), "a whole egg can be taken")
	var egg: RigidBody2D = world._held
	var original_mass := egg.mass
	world.drop_into_pan()
	for i in 35: await physics_frame
	_check(not bool(egg.get_meta("thermal", {}).get("egg_opened", false)), "dropping an egg in the pan leaves its shell intact")
	world._pickup(egg)
	_mouse(rim, true)
	await process_frame
	_mouse(rim, false)
	await process_frame
	_check(world._held == egg and int(egg.get_meta("egg_taps", 0)) == 1, "first rim strike leaves egg held with a fissure")
	_check(world._egg_shells.get_child_count() == 0, "first strike does not fabricate shell waste")
	_mouse(rim, true)
	await process_frame
	_mouse(rim, false)
	await process_frame
	_check(world._held == null and bool(egg.get_meta("thermal", {}).get("egg_opened", false)), "second rim strike opens the same egg")
	_check(world._egg_shells.get_child_count() == 2, "two shell pieces launch from the struck egg")
	var shell_mass := 0.0
	for shell in world._egg_shells.get_children():
		shell_mass += shell.mass
		_check(str(shell.get_meta("source_uid", "")) == str(egg.get_meta("instance_uid", "")), "shell piece preserves egg provenance")
	_check(absf(egg.mass + shell_mass - original_mass) < 0.00001, "edible egg and shell masses sum to the original")
	await create_timer(0.8).timeout
	_check(egg.get_meta("enrolled", false), "poured egg enrolls in the pan after the animation")
	_check(world._egg_shells.get_child_count() == 2, "shell pieces persist after their fall")
	for shell in world._egg_shells.get_children():
		_check(shell.position.x < 600.0 and not world.pan.contains(shell.position), "shell lands on the spare counter, outside the pan")
	world.clear_workspace()
	_check(absf(world.shell_waste_kg - shell_mass) < 0.00001, "cleaning records shell mass as waste")
	if failures.is_empty():
		print("PASS: egg cracking (%s checks)" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)
