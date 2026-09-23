extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func press(node: Node, key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	node._unhandled_input(event)
func drain(panel: Node) -> void:
	panel.typewriter = false
	var guard := 0
	while not panel.closing and not is_instance_valid(panel.vendor_choices) and guard < 80:
		panel._advance()
		guard += 1
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.gui_disable_input = true
	var state = root.get_node("GameState")
	var economy = root.get_node("EconomySystem")
	var router = root.get_node("SceneRouter")
	var residency = root.get_node("ResidencySystem")
	var modules = root.get_node("GameplayModuleSystem")
	var save = root.get_node("SaveManager")
	root.get_node("ChapterSystem").start_new_game()
	state.switch_to_role("B", 2, true) # Focused economy fixture: B's actual day.
	check(state.money == 1600, "B starts with the configured 1600, without charging prepaid rent")
	state.current_minute = 960 # Leave real time for shopping before the 18:30 closing.
	state.current_location = "night_market"
	router.active_space_id = "restaurant"
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.3).timeout
	var room = current_scene
	room.set_process(false)
	room.stage.set_process(false)
	var counter_index := -1
	for i in room.objects.size():
		if str(room.objects[i].id) == "procurement_counter": counter_index = i
	check(counter_index >= 0, "Existing restaurant contains a real procurement hotspot")
	if counter_index < 0: quit(1); return
	room.stage.player_x = room._hotspot_x(counter_index)
	press(room, KEY_E)
	check(not get_nodes_in_group("economy_paper").is_empty(), "Normal E opens the restaurant order paper")
	var paper = get_nodes_in_group("economy_paper")[0]
	var accepted: Dictionary = economy.accept_procurement()
	check(bool(accepted.ok) and modules.is_unlocked("cooking"), "Accepting the real counter order unlocks its kitchen")
	paper.queue_free()
	await process_frame
	check(not economy.cooking_check(["tomato","herbs","sea_beans"]).ok, "Unbought ingredients cannot enter the kitchen")
	state.current_location = "produce_stall"
	router.active_space_id = ""
	state.shared_state["map_arrival"] = "produce_stall"
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.3).timeout
	var town = current_scene
	town.set_process(false)
	town.street.set_process(false)
	town._refresh()
	var produce_counter: Dictionary = {}
	for spot in town.street.hotspots:
		if str(spot.get("kind", "")) == "shop" and str(spot.get("id", "")) == "produce_stall": produce_counter = spot
	check(not produce_counter.is_empty() and str(produce_counter.get("label", "")) == "查看蔬菜和罐头", "Produce counter exposes the direct vegetable and canned-food prompt")
	if produce_counter.is_empty(): quit(1); return
	town.street.player_x = float(produce_counter.x)
	press(town, KEY_E)
	check(is_instance_valid(town.pocket_panel) and town.pocket_panel.shop_id == "produce_stall", "E at the produce counter opens the existing purchase panel directly")
	if is_instance_valid(town.pocket_panel): town.pocket_panel.queue_free()
	await process_frame
	for spot in town.street.hotspots:
		if str(spot.get("id","")) == "beetman": town.street.player_x = float(spot.x)
	var chat_start: int = state.current_minute
	press(town, KEY_W)
	check(is_instance_valid(town.conversation), "Actual market vendor W opens ordinary chat")
	if not is_instance_valid(town.conversation): quit(1); return
	drain(town.conversation)
	check(state.current_minute == chat_start+15, "Full vendor chat charges once")
	check(root.get_node("KnowledgeSystem").facts().any(func(row: Dictionary) -> bool: return str(row.id) == "beetman_shopping"), "Finishing real chat grants usable sourced shop information")
	town.conversation._vendor_action("shop")
	var shop = town.pocket_panel
	check(is_instance_valid(shop), "Optional chat branch reaches real ShopPanel")
	for id in ["tomato","herbs","sea_beans"]:
		shop.last_purchase_msec = -1000
		shop._buy({"id":id})
	check(state.money == 1571, "Actual three ingredient purchases deduct 29 once")
	check(int(state.inventory.get("sea_beans",0)) == 1 and int(state.inventory.get("tomato",0)) == 1, "Purchased kitchen materials enter the actual inventory")
	check(economy.state().receipts.size() == 3, "Three purchases retain three distinct physical receipts")
	for receipt in economy.state().receipts.values():
		check(receipt.line_items.size() == 1 and str(receipt.category) == "food" and bool(receipt.reimbursable), "Receipt contains real line items, category and reimbursement eligibility")
	shop.queue_free()
	town.conversation._close()
	await process_frame
	state.current_location = "night_market"
	router.active_space_id = "restaurant"
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.2).timeout
	current_scene.set_process(false)
	current_scene.stage.set_process(false)
	var receipt_ids: Array = economy.state().receipts.keys().duplicate()
	var delivery: Dictionary = economy.deliver_procurement()
	check(bool(delivery.ok) and state.money == 1600, "Delivery reimburses actual purchase cost")
	check(economy.state().receipts.keys() == receipt_ids, "Reimbursement stamps the same receipts without duplicates")
	for receipt in economy.state().receipts.values():
		check(bool(receipt.reimbursed) and int(receipt.reimbursed_amount) == int(receipt.total) and str(receipt.stamp).contains("已报销"), "Every covered original receipt receives its reimbursement stamp")
	check(not bool(economy.deliver_procurement().ok) and state.money == 1600, "Repeated delivery cannot create a second reimbursement")
	check(residency.state().materials.values().filter(func(row: Dictionary) -> bool: return str(row.get("proof_kind","")) == "income").is_empty(), "Reimbursement does not create work income proof")
	check(economy.cooking_check(["tomato","herbs","sea_beans"]).ok, "Delivered purchased materials are available at the kitchen")
	check(modules.begin_session("cooking","restaurant_procurement:"+str(economy.active_order().id)), "Order launches the existing cooking module session")
	change_scene_to_file("res://scenes/native_module_game.tscn")
	await create_timer(.25).timeout
	var kitchen = current_scene
	kitchen.set_process(false)
	for id in ["tomato","herbs","sea_beans"]: kitchen._toggle_token(id)
	kitchen.value_slider.value = .58
	kitchen._perform_primary_action()
	check(kitchen.stage_ready, "Real kitchen selection and heat mechanic allow serving")
	var before_work: int = state.current_minute
	kitchen._complete_choice("careful_menu")
	check(kitchen.completed, "Existing native kitchen completes the order")
	check(state.current_minute == before_work+90 and state.money == 1760, "Exactly one configured 90 minute, 160 yuan shift is settled")
	check(not state.inventory.has("tomato") and not state.inventory.has("herbs") and not state.inventory.has("sea_beans"), "Serving consumes the three actual purchased items")
	check(bool(economy.active_order().paid) and bool(economy.active_order().completed), "Paid/completed order is a persistent transaction state")
	kitchen._complete_choice("careful_menu")
	check(state.money == 1760, "Double clicking serving never pays twice")
	var wage_id := ""
	for id in residency.state().materials:
		var material: Dictionary = residency.state().materials[id]
		if str(material.get("proof_kind","")) == "income" and int(material.get("paid",0)) == 160: wage_id = str(id)
	check(not wage_id.is_empty(), "Actual wage creates a work record for the correct issuer")
	check(bool(residency.state().materials.get("module_cooking_0",{}).get("contribution_entered_town",false)), "Served dish has an accepted public contribution trace")
	if not wage_id.is_empty():
		residency.collect_proof(wage_id)
		check(residency.state().materials.has("proof_"+wage_id), "Real restaurant counter issues signed income proof after serving")
		var money_before_proof: int = state.money
		residency.collect_proof(wage_id)
		check(state.money == money_before_proof, "Repeated proof collection grants no money")
	state.current_location = "cafe"
	var soap: Dictionary = economy.purchase("grocery","soap")
	check(bool(soap.ok) and str(soap.get("receipt",{}).get("category","")) == "household", "A separate household purchase creates a genuinely different receipt category")
	receipt_ids = economy.state().receipts.keys().duplicate()
	receipt_ids.sort()
	state.current_location = "night_market"
	check(save.save_or_report("V3 economy integration save"), "Economy chain saves")
	state.artifacts.clear()
	check(save.load_slot(1), "Economy chain reloads through SaveManager")
	var loaded_receipt_ids: Array = economy.state().receipts.keys().duplicate()
	loaded_receipt_ids.sort()
	check(bool(economy.active_order().get("paid",false)) and loaded_receipt_ids == receipt_ids, "Paid order and original receipt identity survive reload")
	root.get_node("ChapterSystem").start_new_game()
	state.current_minute = 600
	state.current_location = "cafe"
	var odd_stock: Array = economy.stock("grocery").filter(func(item: Dictionary) -> bool: return item.category == "collection")
	check(odd_stock.size() >= 2 and odd_stock.size() <= 3, "Day one offers two or three authored odd objects")
	var purchase: Dictionary = economy.purchase("grocery","misprint_postcard")
	check(bool(purchase.ok), "A can actually buy a limited collectible")
	check(not economy.purchase("grocery","misprint_postcard").ok, "Daily one-item stock cannot be purchased twice")
	var owned_id := str(purchase.get("receipt",{}).get("id",""))
	if owned_id.is_empty():
		check(false,"Owned object receives a physical purchase identity")
		quit(failures)
		return
	check(economy.name_collection(owned_id,"另一边的灯塔","今天想把错印留下。","desk"), "Owned object accepts a persistent private name, note and place")
	check(economy.collage_materials().any(func(row: Dictionary) -> bool: return str(row.get("collection_id","")) == owned_id), "Eligible purchased paper enters the real collage source catalog")
	state.current_location = "residence"
	router.active_space_id = "home_a"
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.25).timeout
	check(current_scene.get_children().any(func(child: Node) -> bool: return child.get_script() != null and child.get_script().resource_path == "res://scripts/ui/collection_display.gd"), "Actual A room renders owned collection props")
	check(save.save_or_report("V3 collection save") and save.load_slot(1), "Collection placement survives a real save/load")
	check(str(economy.state().collections.get(owned_id,{}).get("nickname","")) == "另一边的灯塔", "The private name and note persist")
	state.current_location = "produce_stall"
	var booked: Dictionary = economy.book_vendor_visit()
	check(bool(booked.ok) and not state.appointments.is_empty(), "Vendor invitation writes an actual player-chosen appointment")
	state.current_minute = 1100
	state.refresh_appointments()
	check(not economy.remembered_line("beetman").is_empty(), "Missing the appointment changes later ordinary dialogue")
	var appointment_id: String = economy.state().appointments.keys()[0]
	check(state.appointment_status(appointment_id) == "missed", "Missed commitment remains visible in the real planner")
	print("V3 ECONOMY PASS: %d checks" % checks if failures == 0 else "V3 ECONOMY FAIL: %d / %d" % [failures,checks])
	quit(failures)
