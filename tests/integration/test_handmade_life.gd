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
	DirAccess.make_dir_recursive_absolute("res://.runtime/handmade-captures")
	root.get_texture().get_image().save_png("res://.runtime/handmade-captures/"+tag+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.size=Vector2i(1600,900)
	var gs=root.get_node("GameState"); var economy=root.get_node("EconomySystem"); var save=root.get_node("SaveManager")
	var modules=root.get_node("GameplayModuleSystem")
	var recipes=load("res://scripts/core/recipe_book.gd")
	var fishing=load("res://scripts/core/coastal_fishing.gd")
	gs.begin_new_game("A"); gs.current_location="cafe"; gs.current_minute=660; gs.money=1000
	var shop=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="grocery"; root.add_child(shop); await settle()
	check(shop.item_list.get_child_count()==economy.stock("grocery").size(),"Each actual product has an independent button")
	var product=economy.stock("grocery")[0]
	shop._select(product); await snap("01-grocery")
	check(economy.set_cart_quantity("grocery","tomato",2).ok,"Cart supports quantities")
	check(economy.set_cart_quantity("grocery","matches",1).ok,"Cart supports multiple actual products")
	check(save.save_game() and save.load_game() and economy.cart("grocery").get("tomato",0)==2,"Unpaid basket survives save and reload")
	check(not economy.set_cart_quantity("grocery","crooked_cup",2).ok,"Unique stock cannot be overbooked")
	check(economy.cart_quote("grocery").total==28,"Cart total comes from catalog and quantities")
	shop.mode="basket"; shop._refresh(); await snap("02-basket")
	var old_script=save.get_script()
	var failing:=GDScript.new(); failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"; check(failing.reload()==OK,"Failure fixture compiles")
	var inventory: Dictionary=gs.inventory.duplicate(true)
	save.set_script(failing)
	check(not economy.purchase_cart("grocery").ok,"Checkout reports save failure")
	check(gs.money==1000 and gs.inventory==inventory and economy.cart("grocery").size()==2,"Failed cart checkout rolls back money, inventory and basket")
	check(economy.state().receipts.is_empty(),"Failed cart creates no receipt")
	save.set_script(old_script)
	shop._checkout(); await snap("03-receipt")
	check(gs.money==972 and gs.inventory.tomato==2 and gs.inventory.matches==1,"Checkout charges once and adds quantities")
	check(economy.state().receipts.size()==1 and shop.receipt.line_items.size()==2,"One checkout creates one itemized receipt")
	check(economy.cart("grocery").is_empty(),"Successful checkout empties basket")
	check(not economy.purchase_cart("grocery").ok and gs.money==972,"Repeated checkout cannot charge again")
	shop.mode="history"; shop._refresh_right(); await snap("04-purchases")
	shop.queue_free(); await settle()
	check(save.save_game(),"Save actual purchase history")
	gs.money=4; gs.inventory={}; check(save.load_game(),"Load purchased items")
	check(gs.money==972 and gs.inventory.tomato==2,"Purchases survive save/load")
	var stall=load("res://scripts/ui/shop_panel.gd").new(); stall.shop_id="produce_stall"; root.add_child(stall); await snap("05-produce"); stall.queue_free(); await settle()
	var row: Dictionary=recipes.originals()[0].duplicate(true)
	row.id=""; row.title="我的柠檬菜谱"; row.author="测试玩家"; row.strokes=[[[.1,.2],[.2,.4],[.7,.6]]]
	var saved: Dictionary=recipes.save_recipe(row); check(saved.ok,"Player recipe saves")
	row=saved.recipe; row.notes="更新后的笔记"; check(recipes.save_recipe(row).ok,"Recipe can be edited")
	check(recipes.entries("mine").size()==1 and recipes.entries("mine")[0].notes==row.notes,"Editing updates the same page rather than dropping changes")
	check(recipes.export_recipe(row,"user://test.solmere-recipe"),"Recipe exchange writes a real file")
	check(recipes.import_recipe("user://test.solmere-recipe").ok,"Other player recipe can be imported")
	check(recipes.entries("shared").size()==1,"Imported recipe appears in real shared archive")
	var bad: Dictionary=row.duplicate(true); bad.ingredients=["bad","id","paths"]
	check(recipes.validate(bad).is_empty(),"Unknown imported ingredients rejected")
	bad=row.duplicate(true); bad.heat={"invalid":true}
	check(recipes.validate(bad).is_empty(),"Non-numeric imported heat rejected without a script error")
	bad=row.duplicate(true); bad.strokes=[[[2.0,-1.0]]]
	check(recipes.validate(bad).is_empty(),"Invalid imported drawing rejected")
	var book=load("res://scripts/ui/recipe_book_panel.gd").new(); book.section="shared"; root.add_child(book); await snap("06-recipe-book")
	book.ingredients=["lemon","bread","cheese"]; book.chosen={}; book.editing=true; book._build()
	book.title_field.text="未写完的汤"; book.drawing.strokes=[[[.1,.1],[.5,.5]]]
	await snap("07-recipe-drawing")
	save.set_script(failing); book._close(); check(not book.is_queued_for_deletion(),"Failed draft save keeps editor open")
	save.set_script(old_script); book._close(); await settle()
	check(save.save_game() and save.load_game() and gs.artifacts.recipe_draft.title=="未写完的汤","Unfinished recipe survives close and load")
	book=load("res://scripts/ui/recipe_book_panel.gd").new(); root.add_child(book); book._begin_draft()
	check(book.title_field.text=="未写完的汤" and book.drawing.strokes.size()==1,"Draft resumes with actual text and strokes")
	book._save(); check(not gs.artifacts.has("recipe_draft") and recipes.entries("mine").size()==2,"Saving draft creates a complete recipe and clears draft atomically")
	book.queue_free(); await settle()
	check(save.save_game() and save.load_game(),"Recipes reload from normal save")
	check(recipes.entries("mine")[0].strokes.size()==1 and recipes.entries("shared").size()==1,"Drawings and imported recipes survive reload")
	gs.current_location="port"; gs.current_minute=700
	var panel=load("res://scripts/ui/coastal_fishing_panel.gd").new(); root.add_child(panel); await settle()
	panel._act(); check(panel.phase==panel.Phase.WAITING and gs.current_minute==710,"Casting uses actual time once")
	panel.timer=0; panel._process(.1); check(panel.phase==panel.Phase.BITE,"Float bite follows waiting")
	panel._act(); panel.set_process(false)
	check(panel.phase==panel.Phase.REELING,"Timely hook enters reeling")
	panel.cursor=panel.target; panel._act(); check(panel.progress>0,"Timed pull advances catch")
	await snap("08-fishing")
	while panel.phase==panel.Phase.REELING: panel.cursor=panel.target; panel._act()
	check(panel.phase==panel.Phase.LANDED and not fishing.state().pending.is_empty(),"Landing preserves pending fish")
	var fish_id: String=panel.fish.id
	await snap("09-catch")
	save.set_script(failing); panel._resolve(true)
	check(not fishing.state().pending.is_empty() and not gs.inventory.has(fish_id),"Failed catch save retains fish without awarding it")
	save.set_script(old_script); panel._resolve(true)
	check(gs.inventory.get(fish_id,0)==1 and fishing.state().catches.size()==1,"Keep awards one ingredient")
	check(not fishing.resolve(true).ok,"Cannot claim fish twice")
	panel.queue_free(); await settle()
	check(save.save_game() and save.load_game() and gs.inventory.get(fish_id,0)==1,"Fish survives load")
	var cast: Dictionary=fishing.begin_cast(); check(cast.ok and fishing.land(cast.fish),"Second landed fish is saved")
	var before_release: Dictionary=gs.inventory.duplicate(true)
	check(fishing.resolve(false).ok and gs.inventory==before_release and fishing.state().catches.size()==2,"Release records the fish without adding ingredients")
	check(not fishing.land(cast.fish),"Released fish cannot be landed a second time")
	gs.current_location="night_market"; gs.current_minute=660; gs.inventory["herbs"]=1; gs.inventory["lemon"]=1
	check(modules.begin_session("cooking","handmade_test"),"Cooking still enters existing module")
	var kitchen=load("res://scenes/native_module_game.tscn").instantiate(); root.add_child(kitchen); await settle()
	for id in [fish_id,"herbs","lemon"]: kitchen._toggle_token(id)
	kitchen.value_slider.value=.58; kitchen._perform_primary_action()
	check(kitchen.stage_ready,"Caught fish works as a real cooking ingredient")
	await snap("10-kitchen")
	kitchen._complete_choice("careful_menu")
	check(kitchen.completed and not gs.inventory.has(fish_id),"Cooking consumes real caught fish")
	kitchen.queue_free(); await settle()
	gs.begin_new_game("B"); gs.current_minute=660; gs.current_location="night_market"
	var router=root.get_node("SceneRouter"); router.active_space_id="restaurant"
	check(economy.accept_procurement().ok,"Restaurant accepts procurement before basket test")
	gs.current_location="cafe"; router.active_space_id=""
	for id in ["tomato","herbs","star_salt","soap"]: check(economy.set_cart_quantity("grocery",id,1).ok,"Mixed basket accepts "+id)
	check(economy.set_cart_quantity("grocery","tomato",2).ok,"Extra private quantity accepted")
	var mixed: Dictionary=economy.purchase_cart("grocery")
	check(mixed.ok and mixed.receipt.category=="mixed","Mixed checkout retains distinct receipt categories")
	var balance: int=gs.money
	gs.current_location="night_market"; router.active_space_id="restaurant"
	var reimbursed: Dictionary=economy.deliver_procurement()
	var expected := 0
	for line in mixed.receipt.line_items:
		if str(line.item_id) in ["tomato","herbs","star_salt"]: expected+=int(line.unit_price)
	check(reimbursed.ok and gs.money==balance+expected,"Only ordered food is reimbursed, excluding soap and spare tomato")
	print("HANDMADE LIFE: ",checks," checks, ",failures," failures")
	quit(failures)
