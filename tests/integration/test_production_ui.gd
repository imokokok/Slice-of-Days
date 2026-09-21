extends SceneTree
var failures := 0
var captures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func settle() -> void:
	await process_frame; await process_frame
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	Input.warp_mouse(Vector2.ZERO)
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://production_"+tag+".png"); captures+=1
func confirmation() -> Control:
	var items := get_nodes_in_group("native_confirmation")
	return items.back() if not items.is_empty() else null
func accept_confirmation() -> void:
	var confirm := confirmation()
	check(is_instance_valid(confirm),"A real confirmation must exist")
	if is_instance_valid(confirm):
		var buttons := confirm.find_children("*","Button",true,false)
		buttons.back().pressed.emit()
	await settle()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var film = root.get_node("FilmSystem")
	var travel = root.get_node("TravelSystem")
	var save = root.get_node("SaveManager")
	root.get_node("ChapterSystem").start_new_game("A")
	state.current_location="cafe"; state.current_minute=660; state.money=800
	router.town_day(.01); await create_timer(.6).timeout
	state.shared_state.typewriter=false
	await snap("exploration")
	var shell = current_scene.get_node("GameplayShell")
	state.shared_state["knowledge_A"]=[{"id":"long_notebook_lead","text":"杂货店 08:00—22:00；番茄12元、青草10元、星形盐片22元。日用品、酱料和摄影柜台都在这里。","source_npc_id":"grocery","subject_id":"cafe","predicate":"lead","confidence":1.0}]
	shell.open_paper("notebook"); await settle()
	var preview= shell.overlay.find_child("HeardPreview_0",true,false)
	check(is_instance_valid(preview) and preview.size.x<=380,"Long real leads stay inside the left notebook page")
	await snap("notebook_long_lead"); shell.overlay.close(); await settle()
	state.shared_state["knowledge_A"]=[]
	var dialogue = load("res://scripts/ui/conversation_panel.gd").new(); dialogue.npc="wu_wu"; current_scene.add_child(dialogue); await settle(); dialogue._advance()
	await snap("dialogue_choices")
	check(dialogue.vendor_choices.get_child_count()>=3,"Dialogue choices remain native branches")
	dialogue._close(); await settle()
	var ask = load("res://scripts/meta/ask_panel.gd").new(); ask.npc="grocery"; current_scene.add_child(ask); await settle()
	var answer: Array=[]
	ask.chosen.connect(func(topic: String) -> void: answer.append(topic))
	var ask_buttons: Array=ask.find_children("*","Button",true,false)
	check(ask_buttons.size()==4 and ask_buttons[0].get_script()==load("res://scripts/ui/components/dialogue_choice.gd"),"Follow-up questions share the real dialogue choice component")
	await snap("ask_choices")
	ask_buttons[0].pressed.emit(); ask_buttons[0].pressed.emit(); await settle()
	check(answer==["schedule_info"],"Question selection emits the real topic once")
	var shop = load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="grocery"; current_scene.add_child(shop); await settle()
	var product: Dictionary=root.get_node("EconomySystem").stock("grocery")[0]
	shop._select(product); await snap("shop_selected")
	var before: int=state.money
	shop.purchase_button.pressed.emit(); await settle(); check(state.money==before,"Selecting purchase does not charge before confirmation")
	await snap("purchase_confirm")
	await accept_confirmation(); check(state.money==before-int(product.price),"Purchase confirmation charges once")
	check(int(state.inventory.get(product.id,0))>0,"Bought item enters actual inventory")
	await snap("purchase_receipt")
	state.money=0; shop._refresh(); check(shop.purchase_button.disabled,"Insufficient balance disables purchase")
	await snap("shop_insufficient"); state.money=800; shop.queue_free(); await settle()
	shell.open_paper("bag"); await settle(); await snap("inventory"); shell.overlay.close(); await settle()
	film.notice_camera()
	var counter = load("res://scripts/photography/film_paper.gd").new(); current_scene.add_child(counter); await settle()
	counter._act("camera"); await accept_confirmation(); check(film.state().camera_owned,"Camera purchase is real")
	await snap("film_counter")
	counter.queue_free(); await settle()
	if DisplayServer.get_name()!="headless":
		shell.open_tool("camera"); await create_timer(.3).timeout; await snap("camera_fullscreen")
		await shell.tool.take_photo(); await create_timer(.4).timeout
		check(int(film.active_roll().exposures_used)==1,"Full-screen shutter consumes one real film exposure")
		shell.tool.queue_free(); await settle()
		counter=load("res://scripts/photography/film_paper.gd").new(); current_scene.add_child(counter); await settle()
		counter._act("rush",str(film.active_roll().id)); await snap("develop_confirm"); await accept_confirmation()
		await snap("develop_wait"); counter.queue_free(); await settle()
	shell.open_paper("sound_library"); await settle(); await snap("recorder_library"); shell.overlay.close(); await settle()
	shell.open_tool("recorder"); await settle(); shell.tool.toggle_recording(); await create_timer(.7).timeout; await snap("recorder_live")
	shell.tool.finish_for_exit(); await settle()
	var economy = load("res://scripts/ui/economy_paper.gd").new(); current_scene.add_child(economy); await settle(); await snap("restaurant_order"); economy.queue_free(); await settle()
	state.current_location="record_store"
	var studio = load("res://scripts/town_sound/studio/StudioScreen.gd").new(); current_scene.add_child(studio); await settle()
	var samples: Array=load("res://scripts/town_sound/data/SampleStore.gd").new().list_samples()
	if not samples.is_empty():
		var count: int=studio.model.clips.size()
		studio.selected=studio.model.add_sample(samples[0],0,0); studio.changed()
		check(studio.model.clips.size()==count+1,"Studio uses a real recording")
		studio._undo_edit(); check(studio.model.clips.size()==count,"Studio undo restores tracks")
		studio._redo_edit(); check(studio.model.clips.size()==count+1,"Studio redo restores the edited clip")
	await snap("music_studio"); studio.queue_free(); await settle(); state.current_location="cafe"
	shell.open_paper("map"); await settle(); var map = shell.overlay
	map._map_select("produce_stall"); await snap("travel_options")
	before=state.money; var minute: int=state.current_minute
	map._travel_selected("walk"); await settle(); await snap("travel_confirm")
	check(state.money==before and state.current_minute==minute,"Route preview does not spend money or time")
	await accept_confirmation(); await create_timer(.6).timeout; await snap("travel_card")
	while router.transitioning: await process_frame
	check(state.current_location=="produce_stall" and state.current_minute>minute,"Confirmed route changes location and clock")
	check(root.get_node("KnowledgeSystem").facts().is_empty(),"Walking does not fabricate transport rumors")
	await snap("arrival")
	check(not travel.route("produce_stall","park","friend","A",state.current_minute).available,"Unknown residents cannot lend a car")
	root.get_node("RelationshipSystem").add_flags("wu_wu",["ride_offered"])
	check(travel.route("produce_stall","park","friend","A",state.current_minute).available,"A real relationship flag unlocks friend travel")
	check(save.save_game(),"Updated UI state persists through existing save system")
	if DisplayServer.get_name()!="headless":
		check(save.save_thumbnail(await current_scene.get_node("GameplayShell")._camera_source()),"A save thumbnail captures the actual world")
	check(save.slot_summary(save.active_slot).location==state.current_location,"Slot metadata includes actual location")
	var modules = root.get_node("GameplayModuleSystem")
	for id in ["cooking","tarot","chess","contemplation","ghostwriting"]:
		state.current_minute=1260 if id=="contemplation" else 660
		var started: bool=modules.begin_session(id,"production_ui_"+id)
		print("Production capture ",id," session=",started," pending=",modules.pending_module_id())
		check(started,"Start real module "+id)
		if not started: continue
		var scene = load("res://scenes/native_module_game.tscn" if id=="cooking" else "res://scenes/extension_host.tscn").instantiate()
		current_scene.hide(); root.add_child(scene); await create_timer(.3).timeout; await snap("minigame_"+id)
		scene.queue_free(); await settle(); current_scene.show(); modules.cancel_session()
	var menu = load("res://scenes/main_menu.tscn").instantiate(); current_scene.hide(); root.add_child(menu); await settle(); await snap("title")
	menu._show_chapters(); await snap("save_slots"); menu.queue_free(); await settle(); current_scene.show()
	print("PRODUCTION UI failures=",failures," screenshots=",captures)
	quit(failures)
