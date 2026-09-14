extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("GameState")
	state.begin_new_game("B")
	state.switch_to_role("B", 2, true)
	var starting_money: int = state.money
	var purchase: Dictionary = state.buy_item({"id":"tomato", "name":"熟透的番茄", "price":8, "minutes":5, "shop_name":"菜摊"})
	check(bool(purchase.get("ok", false)), "A produce item should be purchasable")
	check(state.money == starting_money - 8 and int(state.inventory.get("tomato", 0)) == 1, "A purchase should deduct money and add inventory")
	check(not state.money_ledger.is_empty() and int(state.money_ledger[-1].amount) == -8, "Purchases should appear in the money ledger")
	state.current_minute = 600
	state.current_location = "dorm"
	state.commit_active_role_state()
	check(not state.advance_to_next_free_block(), "A due at-home commitment should wait for player input")
	check(bool(state.shared_state.get("pending_commitment", false)), "The work computer should receive a pending commitment")
	var before_work: int = state.money
	var work: Dictionary = state.complete_next_commitment()
	check(bool(work.get("ok", false)), "B should be able to start the due commitment from the home computer")
	check(state.current_minute == 660 and state.money == before_work + 45, "Work should consume its authored minutes and pay income")
	check(state.money_ledger.any(func(row): return int(row.get("amount", 0)) == 45), "Work income should be visible in the ledger")
	var ingredients: Array[String] = ["tomato"]
	var consumed: Array[String] = state.consume_inventory(ingredients)
	check(consumed == ["tomato"] and not state.inventory.has("tomato"), "Cooking should be able to consume a purchased ingredient")
	var photo_lib := PhotoLibrary.new()
	photo_lib.root_path = "user://tests/feedback_photos_" + Crypto.new().generate_random_bytes(6).hex_encode()
	var test_image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	test_image.fill(Color("789ca1"))
	var photo: Dictionary = photo_lib.save_photo(test_image, {"location":"dorm", "title":"B的家", "day":2, "role":"B", "game_minute":660})
	check(not photo.is_empty() and str(photo.get("role", "")) == "B" and int(photo.get("game_minute", 0)) == 660, "Pocket photos should keep journey time and role metadata")
	photo_lib.save_photo(test_image, {"location":"dorm"})
	check(photo_lib.list_photos().size() == 1, "Identical photos should not create duplicate local files")
	for action in ["interact", "dialogue_advance", "open_camera", "open_recorder", "open_album", "open_journal"]:
		check(InputMap.has_action(action), "Semantic input action should exist: %s" % action)
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.8).timeout
	check(current_scene != null and current_scene.time_guidance_label != null and current_scene.wallet_label != null and current_scene.wallet_icon != null, "Town HUD should expose iconic money feedback and actionable time guidance")
	current_scene._open_shop("produce_stall")
	await process_frame
	check(is_instance_valid(current_scene.pocket_panel) and current_scene.pocket_panel.item_list.get_child_count() == 4, "Produce stall should open a four-item purchase interface")
	current_scene.pocket_panel._buy({"id":"lemon", "name":"一袋柠檬", "price":12, "minutes":5})
	check(current_scene.pocket_panel.status_label.text.contains("花费12元"), "Purchase feedback must survive the item-list refresh")
	current_scene.pocket_panel.queue_free()
	await process_frame
	var dialogue = load("res://scripts/ui/conversation_panel.gd").new()
	dialogue.npc = "zhou_xiaoliu"
	current_scene.add_child(dialogue)
	dialogue.typewriter = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.pressed = true
	root.push_input(key, true)
	check(dialogue.index == 0, "S does not navigate a removed topic menu")
	key.physical_keycode = KEY_ENTER
	key.keycode = KEY_ENTER
	root.push_input(key, true)
	check(is_instance_valid(dialogue.text_label) and dialogue.index == 1, "Enter advances exactly one spoken line")
	dialogue._close()
	await process_frame
	var modules = root.get_node("GameplayModuleSystem")
	modules.unlock("ghostwriting")
	var before_letter: int = state.money
	check(modules.complete_external("ghostwriting", {"choice_id":"extension_complete"}, {"money":35}), "Finished commission can settle")
	check(state.money == before_letter + 35, "Letter commission pays its real fee")
	modules.complete_external("ghostwriting", {"choice_id":"extension_complete"}, {"money":35})
	check(state.money == before_letter + 35, "Reopening a completed letter cannot farm the same fee")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		var viewport_texture := root.get_texture()
		if viewport_texture != null:
			viewport_texture.get_image().save_png("/private/tmp/solmere-feedback-shop.png")
	print("FEEDBACK SYSTEMS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
