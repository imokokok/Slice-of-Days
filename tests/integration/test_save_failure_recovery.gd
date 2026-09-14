extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var saves = root.get_node("SaveManager")
	var router = root.get_node("SceneRouter")
	var gameplay = root.get_node("GameplayModuleSystem")
	var original_script = saves.get_script()
	var failing := GDScript.new()
	failing.source_code = "extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload() == OK, "Save-failure stub compiles")
	root.get_node("ChapterSystem").start_new_game()
	root.get_node("ChapterSystem").advance_chapter()
	state.current_location = "cafe"
	state.current_minute = 700
	var shop = load("res://scripts/ui/shop_panel.gd").new()
	shop.shop_id = "grocery"
	root.add_child(shop)
	await process_frame
	var before: Dictionary = state.to_save_data()
	var item: Dictionary = shop.shop.items[0].duplicate(true)
	saves.set_script(failing)
	shop._buy(item)
	shop._buy(item)
	check(state.to_save_data() == before, "Repeated failed saves preserve money, items, time and daily spending")
	check(shop.status_label.text.contains("没有扣款"), "Shop explains that the failed transaction was undone")
	saves.set_script(original_script)
	shop._buy(item)
	check(state.money == int(before.role_states.B.money) - int(item.price) and int(state.inventory[item.id]) == 1, "Retry purchases exactly once")
	shop.queue_free()
	await process_frame
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.8).timeout
	var town = current_scene
	var old_place: String = state.current_location
	saves.set_script(failing)
	town._change_route("residence",140,1)
	check(not router.transitioning and state.current_location == old_place and not state.shared_state.has("route_arrival"), "Failed route save leaves the player on the original street")
	check(town.event_overlay.visible, "Route save failure is visible to the player")
	check(gameplay.begin_session("translation", "audit", state.to_save_data()), "Prepare a pending extension session")
	var host = load("res://scripts/ui/extension_host.gd").new()
	host.module_id = "translation"
	host.status_label = Label.new()
	host.add_child(host.status_label)
	host._cancel()
	check(gameplay.pending_module_id() == "translation" and not router.transitioning, "Failed cancel save preserves the pending minigame for retry")
	check(host.status_label.text.contains("重试离开"), "Failed cancel gives a retry message")
	saves.set_script(original_script)
	gameplay.cancel_session()
	host.free()
	town.queue_free()
	await create_timer(0.3).timeout
	print("SAVE FAILURE RECOVERY PASS" if failures == 0 else "SAVE FAILURE RECOVERY FAIL")
	quit(failures)
