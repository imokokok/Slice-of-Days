extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle() -> void: await process_frame; await process_frame
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await settle(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/services-captures")
	root.get_texture().get_image().save_png("res://.runtime/services-captures/"+tag+".png")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.size=Vector2i(1600,900)
	var gs=root.get_node("GameState"); var save=root.get_node("SaveManager"); var film=root.get_node("FilmSystem")
	var economy=root.get_node("EconomySystem"); var router=root.get_node("SceneRouter")
	var presence=load("res://scripts/ui/resident_presence.gd").new()
	var residents: Array=[{"id":"maya","kind":"person","x":1400.0}]
	check(presence.reconcile(residents,0).size()==1,"Resident enters presentation")
	check(presence.reconcile([],0).size()==1,"Schedule removal keeps a visible resident")
	check(presence.reconcile([],1500).size()==1,"Offscreen center alone is insufficient while silhouette is visible")
	check(presence.reconcile([],1561).is_empty(),"Resident retires only after full silhouette leaves viewport")
	presence.reconcile(residents,0)
	residents[0].x=2200.0
	check(presence.reconcile(residents,0)[0].x==1400,"Schedule movement does not teleport on camera")
	check(presence.reconcile(residents,1600)[0].x==2200,"Schedule position updates after former pose leaves camera")
	presence.residents.clear()
	check(presence.reconcile([{"kind":"argument","x":800.0}],0).size()==2,"Market pair has two independently retained bodies")
	check(presence.reconcile([],0).size()==2,"Finishing the argument keeps both residents visible")
	var toast=load("res://scripts/ui/components/guidance_toasts.gd")
	check(toast.reading_seconds("看过来的话")>=14,"Short guidance remains at least fourteen seconds")
	check(toast.reading_seconds("长提示".repeat(100))==26,"Long guidance has a readable bounded duration")
	gs.begin_new_game("A"); gs.money=1000; gs.current_location="cafe"; gs.current_minute=660
	var bought: Dictionary=film.acquire_camera(false)
	check(bought.ok and not bought.receipt.is_empty(),"Camera purchase returns its actual receipt")
	check(bought.receipt.total==int(film.economy().camera_price) and bought.receipt.balance==gs.money,"Camera receipt has real payment and balance")
	check(economy.state().receipts.size()==1,"Camera creates exactly one receipt")
	var receipt_id: String=bought.receipt.id
	check(root.get_node("ResidencySystem").state().materials.has(receipt_id),"Camera receipt is reusable in Life Log")
	var paper=load("res://scripts/photography/film_paper.gd").new(); root.add_child(paper); await settle()
	paper._show_receipt(bought.receipt); await snap("01-camera-receipt")
	check(paper.has_node("PaymentReceipt"),"Actual payment is presented, not only recorded in background")
	paper.get_node("PaymentReceipt").queue_free(); await settle()
	var bought_roll: Dictionary=film.buy_roll("bw")
	check(bought_roll.ok and bought_roll.receipt.id!=receipt_id,"Each film purchase returns its own receipt")
	var image := Image.create(64,64,false,Image.FORMAT_RGB8); image.fill(Color.SKY_BLUE)
	check(not film.capture(image,{}).is_empty(),"Camera still captures a real image")
	var developed: Dictionary=film.dropoff(str(film.active_roll().id),"standard")
	check(developed.ok and not developed.receipt.is_empty() and developed.ticket.ready_day==2,"Developing gives both payment receipt and pickup ticket")
	paper.mode="receipts"; paper.rebuild(); await snap("02-receipt-history")
	check(economy.state().receipts.size()==3,"Three purchases produce three receipts")
	check(save.save_game() and save.load_game() and economy.state().receipts.has(receipt_id),"Receipt survives save and load")
	paper.queue_free(); await settle()
	gs.current_location="bus_stop"; gs.current_minute=660
	check(not load("res://scripts/core/coastal_fishing.gd").begin_cast().ok,"Bus stop no longer offers fishing")
	change_scene_to_file("res://scenes/town_day.tscn"); await create_timer(.5).timeout
	var town=current_scene; town.set_process(false)
	check(get_nodes_in_group("marginalia_layers").is_empty(),"Barrage layer is absent from gameplay")
	check(not root.get_node("MetaExperience").catalog.has("marginalia"),"Barrage catalog has been removed")
	for segment in root.get_node("WorldGraph").config.segments:
		for location in segment.locations:
			gs.current_location=location
			town.street_order.assign(segment.locations); town.route_offset=float(segment.get("offset",0)); town.BLOCK_WIDTH=(float(segment.width)-town.route_offset)/segment.locations.size()
			town.current_index=segment.locations.find(location); town._rebuild_hotspots()
			var signs: Array=town.street.hotspots.filter(func(h):return h.kind=="transport" and h.id==location)
			check(signs.size()==1,"Exactly one transport node at "+location)
			check(float(signs[0].x)>town._world_x(town.current_index,900),"Transport lies to the right of "+location)
	# Reload street without changing the actual route constants used for screenshots.
	gs.current_location="bus_stop"; change_scene_to_file("res://scenes/town_day.tscn"); await create_timer(.5).timeout
	town=current_scene; town.set_process(false); town.street.player_x=1120; town.street.move_player(0,0); town._refresh()
	await snap("03-station-sign")
	var interact: InputEventKey=InputMap.action_get_events("interact")[0].duplicate(); interact.pressed=true
	Input.parse_input_event(interact); await settle()
	check(is_instance_valid(town.pocket_panel),"Input Map keyboard binding opens the route board at its sign")
	var panel=town.pocket_panel
	panel._select("residence"); panel._choose_method("bus")
	check(panel.choices.size()==4 and panel.destinations.size()==root.get_node("WorldGraph").street_locations.size(),"All destinations and four real methods are native controls")
	check(not panel.depart.disabled and panel._quote("bus").cost>0,"Bus route is an actual available paid journey")
	await snap("04-transport")
	var before_money: int = gs.money
	var old_script=save.get_script()
	var failing := GDScript.new(); failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload()==OK,"Failure fixture compiles"); save.set_script(failing)
	panel._depart()
	check(not panel.busy and gs.current_location=="bus_stop" and gs.money==before_money,"Failed travel save keeps route UI open and restores money/location")
	save.set_script(old_script)
	panel._depart()
	while router.transitioning: await process_frame
	check(gs.current_location=="residence" and gs.money<before_money,"Departure performs real scene travel and charges quoted fare")
	check(save.load_game() and gs.current_location=="residence","Transport arrival persists")
	gs.current_location="port"; gs.current_minute=700
	var fishing=load("res://scripts/ui/coastal_fishing_panel.gd").new(); root.add_child(fishing); await settle()
	check(fishing.sea_view.texture!=null and fishing.sea_view.modulate.a==1,"Fishing has a fully opaque dedicated sea view")
	fishing._act(); check(fishing.phase==fishing.Phase.WAITING,"Actual seaside casting still works")
	await snap("05-sea-fishing")
	fishing.queue_free(); await settle()
	print("STREET SERVICES ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
