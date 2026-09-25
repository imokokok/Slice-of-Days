extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://removed_counter_items_cast_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	expect(game._definition("rice").is_empty(), "rice is absent from the ingredient catalog")
	expect(game.storage_display.find_child("Ingredient_rice", true, false) == null, "rice has no cabinet slot")
	game._show_pantry()
	expect(game._pantry_grid.find_child("Pantry_rice", true, false) == null, "rice cannot be selected through the pantry")
	game._close_modal()
	expect(game.hud.get_node_or_null("RiceCooker") == null, "the countertop cooker is gone")
	expect(not game._recipe_stand.visible and game.hud.find_child("ReferenceRecipeBook", true, false) == null, "countertop recipe stand and its hotspot are gone")
	expect(game._recipe_has_retired_ingredient({"dish": {"ingredients": ["rice", "egg"]}}), "historical rice recipe is recognized as retired")
	expect(not game._recipe_has_retired_ingredient({"dish": {"ingredients": ["egg", "tomato"]}}), "current ingredient recipe remains usable")
	game._show_cookbook()
	expect(game.modal_body.find_child("SharedRecipePage", true, false) != null, "cookbook pages remain accessible through the recipe button")
	game._close_modal()
	var source_path := ProjectSettings.globalize_path("res://../../data/npcs/core_residents.json")
	var canonical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var expected: Dictionary = {}
	for profile in canonical.get("profiles", []):
		expected[str(profile.id)] = str(profile.display_name)
	expect(expected.size() == 12 and game.session.customers.size() == 12, "kitchen uses the 12 authored town residents")
	for customer in game.session.customers:
		expect(expected.get(str(customer.id), "") == str(customer.name), "customer ID and visible name match the canonical resident roster: " + str(customer.id))
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: removed countertop items and canonical cast, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
