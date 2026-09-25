extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://layout_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	for id in ["oil", "pepper", "salt", "sugar", "soy_sauce"]:
		var item: Button = game.hud.find_child("Ingredient_"+id, true, false)
		expect(item != null and item.position.x >= 340 and item.position.x < 548 and item.position.y > 440, "condiment comes from the left condiment rack: " + id)
		for other_id in ["oil", "pepper", "salt", "sugar", "soy_sauce"]:
			if other_id == id: break
			var other := game.hud.find_child("Ingredient_" + other_id, true, false) as Button
			expect(item != null and other != null and not item.get_rect().intersects(other.get_rect()), "left condiment footprints stay separate: " + id + " / " + other_id)
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]:
		var item: Button = game.hud.find_child("Ingredient_"+id, true, false)
		expect(item != null and Rect2(640, 500, 435, 120).encloses(item.get_rect()), "ingredient belongs in the original five-slot tray: " + id)
		expect(item != null and item.get_rect().end.y < 590, "tray click area stays inside its groove: " + id)
	var faucet_stream := Rect2(194, 560, 12, 175)
	for id in ["FridgePreviousPage", "FridgeNextPage"]:
		var tab := game.storage_display.find_child(id, true, false) as Button
		expect(tab != null and not tab.get_rect().intersects(faucet_stream), "fridge page tab stays on the cabinet, clear of running water: " + id)
	expect(game._order_paper.position.y <= 140 and game._order_paper.position.y + game._order_paper.size.y >= 440, "order note covers the original blank sheet rather than leaving a top strip")
	expect(game.world.pan.point(Vector2(809, 541)).y > 639.0, "pan opening starts below the rear rack front")
	expect(game.world.cutting_board.rect().encloses(Rect2(game.world._knife_rest_position + Vector2(-93, -24), Vector2(188, 52))), "knife art rests entirely on the cutting board")
	expect(game.world.cutting_board.z_index > game.world.pan.pan_back.z_index and game.world.cutting_board.z_index < game.world._knife_visual.z_index, "board hides the crossing pan handle while the knife remains above the board")
	for id in ["sock", "confetti", "toilet_paper", "soap"]:
		var item := game.hud.find_child("Ingredient_" + id, true, false) as Button
		if item == null: continue
		var art := item.get_node("FoodArt") as Node2D
		var library = preload("res://modules/restaurant/assets/sprite_library.gd")
		var tex: Texture2D = library.food(id)
		var visible_rect: Rect2 = library.fit(tex, Vector2.ZERO, Vector2(78, 78))
		var row := roundi((item.position.y + item.size.y - 300.0) / 105.0)
		var shelf_front := 300.0 + row * 105.0
		var art_bottom := item.position.y + art.position.y + visible_rect.end.y * art.scale.y
		expect(absf(art_bottom - (shelf_front - 4.0)) < 1.0, "odd ingredient rests on its shelf floor: " + id)
		expect(item.position.y + item.get_node("IngredientName").position.y >= shelf_front, "odd name is attached to the shelf front: " + id)
	for utensil in game.world.utensils:
		expect(utensil.position.x >= 545 and utensil.position.x <= 630 and utensil.home_angle > 1, "utensil rests upright in the source cup")
	var book: Button = game.hud.find_child("ReferenceRecipeBook", true, false)
	expect(book != null, "visible recipe book has a real entry")
	book.pressed.emit()
	await process_frame
	expect(game.modal.visible, "reference book opens the working recipe interface")
	game._close_modal()
	game.world.pan.overflow_water_ml = 100
	game.world.spill_pan_water(100, Vector2(480, 716))
	await process_frame
	var sponge = game.world.sponge
	_mouse(sponge.position, "down")
	await process_frame
	expect(sponge.active and not game.world.spawn_ingredient(game._definition("tomato")), "sponge can be picked up and owns the hand")
	_mouse(Vector2(480, 716), "move")
	_mouse(Vector2(480, 716), "up")
	await process_frame
	expect(not sponge.active and is_zero_approx(game.world.pan.overflow_water_ml), "dragging sponge over water removes the tracked spill")
	await process_frame
	expect(game.world._foods.get_child_count() == 0, "wiped liquid has no ghost physical body")
	var ketchup := game.storage_display.find_child("Ingredient_ketchup", true, false) as Button
	_mouse(ketchup.get_global_rect().get_center(), "down")
	_mouse(ketchup.get_global_rect().get_center(), "up")
	await process_frame
	var pan_point: Vector2 = game.world.pan.point(Vector2(800, 535))
	_mouse(pan_point, "move")
	_mouse(pan_point, "down")
	await process_frame
	expect(game.world._squeezing, "holding a rack bottle over the pan starts dispensing without the tray blocking input")
	_mouse(pan_point, "up")
	game.world.discard_held()
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: reference layout and sponge, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.position = point
		button.global_position = point
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = kind == "down"
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if button.pressed else 0
		Input.parse_input_event(button)
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
