extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event.pressed = false
	root.push_input(event)
	await process_frame
func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP") + "/solmere-polish-review/" + label + ".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	state.current_minute = 700
	state.shared_state.typewriter = false
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.8).timeout
	var town = current_scene
	var height: float = town.street._actor_height()
	# Walk across background changes, then enter a different route/room: no resizing.
	for i in town.street_order.size():
		town.street.player_x = town._world_x(i, 300)
		town._on_walk(town.street.player_x)
		await create_timer(0.1).timeout
		check(town.street._actor_height() == height and town.street.scale == Vector2.ONE, "Walking past different door illustrations keeps world scale")
	state.current_location = "cafe"
	router.town_day()
	await create_timer(0.15).timeout
	check(town.street.scale == Vector2.ONE, "Scene curtain does not enlarge the character")
	await create_timer(0.7).timeout
	while router.transitioning:
		await process_frame
	town = current_scene
	var owners: Array = town.street.hotspots.filter(func(h): return h.kind == "shopkeeper")
	check(owners.size() == 1, "Open grocery has one outdoor shopkeeper")
	check(not town.street.hotspots.any(func(h): return h.kind == "door"), "Grocery shopping requires no interior entry")
	if owners.is_empty(): quit(1); return
	town.street.player_x = float(owners[0].x) - 65
	town.street.move_player(0,0)
	var talk_target: Dictionary = town.street.nearest_of(["person", "npc", "resident", "shopkeeper", "invitation"])
	check(str(talk_target.get("kind", "")) == "shopkeeper", "W resolves the nearby shopkeeper independently from overlapping object hotspots")
	await shot("silhouette-grocery")
	var before: int = state.money
	var location_x: float = town.street.player_x
	town._talk_to_nearest()
	check(is_instance_valid(town.conversation) and town.conversation.npc == "grocery", "W opens the nearby grocery owner's conversation")
	check(not is_instance_valid(town.pocket_panel), "Greeting precedes the product list")
	await shot("grocery-greeting")
	town.conversation.typewriter = false
	var guard := 0
	while is_instance_valid(town.conversation) and not is_instance_valid(town.conversation.vendor_choices) and guard < 40:
		town.conversation._advance()
		guard += 1
	check(is_instance_valid(town.conversation.vendor_choices), "Finishing the greeting exposes the grocery owner's choices")
	town.conversation._vendor_action("shop")
	check(is_instance_valid(town.pocket_panel) and town.pocket_panel.shop_id == "grocery", "The conversation's shop choice opens the grocery purchase list")
	check(router.active_space_id.is_empty() and state.current_location == "cafe", "Player remains outside")
	var shop = town.pocket_panel
	var item: Dictionary = shop.shop.items[0].duplicate(true)
	var item_id := str(item.id)
	var inventory_before := int(state.inventory.get(item_id,0))
	shop._buy(item)
	check(state.money == before - int(item.price) and int(state.inventory[item_id]) == inventory_before + 1, "Outdoor purchase deducts the price and adds the actual item")
	shop.queue_free()
	await process_frame
	check(town.street.player_x == location_x and is_instance_valid(town.conversation), "Finish shopping returns to the same conversation and street position")
	town.conversation._close()
	await process_frame
	town._talk_to_nearest()
	await key(KEY_ESCAPE)
	check(not is_instance_valid(town.pocket_panel) and not is_instance_valid(town.conversation), "Leaving the greeting does not open the product list or charge money")
	state.current_location = "residence"
	router.enter_space("home_a")
	await create_timer(0.8).timeout
	while router.transitioning:
		await process_frame
	check(current_scene.stage._actor_height() > height, "Interior close-up uses the authored larger actor scale")
	print("GROCERY + SILHOUETTE PASS" if failures == 0 else "GROCERY + SILHOUETTE FAIL")
	quit(failures)
