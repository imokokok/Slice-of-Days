extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error(message)
func settle() -> void:
	await create_timer(.9).timeout
	for i in 80:
		if not root.get_node("SceneRouter").transitioning: break
		await create_timer(.1).timeout
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func paper_to(location: String) -> Control:
	await key(KEY_TAB)
	var shell = current_scene.get_node("GameplayShell")
	check(is_instance_valid(shell.overlay) and shell.overlay.mode == "map","Tab opens real map")
	var paper: Control = shell.overlay
	for child in paper.map_board.get_children():
		if child is Button and str(child.get_meta("location","")) == location:
			child.pressed.emit()
			await process_frame
			return paper
	check(false,"Destination button exists: "+location)
	return paper
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var gs = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var travel = root.get_node("TravelSystem")
	var save = root.get_node("SaveManager")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(3.2).timeout
	# Actual visible new-game button, including its opening animation.
	current_scene.navigation.get_node("NewGame").pressed.emit()
	for i in 250:
		await create_timer(.1).timeout
		if current_scene.scene_file_path.ends_with("town_day.tscn") and not router.transitioning: break
	check(current_scene.scene_file_path.ends_with("town_day.tscn"),"Main-menu new game enters street")
	if not current_scene.scene_file_path.ends_with("town_day.tscn"): quit(1); return
	var map = await paper_to("residence")
	map.body.get_node("MapDetails/TravelWalk").pressed.emit()
	await settle()
	check(gs.current_location == "residence" and current_scene.segment_id == "residential","Map reaches residential area")
	map = await paper_to("handcraft_shop")
	var minute: int = gs.current_minute
	var money: int = gs.money
	var walking: Dictionary = travel.route(gs.current_location,"handcraft_shop","walk",gs.current_role,minute)
	check(map.body.get_node("MapDetails/TravelWalk").text.contains(str(walking.minutes)),"Walk preview uses live route minutes")
	await create_timer(1.1).timeout
	check(gs.current_minute == minute and not current_scene.street.enabled,"Map pauses world time and movement")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/patch_map_route.png")
	map.body.get_node("MapDetails/TravelWalk").pressed.emit()
	check(gs.current_minute == minute+int(walking.minutes) and gs.money == money,"Walk applies exact time and no charge")
	check(not router.travel_to("residence","taxi").ok,"Double request blocked during transition")
	await settle()
	check(gs.current_location == "handcraft_shop" and current_scene.segment_id == "cultural_street","Walking reaches culture street")
	check(absf(current_scene.street.player_x-float(travel.arrival_for("handcraft_shop").x)) < 1,"Culture arrival uses configured door spawn")
	map = await paper_to("residence")
	var taxi: Dictionary = travel.route(gs.current_location,"residence","taxi",gs.current_role,gs.current_minute)
	check(int(taxi.minutes) < int(walking.minutes),"Taxi is faster than same walking route")
	minute = gs.current_minute
	money = gs.money
	map.body.get_node("MapDetails/TravelTaxi").pressed.emit()
	check(gs.current_minute == minute+int(taxi.minutes) and gs.money == money-int(taxi.cost),"Taxi applies time and fare exactly once")
	check(not router.travel_to("residence","taxi").ok,"Repeated taxi cannot charge twice")
	await settle()
	check(gs.current_location == "residence" and current_scene.segment_id == "residential","Taxi returns to correct residential scene")
	check(absf(current_scene.street.player_x-float(travel.arrival_for("residence").x)) < 1,"Taxi has correct spawn")
	money = gs.money
	minute = gs.current_minute
	check(save.load_latest(),"Actual save reload succeeds")
	check(gs.money == money and gs.current_minute == minute and gs.current_location == "residence","Reload preserves trip without replaying cost")
	map = await paper_to("residence")
	check(map.body.get_node_or_null("MapDetails/TravelWalk") == null,"Current location offers no repeat trip")
	map._map_select("handcraft_shop")
	map.body.get_node("MapDetails/TravelCancel").pressed.emit()
	check(map.map_selected == gs.current_location and gs.money == money and gs.current_minute == minute,"Cancel keeps location, money and clock")
	# Insufficient funds is a negative fixture; all travel still uses real UI and router.
	gs.money = 0
	map._map_select("handcraft_shop")
	check(map.body.get_node("MapDetails/TravelTaxi").disabled,"Unaffordable taxi is disabled")
	check(not router.travel_to("handcraft_shop","taxi").ok and gs.current_minute == minute,"Router also rejects unfunded taxi without time loss")
	gs.money = money
	map.close()
	await process_frame
	await key(KEY_W)
	await key(KEY_S)
	check(gs.current_location == "residence" and not router.transitioning,"W/S cannot switch region")
	check(not current_scene.has_method("_change_route"),"Legacy free region switch removed")
	check(not current_scene.street.hotspots.any(func(h: Dictionary) -> bool: return h.get("kind","") == "roads"),"No old road sign hotspot")
	current_scene.street.player_x = 80
	await create_timer(.2).timeout
	check(current_scene.segment_id == "residential" and not router.transitioning,"Street edge cannot bypass map travel")
	print("PATCH_TRAVEL ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)
