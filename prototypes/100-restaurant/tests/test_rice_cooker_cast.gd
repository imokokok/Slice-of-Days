extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://rice_cooker_cast_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var cooker: Control = game.rice_cooker
	expect(game.storage_display.find_child("Ingredient_rice", true, false) == null, "rice has no fridge or shelf duplicate")
	game._show_pantry()
	expect(game._pantry_grid.find_child("Pantry_rice", true, false) == null, "catalog cannot bypass the rice cooker lid")
	game._close_modal()
	_click(cooker, Vector2(66, 22))
	expect(cooker.lid_open, "first click visibly opens hinged lid")
	game.world.pickup_knife()
	_click(cooker, Vector2(66, 67))
	expect(not game._stock.has("rice") and cooker.serving_available, "occupied hands cannot create or consume rice")
	game.world._release_knife()
	_click(cooker, Vector2(66, 67))
	var serving: RigidBody2D = game.world._held
	expect(is_instance_valid(serving) and str(serving.get_meta("id", "")) == "rice", "clicking visible rice scoops its actual physical portion")
	expect(not cooker.lid_open and not cooker.serving_available and not bool(game._stock.get("rice", true)), "empty cooker closes and source stock is debited")
	var identity := str(serving.get_meta("instance_uid", ""))
	game.world.begin_food_drag(serving.position)
	game.world._move_dragged_food(cooker.get_global_rect().get_center())
	game.world._finish_food_drag()
	expect(not is_instance_valid(game.world._held) and cooker.serving_available, "untouched rice can be returned to the cooker")
	_click(cooker, Vector2(66, 22))
	_click(cooker, Vector2(66, 67))
	expect(is_instance_valid(game.world._held) and str(game.world._held.get_meta("instance_uid", "")) == identity, "second scoop reuses the identical returned rice body")
	game.world._held.set_meta("saved_heat", 1.0)
	game.world._held.position = cooker.get_global_rect().get_center()
	expect(not game._return_to_storage(game.world._held), "heated rice cannot return as a fresh serving")
	var source_path := ProjectSettings.globalize_path("res://../../data/npcs/core_residents.json")
	var canonical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var expected: Dictionary = {}
	for profile in canonical.get("profiles", []):
		expected[str(profile.id)] = str(profile.display_name)
	expect(expected.size() == 12 and game.session.customers.size() == 12, "kitchen uses the 12 authored town residents")
	for customer in game.session.customers:
		expect(expected.get(str(customer.id), "") == str(customer.name), "customer ID and visible name match the canonical resident roster: " + str(customer.id))
	game.world.discard_held()
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: rice cooker and canonical cast, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _click(cooker: Control, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	cooker._gui_input(event)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
