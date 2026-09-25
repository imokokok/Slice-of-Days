extends SceneTree
## Checks that plating cannot invent sauce or broth and that recipe matching
## reflects quantities, preparation, and extra ingredients.
var game: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://serving_continuity_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game.world.audio.muted = true
	game._show_plating()
	check(is_zero_approx(game._dispense_plating_sauce("ketchup", 5.0)), "uncollected bottle cannot make sauce on the serving plate")
	game._close_modal()
	game._take_ingredient(game._definition("ketchup"))
	var bottle: RigidBody2D = game.world._held
	check(is_instance_valid(bottle), "the displayed rack supplies the real ketchup bottle")
	if not is_instance_valid(bottle):
		finish()
		return
	bottle.position = Vector2(1000, 700)
	game.world.drop_held(false)
	await process_frame
	game._show_plating()
	var remaining_before := float(bottle.get_meta("remaining_ml", 0.0))
	var mass_before := bottle.mass
	var delivered: float = game._dispense_plating_sauce("ketchup", 7.25)
	check(is_equal_approx(delivered, 7.25) and is_equal_approx(float(bottle.get_meta("remaining_ml", 0.0)) + delivered, remaining_before), "plating sauce debits the same physical bottle by the served volume")
	check(absf((mass_before - bottle.mass) - delivered * float(game._definition("ketchup").get("density_g_ml", 1.03)) / 1000.0) < 0.00001, "bottle weight decreases with its actual sauce contents")
	bottle.set_meta("remaining_ml", 0.0)
	bottle.refresh_response()
	check(is_zero_approx(game._dispense_plating_sauce("ketchup", 3.0)), "empty bottle cannot garnish a dish")
	game.world.pan.water_ml = 250.0
	game.world.pan.water_heat = 92.0
	game._set_serving_vessel("bowl")
	var served_water: float = game._transfer_broth_to_bowl(100.0)
	check(is_equal_approx(served_water, 100.0) and is_equal_approx(game.world.pan.water_ml, 150.0) and is_equal_approx(float(game.session.plate().get("water_ml", 0.0)), 100.0), "served soup belongs to the bowl and leaves the pan")
	game._plating_canvas.clear_sauce()
	check(is_equal_approx(float(game.session.presentation.get("broth_ml", 0.0)), 100.0) and game.session.garnishes.is_empty() and is_equal_approx(game.session.plating_waste_ml, delivered), "cleaning sauce records waste without discarding the soup")
	check(is_equal_approx(game._return_broth_to_pan(), 100.0) and is_equal_approx(game.world.pan.water_ml, 250.0) and is_zero_approx(float(game.session.plate().get("water_ml", 0.0))), "returning soup to the pan conserves volume and removes it from the dish")
	game.world.pan.water_ml = 1480.0
	game.session.presentation["broth_ml"] = 100.0
	check(is_zero_approx(game._return_broth_to_pan()) and is_equal_approx(game.world.pan.water_ml, 1480.0) and is_equal_approx(float(game.session.presentation.get("broth_ml", 0.0)), 100.0), "a full pan cannot silently absorb and erase bowl contents")
	game.world.pan.water_ml = 250.0
	game.session.presentation.erase("broth_ml")
	var requested := {"dish": {"ingredients": [{"id": "tomato", "mass_kg": 0.15, "cut": true, "heat": 6.0}], "water_ml": 250.0}}
	var correct := {"ingredients": [{"id": "tomato", "mass_kg": 0.15, "cut": true, "heat": 6.0}], "water_ml": 250.0}
	var wrong := {"ingredients": [{"id": "tomato", "mass_kg": 0.01, "cut": false, "heat": 0.0}, {"id": "egg", "mass_kg": 0.06}], "water_ml": 0.0}
	check(is_equal_approx(game.session._recipe_match(correct, requested), 1.0), "faithful cooking scores a full recipe match")
	check(game.session._recipe_match(wrong, requested) < 0.1, "tiny raw uncut tomato, an extra egg, and missing soup cannot report a full match")
	var mixed := {"ingredients": [{"id": "tomato", "mass_kg": 0.01, "cut": true, "heat": 6.0}, {"id": "tomato", "mass_kg": 0.14, "cut": false, "heat": 0.0}], "water_ml": 250.0}
	check(game.session._recipe_match(mixed, requested) < 0.6, "one cooked fragment cannot certify a mostly whole raw ingredient")
	game._close_modal()
	game._take_ingredient(game._definition("tomato"))
	game.world.drop_into_pan()
	await create_timer(0.8).timeout
	game.world.pan.water_ml = 100.0
	game.world.pan.water_heat = 90.0
	game._interact("plate")
	game._plate_bodies(game.world._foods.get_children())
	game._set_serving_vessel("bowl")
	game._transfer_broth_to_bowl(100.0)
	game.session.start_shift()
	game._close_modal()
	game._serve()
	var showcase: Node = game.modal_body.find_child("FinishedDishShowcase", true, false)
	check(showcase != null and game._modal_kind == "dish_showcase" and is_equal_approx(float(showcase.presentation_data().get("broth_ml", 0.0)), 100.0), "served showcase keeps the same bowl and soup after the live session clears")
	check(is_equal_approx(float(game._last_dish.get("water_ml", 0.0)), 100.0) and is_zero_approx(game.world.pan.water_ml), "served snapshot owns broth while the pan is empty")
	var soup_dish: Dictionary = game._last_dish.duplicate(true)
	for entry in soup_dish.get("ingredients", []):
		if entry is Dictionary:
			entry.erase("physics_id")
			entry.erase("off_heat")
	var soup_record := {"title": "盛入碗的汤", "author": "测试主厨", "dish": soup_dish, "notes": "从锅盛入汤碗。", "thumbnail": "", "poster": {"version": 1, "caption": "", "strokes": [], "stickers": []}}
	var soup_saved: bool = game.repository.save_recipe(soup_record)
	check(soup_saved, "a plated soup can be saved as a recipe: " + game.repository.get_last_error())
	if soup_saved:
		var reopened = preload("res://modules/restaurant/storage/recipe_repository.gd").new(game.repository.storage_path)
		var entries: Array = reopened.load_recipes()
		check(entries.size() == 1 and is_equal_approx(float(entries[0].dish.get("water_ml", 0.0)), 100.0) and is_equal_approx(float(entries[0].dish.get("presentation", {}).get("broth_ml", 0.0)), 100.0), "reopened cookbook preserves actual soup volume and bowl presentation")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]) == OK, "GPU renders the actual served soup bowl")
	finish()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func finish() -> void:
	if failures.is_empty(): print("PASS: serving continuity, %d checks" % checks)
	else: print("FAIL: serving continuity, %d checks" % checks)
	if is_instance_valid(game): game.queue_free()
	quit(0 if failures.is_empty() else 1)
