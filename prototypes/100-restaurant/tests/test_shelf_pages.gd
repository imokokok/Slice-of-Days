extends SceneTree
## Exercise the player-facing page controls and finite stock across rebuilds.
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://shelf_pages_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var shelf = game.storage_display
	for id in shelf.FEATURED_FOODS_FIRST:
		var first_index := -1
		for index in shelf._cold_catalog.size():
			if str(shelf._cold_catalog[index].id) == id: first_index = index
		expect(first_index >= 0 and first_index < shelf.FEATURED_FOODS_FIRST.size(), id + " supplied food art is on the first fridge page")
		if first_index < shelf.FRIDGE_PAGE_SIZE:
			expect(shelf.find_child("Ingredient_" + id, true, false) != null, id + " is visible on opening the fridge")
	expect(shelf.find_child("MysteryStock", true, false) == null, "strange box button is absent")
	for section in ["fridge", "odd"]:
		var found: Array[String] = []
		var pages: int = shelf._fridge_page_count() if section == "fridge" else ceili(shelf._odd_catalog.size() / 12.0)
		for page in pages:
			for slot in shelf.find_children("Ingredient_*", "Button", true, false):
				var def: Dictionary = slot.get_meta("definition")
				var relevant: bool = def.category == "odd" if section == "odd" else def.category in ["basic", "sweet"]
				if not relevant: continue
				expect(not found.has(str(def.id)), str(def.id) + " occurs once across shelf pages")
				found.append(str(def.id))
				if section == "odd": expect(slot.position.x > 1300, str(def.id) + " stays on the odd shelf")
				else: expect(slot.position.x < 340, str(def.id) + " stays in ordinary storage")
			if section == "fridge" and page == 0:
				var scroll := shelf.find_child("FridgeScrollDown", true, false) as Button
				expect(scroll != null and not scroll.disabled, "first fridge page scrolls within the supplied artwork")
				if scroll != null: scroll.pressed.emit()
				for id in shelf.FEATURED_FOODS_FIRST:
					if not found.has(id) and shelf.find_child("Ingredient_" + id, true, false) != null: found.append(id)
				expect(shelf.fridge_page == 0 and found.has("bread"), "last supplied artwork stays on page one after scrolling")
				shelf.find_child("FridgeScrollUp", true, false).pressed.emit()
			var next := shelf.find_child(section.capitalize() + "NextPage", true, false) as Button
			expect(next != null, section + " has working page control")
			if next != null: next.pressed.emit()
		for def in game.session.active_ingredients():
			if (def.category == "odd" if section == "odd" else def.category in ["basic", "sweet"]):
				expect(found.has(str(def.id)), str(def.id) + " reachable by real page buttons")
		expect((shelf.fridge_page if section == "fridge" else shelf.odd_page) == 0, section + " pages wrap back to first shelf")

	game._take_ingredient(game._definition("sock"))
	var body: RigidBody2D = game.world._held
	var identity: String = body.get_meta("instance_uid")
	game.world._dragging = false
	shelf.find_child("OddNextPage", true, false).pressed.emit()
	expect(not shelf.slot_at("sock", Vector2(1357, 257)), "an offscreen sock slot cannot accept a return")
	shelf.find_child("OddPreviousPage", true, false).pressed.emit()
	var slot := shelf.find_child("Ingredient_sock", true, false) as Button
	expect(slot.disabled and not slot.get_node("FoodArt").visible, "changing pages does not refill an emptied slot")
	game._take_ingredient(game._definition("sock"))
	expect(game.world._held == body and game.world._foods.get_child_count() == 1, "repeated take cannot create a second sock")
	body.position = slot.get_global_rect().get_center()
	expect(game._return_to_storage(body), "original sock can return after page navigation")
	game._pantry_category = "odd"
	game._show_pantry()
	await capture("cupboard")
	var pantry_slot := game._pantry_grid.find_child("Pantry_sock", true, false) as Button
	expect(pantry_slot != null and pantry_slot.get_node("FoodArt").definition.id == "sock", "cupboard uses the same authored sock thumbnail")
	pantry_slot.pressed.emit()
	expect(game.world._held == body and body.get_meta("instance_uid") == identity, "cupboard reuses returned shelf entity")
	expect(not game.modal.visible, "cupboard selection returns to gameplay")
	game.world.discard_held()
	await process_frame
	# A cupboard selection on another layer reveals its physical return slot.
	game._pantry_category = "all"
	game._show_pantry()
	game._pantry_grid.find_child("Pantry_sponge", true, false).pressed.emit()
	expect(shelf.odd_page > 0 and shelf.find_child("Ingredient_sponge", true, false) != null, "cupboard selection reveals the matching shelf layer")
	await capture("shelf-layer")
	for id in ["sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste"]:
		var def: Dictionary = game._definition(id)
		expect(def.category == "odd" and "non_food" in def.tags, id + " remains a non-food strange ingredient")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: paged shelves and shared finite stock, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func capture(label: String) -> void:
	if OS.get_cmdline_user_args().is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-" + label + ".png") == OK, "GPU " + label)
