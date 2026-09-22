extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; push_error(why)
func settle() -> void:
	await process_frame
	await process_frame
func capture(tag: String) -> void:
	await settle()
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://world_ui_"+tag+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game("A")
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.6).timeout
	state.money=200
	state.current_minute=660
	var scene = current_scene
	scene._open_shop("grocery")
	await settle()
	var shop = scene.pocket_panel
	var stock: Array = root.get_node("EconomySystem").stock("grocery")
	check(shop.item_list.get_child_count()==stock.size(),"Every real shelf item has its own control")
	var item: Dictionary = stock[0]
	for row in stock:
		if "bean" in str(row.id) or "can" in str(row.id): item=row; break
	var before: int = state.money
	var count: int = int(state.inventory.get(str(item.id),0))
	shop._select(item); shop.purchase_button.pressed.emit()
	shop.mode="basket"; shop._refresh_right(); shop.purchase_button.pressed.emit()
	await settle()
	check(state.money==before-int(item.price),"Purchase deducts displayed price once")
	check(int(state.inventory.get(str(item.id),0))==count+1,"Purchase enters bag")
	shop._checkout()
	check(state.money==before-int(item.price),"Double click cannot purchase twice")
	check(not shop.receipt.is_empty() and shop.mode=="receipt","Actual receipt remains available after checkout")
	var snapshot: Dictionary = state.to_save_data().duplicate(true)
	state.load_save_data(snapshot)
	check(int(state.inventory.get(str(item.id),0))==count+1,"Purchased goods survive serialization")
	var backdrop: ColorRect=shop.get_child(0)
	check(backdrop.color.a==1,"Handmade shelf has an opaque reading surface")
	await capture("shop")
	shop.queue_free(); await settle()
	scene._open_shop("produce_stall"); await settle()
	shop=scene.pocket_panel
	var can: Dictionary = {}
	for row in root.get_node("EconomySystem").stock("produce_stall"):
		if str(row.id)=="sea_beans": can=row
	check(not can.is_empty(),"Canned goods are present on shelf")
	if not can.is_empty():
		var can_count := int(state.inventory.get("sea_beans",0))
		shop._buy(can); await settle()
		check(int(state.inventory.get("sea_beans",0))==can_count+1,"Can purchase enters bag")
		await capture("cans")
	shop.queue_free(); await settle()
	var shell = scene.get_node("GameplayShell")
	shell.open_paper("bag"); await settle()
	check(shell.overlay.mode=="bag","Backpack opens within carried objects")
	await capture("bag")
	shell.overlay.close(); await settle()
	var talk = load("res://scripts/ui/conversation_panel.gd").new()
	talk.npc="beetman"; talk.shop_id="produce_stall"; talk.shop_name="BEETMAN"
	scene.add_child(talk); await settle()
	talk._show_vendor_choices(); await settle()
	check(talk.speech_card.get_theme_stylebox("panel").bg_color.a==1,"Dialogue has an opaque backing")
	check(talk.speech_card.position.y+talk.speech_card.size.y<scene.street._actor_ground_at(scene.street.player_x),"Dialogue and choices stay near the actor without covering feet")
	await capture("speech")
	talk.queue_free(); await settle()
	scene._show_line("尘缘","海风把刚才的话带远了一点。我们沿着路再走走吧。")
	await settle()
	check(scene.event_panel.get_theme_stylebox("panel").bg_color.a==1,"Event dialogue shares the opaque backing")
	await capture("event")
	scene.event_overlay.hide()
	root.get_node("GameplayModuleSystem").begin_session("cooking")
	var game = load("res://scripts/ui/native_module_game.gd").new()
	scene.add_child(game); await settle()
	game._toggle_token("bread")
	await settle()
	if game.token_buttons.has("bread"):
		check(game.token_buttons.bread.selected,"Selected ingredient retains native selection state")
	await capture("cooking")
	game.queue_free(); await settle()
	root.get_node("SceneRouter").enter_space("home_a")
	await create_timer(.7).timeout
	var room = current_scene
	room.cue_label.text="窗边的光慢慢移过地板。今天先记下这一刻。"
	room.room_dialogue.show()
	await settle()
	check(room.room_dialogue.get_theme_stylebox("panel").bg_color.a==1,"Room dialogue shares the opaque backing")
	check(root.get_visible_rect().encloses(room.room_dialogue.get_global_rect()),"Room words stay inside the view")
	check(preload("res://scripts/ui/components/dialogue_layout.gd").overlap(room.room_dialogue.get_global_rect(),room.stage.dialogue_obstacles().actors)==0,"Room words do not cover characters")
	await create_timer(1.1).timeout
	await capture("room")
	room.room_dialogue.hide()
	root.get_node("SceneRouter").journal(); await settle()
	check(room.get_node("GameplayShell").overlay.mode=="notebook","Legacy journal uses carried notebook")
	room.get_node("GameplayShell").overlay.close(); await settle()
	print("WORLD UI failures=",failures)
	quit(failures)
