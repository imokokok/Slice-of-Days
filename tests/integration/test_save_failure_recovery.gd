extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	TranslationServer.set_locale("zh_CN")
	var state = root.get_node("GameState")
	var saves = root.get_node("SaveManager")
	var router = root.get_node("SceneRouter")
	var gameplay = root.get_node("GameplayModuleSystem")
	var original_script = saves.get_script()
	var failing := GDScript.new()
	failing.source_code = "extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload() == OK, "Save-failure stub compiles")
	root.get_node("ChapterSystem").start_new_game()
	state.switch_to_role("B",2,true) # Valid five-day fixture; B is not playable on day one.
	state.current_location = "cafe"
	state.current_minute = 700
	var shop = load("res://scripts/ui/shop_panel.gd").new()
	shop.shop_id = "grocery"
	root.add_child(shop)
	await process_frame
	var before: Dictionary = state.to_save_data().duplicate(true)
	var before_money: int = int(state.money)
	var before_inventory: Dictionary = state.inventory.duplicate(true)
	var before_spending: Dictionary = state.daily_spending.duplicate(true)
	var item: Dictionary = shop.shop.items[0].duplicate(true)
	saves.set_script(failing)
	shop._buy(item)
	shop._buy(item)
	check(state.money == before_money and state.inventory == before_inventory and state.current_minute == 700 and state.daily_spending == before_spending, "Repeated failed saves preserve money, items, time and daily spending")
	check(shop.status_label.text.contains("已撤回"), "Shop explains that the failed transaction was undone")
	saves.set_script(original_script)
	shop._buy(item)
	check(state.money == before_money - int(item.price) and int(state.inventory.get(item.id,0)) == int(before_inventory.get(item.id,0)) + 1, "Retry purchases exactly once")
	shop.queue_free()
	await process_frame
	# Use the longer afternoon free block so the trip reaches the save boundary.
	state.current_minute = 840
	var old_place: String = state.current_location
	var old_minute: int = int(state.current_minute)
	var old_money: int = int(state.money)
	saves.set_script(failing)
	var failed_trip: Dictionary = router.travel_to("residence","walk")
	check(not router.transitioning and state.current_location == old_place and not state.shared_state.has("route_arrival"), "Failed route save leaves the player on the original street")
	check(state.current_minute == old_minute and state.money == old_money and not bool(failed_trip.get("ok",false)), "Failed route save restores time and money")
	var trip_message := str(failed_trip.get("message",""))
	check(trip_message.contains("撤销") or trip_message.contains("失败"), "Route failure returns a visible retry message to the map: "+trip_message)
	check(gameplay.begin_session("cooking", "audit", state.to_save_data()), "Prepare a pending gameplay session")
	var host = load("res://scripts/ui/extension_host.gd").new()
	host.module_id = "cooking"
	host.status_label = Label.new()
	host.add_child(host.status_label)
	host._cancel()
	check(gameplay.pending_module_id() == "cooking" and not router.transitioning, "Failed cancel save preserves the pending minigame for retry")
	check(host.status_label.text.contains("重试离开"), "Failed cancel gives a retry message")
	saves.set_script(original_script)
	gameplay.cancel_session()
	host.free()
	state.load_save_data(before)
	# New loop transitions use the same rollback boundary as the established economy.
	state.begin_new_game("A"); state.current_location="residence"; state.current_minute=1200
	var loop=root.get_node("CoreLoopSystem"); var residency=root.get_node("ResidencySystem")
	saves.set_script(failing)
	check(not loop.review_day("今天在路上听到了风声。").ok,"Failed evening save reports failure")
	check(not loop.day_state().reviewed and not residency.state().materials.has("reflection_A_1"),"Failed evening save restores both objective and canonical material")
	saves.set_script(original_script)
	check(loop.review_day("今天在路上听到了风声。").ok,"Evening save can be retried")
	residency._add("share_test","work","真实作品",{"source":"module:sound_sampling:0"}); loop.encounter("xanni")
	saves.set_script(failing)
	check(not loop.share_material("xanni","share_test").ok and not loop.state().shared.has("xanni") and not state.confirmed_residents.has("xanni"),"Failed material sharing cannot grant a signature or consume sharing")
	saves.set_script(original_script)
	check(loop.share_material("xanni","share_test").ok,"Material sharing retries once")
	var dossier: Dictionary=residency.state(); dossier.free_pages={"collage":[{"kind":"text","text":"当天的记录"}]}
	saves.set_script(failing)
	check(not residency.persist(),"Failed optional collage save is reported")
	check(residency.state().free_pages.collage.size()==1,"Failed optional collage save retains the editable page")
	saves.set_script(original_script)
	print("SAVE FAILURE RECOVERY PASS" if failures == 0 else "SAVE FAILURE RECOVERY FAIL")
	quit(failures)
