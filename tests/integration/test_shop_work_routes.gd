extends SceneTree
var checks := 0
var failures := 0
var gs: Node
var economy: Node
var router: Node
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame; await create_timer(.25).timeout
func snapshot(file: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/atmosphere-review/"+file+".png")
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/atmosphere-review"))
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); economy=root.get_node("EconomySystem"); router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("B",2,true)
	gs.current_minute=660; gs.current_location="cafe"; gs.money=500
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	check(current_scene._spaces_at("cafe").is_empty(),"Grocery has no second interior entrance")
	check(not current_scene.street.hotspots.any(func(h):return h.kind=="door" and h.id=="grocery"),"No Enter Grocery hotspot remains")
	var counter=current_scene.street.hotspots.filter(func(h):return h.kind=="counter")[0]
	current_scene.street.player_x=counter.x; current_scene.street.move_player(0,0); current_scene._interact(); await settle()
	check(current_scene.event_overlay.visible and current_scene.event_panel.speaker_label.text=="杂货店老板","Storefront interaction opens owner dialogue in the street")
	await snapshot("grocery-dialogue")
	current_scene.event_panel.find_child("Grocery_shop",true,false).pressed.emit(); await settle()
	check(current_scene.pocket_panel.shop_id=="grocery" and router.active_space_id.is_empty(),"Purchase dialogue opens the shelf without entering a room")
	var panel=current_scene.pocket_panel
	for merchant in ["grocery","produce_stall"]:
		if merchant=="produce_stall":
			gs.current_location="produce_stall"
			panel=load("res://scripts/ui/shop_panel.gd").new(); panel.shop_id=merchant; current_scene.add_child(panel); await settle()
		check(panel.checkout_button.visible and panel.checkout_button.disabled,"Empty shelf still shows an explicit disabled checkout: "+merchant)
		var product: Dictionary=economy.stock(merchant)[0]
		panel._select(product); await settle()
		panel.find_child("AddToBasket",true,false).pressed.emit(); await settle()
		check(panel.mode=="shelf" and not panel.checkout_button.disabled,"Adding an item enables direct shelf checkout: "+merchant)
		check(panel.checkout_button.text.contains(str(int(product.price))),"Direct checkout shows the actual total: "+merchant)
		var saved_money: int=gs.money
		gs.money=0; panel._refresh()
		check(panel.checkout_button.disabled,"Shelf checkout prevents overspending: "+merchant)
		gs.money=saved_money; panel._refresh()
		await snapshot(merchant+"-checkout")
		var balance: int=gs.money; var inventory: int=gs.inventory.get(product.id,0)
		panel.checkout_button.pressed.emit(); await settle()
		check(panel.mode=="receipt" and gs.money==balance-int(product.price),"Shelf checkout charges once and displays the receipt: "+merchant)
		check(int(gs.inventory.get(product.id,0))==inventory+1 and economy.cart(merchant).is_empty(),"Direct checkout grants real goods and clears the cart: "+merchant)
		await snapshot(merchant+"-receipt")
		panel.queue_free(); await settle()
	# Real procurement and its real work-entry button, not a direct scene load.
	gs.current_location="night_market"; gs.current_minute=720; router.active_space_id="restaurant"
	change_scene_to_file("res://scenes/interactive_space.tscn"); await settle()
	check(economy.accept_procurement().ok,"Real restaurant counter accepts a procurement order")
	gs.current_location="produce_stall"
	for id in ["tomato","herbs","sea_beans"]: check(economy.purchase("produce_stall",id).ok,"Real procurement purchase: "+id)
	gs.current_location="night_market"
	check(economy.deliver_procurement().ok,"Real materials and receipts can be delivered")
	gs.current_minute=780
	economy.open_counter(current_scene,"restaurant"); await settle()
	var unavailable=get_nodes_in_group("economy_paper")[0]
	check(unavailable.find_child("StartRestaurantWork",true,false).disabled,"Work is disabled when 90 minutes cannot fit before the fixed shift")
	check(unavailable.find_children("*","Label",true,false).any(func(n):return n.text.contains("当前空闲时段放不下")),"Unavailable work has a visible reason beside its button")
	unavailable.queue_free(); await settle(); gs.current_minute=720
	economy.open_counter(current_scene,"restaurant"); await settle()
	var work=get_nodes_in_group("economy_paper")[0]
	var start=work.find_child("StartRestaurantWork",true,false)
	check(start!=null and not start.disabled and start.text.begins_with("开始"),"Natural, enabled Start Work label is present")
	if start==null or start.disabled: print("SHOP_WORK_ROUTES: ",checks," checks, ",failures," failures"); quit(1); return
	start.pressed.emit(); await settle()
	check(get_nodes_in_group("native_confirmation").size()==1,"Starting work produces exactly one confirmation")
	check(not router.request_gameplay("cooking","duplicate"),"A repeated click cannot create a second work confirmation")
	var sheet=get_nodes_in_group("native_confirmation")[0]
	await snapshot("start-work-confirmation")
	var confirm=sheet.find_children("*","Button",true,false).filter(func(b):return b.text=="开始工作")[0]
	confirm.pressed.emit(); await create_timer(1.5).timeout
	check(current_scene.scene_file_path=="res://scenes/native_module_game.tscn","Confirmed work loads the real cooking interface")
	check(root.get_node("GameplayModuleSystem").pending_module_id()=="cooking","Cooking has a real active gameplay transaction")
	check(get_nodes_in_group("native_confirmation").is_empty(),"No nested confirmation blocks cooking")
	await snapshot("cooking-open")
	print("SHOP_WORK_ROUTES: ",checks," checks, ",failures," failures")
	quit(failures)
