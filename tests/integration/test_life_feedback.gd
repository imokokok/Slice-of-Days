extends SceneTree
var failures := 0
var checks := 0
var gs: Node
var loop: Node
var guide: Node
var residency: Node
var save: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(why)
func settle() -> void:
	await process_frame; await process_frame
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(.25).timeout; await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://production_"+tag+".png")
func key_action(action: String) -> void:
	for binding in InputMap.action_get_events(action):
		if not binding is InputEventKey: continue
		var event: InputEventKey=binding.duplicate(); event.pressed=true; Input.parse_input_event(event)
		await settle(); event.pressed=false; Input.parse_input_event(event); await settle(); return
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	gs=root.get_node("GameState"); loop=root.get_node("CoreLoopSystem"); guide=root.get_node("GuidanceSystem"); residency=root.get_node("ResidencySystem"); save=root.get_node("SaveManager")
	if OS.get_cmdline_user_args().has("--load-only"):
		check(save.load_game("user://production_roundtrip.json"),"Reload production state in a fresh process")
		var c: Dictionary=loop.state().callbacks.A_module_tarot_0
		check(c.shared and not c.returned,"A half-finished exchange survives quitting")
		check(residency.state().materials.has(c.reply_material),"The resident's response is a canonical saved material")
		check(loop.share_material("xia_touming",str(c.reply_material)).ok,"Return the saved response after restarting")
		check(c.returned and not loop.share_material("xia_touming",str(c.reply_material)).ok,"Return completes once and cannot be farmed")
		print("PRODUCTION RELOAD checks=",checks," failures=",failures); quit(failures); return
	root.get_node("ChapterSystem").start_new_game("A")
	gs.current_minute=600; gs.current_location="produce_stall"; gs.shared_state.typewriter=false
	root.get_node("SceneRouter").town_day(.01); await create_timer(.8).timeout
	var shell: Control=current_scene.get_node("GameplayShell")
	guide.refresh(); shell._update_active_direction(); await settle()
	check(guide.feedback_queue.is_empty(),"A new day does not duplicate its direction as a notification")
	check(shell.next_button.title.text.contains("领取资料袋") and shell.next_button.context.visible,"The current action and useful context are separate real labels")
	check(shell.next_button.get_theme_stylebox("normal").bg_color.a==1,"Direction stays opaque over bright sky")
	check(shell.hints.get_theme_stylebox("normal").bg_color.a==1,"Nearby prompt has its own readable solid surface")
	shell.next_button.present({"text":"一段很长的私人安排".repeat(60),"context":"很长的记录".repeat(70),"action":"personal"})
	await settle()
	check(shell.next_button.size.y<310 and shell.next_button.tooltip_text.contains("一段很长的私人安排"),"Long private plans remain bounded on screen while preserving the full text")
	shell._update_active_direction(); await settle()
	await capture("01_exploration")
	await key_action("open_notebook")
	check(is_instance_valid(shell.overlay),"The actual Input Map binding opens the notebook")
	await key_action("ui_cancel")
	check(not is_instance_valid(shell.overlay),"The actual cancel binding closes the notebook")
	gs.current_minute=660
	current_scene._rebuild_hotspots()
	for point in current_scene.street.hotspots:
		if str(point.get("id",""))=="beetman": current_scene.street.player_x=float(point.x)
	await settle(); shell.hints.pressed.emit(); await settle()
	check(is_instance_valid(current_scene.conversation) and current_scene.conversation.npc=="beetman","The visible context control starts the actual nearest resident conversation")
	await key_action("ui_cancel")
	check(not is_instance_valid(current_scene.conversation),"Esc leaves that conversation without forcing the player through it")
	await key_action("talk")
	check(is_instance_valid(current_scene.conversation),"The mapped talk action uses the same real conversation path")
	await key_action("ui_cancel")
	guide.hear("personal_destination","想先看看书店","maya","library"); guide.track("personal_destination")
	check(guide.next_step().location=="library" and guide.next_step().priority=="personal","A deliberate tracked lead outranks daily suggestions")
	guide.track("")
	# Use the same canonical module material/event contract as actual activity completion.
	residency._add("module_tarot_0","work","那张没有定论的牌",{"source":"module:tarot:0"})
	loop.encounter("xia_touming"); loop._module_completed("A","tarot",{})
	check(loop.connection_steps().is_empty(),"A next-day reply does not pretend to be ready immediately")
	check(not guide.leads().any(func(row: Dictionary) -> bool: return str(row.id)=="return_A_module_tarot_0"),"Premature return leads do not misdirect the player")
	gs.current_day=2; gs.current_minute=600; guide.refresh()
	var c: Dictionary=loop.state().callbacks.A_module_tarot_0
	check(str(loop.dialogue_prefix("chenyuan")).contains("也让我看看") and not str(loop.dialogue_prefix("chenyuan")).contains("我没有收进抽屉"),"A resident never claims to have seen an unshared work")
	check(loop.connection_steps()[0].npc=="chenyuan","The completed tarot activity connects to the authored childhood friend")
	check(loop.connection_steps()[0].location==loop.npc_place("chenyuan"),"A person is found at their current schedule, not a hardcoded old shop")
	guide.track("return_A_module_tarot_0")
	check(guide.tracked_lead().location=="produce_stall" and guide.tracked_lead().text.contains("先听听"),"A tracked return follows the real argument encounter before direct conversation is possible")
	guide.track("")
	var talk: Control=load("res://scripts/ui/conversation_panel.gd").new(); talk.npc="chenyuan"; current_scene.add_child(talk); await settle()
	talk._close(); await settle()
	check(not c.acknowledged and not c.shared,"Leaving early never completes the exchange")
	loop.encounter("chenyuan")
	var original_script=save.get_script()
	var failing := GDScript.new(); failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"; failing.reload()
	save.set_script(failing)
	check(not loop.share_material("chenyuan","module_tarot_0").ok,"A failed exchange save reports failure")
	save.set_script(original_script)
	c=loop.state().callbacks.A_module_tarot_0
	check(not c.shared and not residency.state().materials.has("reply_A_module_tarot_0"),"Save failure rolls back both exchange and response, keeping the original")
	var result: Dictionary=loop.share_material("chenyuan","module_tarot_0")
	check(result.ok and result.message.contains("反驳"),"Sharing the real work gives the specific relationship response")
	c=loop.state().callbacks.A_module_tarot_0
	check(c.shared and residency.state().materials[c.reply_material].source_material=="module_tarot_0","The response refers to the original unique material")
	check(loop.material_in_use(str(c.reply_material)),"An unreturned response cannot be deleted out from under the chain")
	check(loop.connection_steps()[0].npc=="xia_touming" and loop.connection_steps()[0].returning,"The next direction returns to the original collaborator")
	check(loop.share_candidates("xia_touming")[0].id==c.reply_material,"Conversation offers the relevant response before unrelated material")
	check(not loop.share_material("chenyuan","module_tarot_0").ok,"Repeated shares do not duplicate the response")
	guide.refresh(); shell._update_active_direction(); await capture("02_response_direction")
	shell.open_paper("notebook"); await settle(); var paper: Control=shell.overlay
	paper.notebook_section="connections"; paper.build(); await settle(); await capture("03_connections")
	check(paper.body.find_child("Connection_*",true,false)!=null,"Notebook builds real clickable relationship steps")
	paper.mode="dossier"; paper.archive_tab="personal"; paper.build()
	check(paper.body.find_children("PortfolioDay_*","Button",true,false).is_empty(),"Ordinary archive sections never acquire day tabs")
	paper.archive_tab="days"; paper.build(); check(paper.body.find_children("PortfolioDay_*","Button",true,false).size()==7,"Portfolio retains all seven functional pages")
	paper.close(); await settle()
	guide.feedback_queue.clear(); guide.queue_feedback("DONE","今天做了第一件东西"); guide.queue_feedback("FOUND","尘缘留下的几句话"); guide.feedback_age=1
	var notice: Dictionary=guide.take_feedback()
	check(notice.entries.size()==2 and not notice.text.contains("DONE") and not notice.text.contains("FOUND"),"Combined notices keep event data but display authored language")
	guide.queue_feedback("HEARD","带给夏透明看看"); guide.feedback_age=1
	shell.open_paper("notebook"); check(guide.take_feedback().is_empty(),"A modal does not consume waiting feedback")
	shell.overlay.close(); await settle(); guide.feedback_age=1
	# Purchase through the current native item, basket and checkout controls.
	gs.money=200; gs.current_location="produce_stall"; gs.current_minute=700
	var shop: Control=load("res://scripts/ui/shop_panel.gd").new(); shop.shop_id="produce_stall"; current_scene.add_child(shop); await settle()
	var can: Button=shop.item_list.get_node("Select_sea_beans"); can.pressed.emit(); await settle(); await capture("04_shop")
	check(shop.selected_item.id=="sea_beans" and not shop.purchase_button.disabled,"The illustrated can is a real purchasable catalog item")
	var before_money: int=gs.money; var before_quantity: int=gs.inventory.get("sea_beans",0)
	shop.purchase_button.pressed.emit(); await settle()
	check(gs.money==before_money,"Adding to the basket does not charge money")
	shop.mode="basket"; shop._refresh_right(); await settle()
	shop.purchase_button.pressed.emit(); await settle()
	check(gs.money==before_money-15 and int(gs.inventory.sea_beans)==before_quantity+1,"Checkout pays exactly once and adds the actual item")
	shop.queue_free(); await settle(); shell.open_paper("bag"); await settle(); await capture("05_pocket")
	check(shell.overlay.body.find_child("PocketItem_sea_beans",true,false)!=null,"The purchased item appears dynamically in the bag")
	shell.overlay.close(); await settle()
	shell.open_paper("settings"); await settle(); await capture("06_settings")
	var slider: HSlider=shell.overlay.body.find_child("master_volume",true,false); slider.value=62
	check(root.get_node("SettingsSystem").values.master_volume==62 and get_tree_paused(),"Settings change the real bus setting while gameplay stays paused")
	shell.overlay.close(); await settle(); check(not paused,"Closing settings releases the real pause")
	check(save.save_game("user://production_roundtrip.json"),"Save the unfinished return, real purchase and all persistent UI data")
	print("PRODUCTION UI checks=",checks," failures=",failures); quit(failures)
func get_tree_paused() -> bool: return paused
