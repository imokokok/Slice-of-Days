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
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]:
		var item: Button = game.hud.find_child("Ingredient_"+id, true, false)
		expect(item != null and Rect2(660, 540, 430, 85).encloses(item.get_rect()), "ingredient belongs in the original five-slot tray: " + id)
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
