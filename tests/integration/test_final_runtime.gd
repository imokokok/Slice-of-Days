extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS ",title)
	else: failures += 1; push_error(title)
func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/final_"+title+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.gui_disable_input = true
	var gs = root.get_node("GameState")
	var rs = root.get_node("ResidencySystem")
	var router = root.get_node("SceneRouter")
	var modules = root.get_node("GameplayModuleSystem")
	gs.begin_new_game("A")
	var chapters=root.get_node("ChapterSystem")
	var sequence: Array=chapters.chapter_sequence()
	check(sequence.size()==14,"Both protagonists receive seven playable days")
	for role in ["A","B"]:
		check(sequence.slice(0,12).filter(func(c: Dictionary) -> bool: return str(c.role)==role).size()==6,"Six pre-final chapters for "+role)
	gs.current_location = "print_shop"
	gs.current_minute = 620
	router.active_space_id = "print_studio"
	check(rs.state().pages.size()==7,"Exactly seven pages, intro kept separate")
	check(rs.collect_packet().contains("六份"),"Collect packet at community counter")
	check(rs.state().materials.size()==6,"Six physical official papers")
	check(rs.collect_packet().contains("领过"),"Packet cannot be duplicated")
	check(not rs.set_field(2,"today","future"),"No future page writing")
	gs.spend_money(8,"购买番茄")
	gs.earn_money(40,"完成module_cooking_external")
	check(rs.state().ledger.size()==2,"Actual transactions enter full ledger")
	var income_id := ""
	for item in rs.state().materials.values():
		if item.get("proof_kind","")=="income": income_id=str(item.id)
	check(not income_id.is_empty(),"Paid work creates income record")
	check(rs.collect_proof(income_id).contains("请回到"),"Proof requires correct counter")
	gs.current_location="night_market"
	router.active_space_id="restaurant"
	gs.current_minute=600
	check(rs.collect_proof(income_id).contains("关闭"),"Closed counter cannot issue proof")
	gs.current_minute=730
	var before: int=gs.money
	check(rs.collect_proof(income_id).contains("已放入"),"Open counter issues proof")
	check(gs.money==before,"Collecting proof does not pay again")
	check(rs.collect_proof(income_id).contains("领过"),"Proof cannot be duplicated")
	modules.unlock("cooking")
	modules.complete("cooking",{"label":"柠檬香草汤","day":1})
	check(not rs.collect_proof("module_cooking_0").contains("已放入"),"Created work waits for real town acceptance")
	check(bool(rs.accept_contribution("module_cooking_0","night_market",{"source":"counter_handover"}).ok),"Actual counter accepts the completed contribution")
	check(rs.collect_proof("module_cooking_0").contains("已放入"),"Accepted contribution issues proof")
	check(rs.file_material("proof_"+income_id,"proof"),"Player can file income proof")
	check(rs.file_material("proof_module_cooking_0","proof"),"Player can file contribution proof")
	var note: String=rs.add_note("第一次经过海边")
	check(rs.file_material(note,"day_1"),"Explicit filing attaches player note")
	check(rs.file_material(note,"personal"),"Material can move between sections")
	check(not rs.state().pages[0].keep.has(note),"Moving material removes previous attachment")
	var snapshot: Dictionary=gs.to_save_data().duplicate(true)
	gs.switch_to_role("B",1,true)
	check(not rs.state().packet and rs.state().materials.is_empty(),"A/B dossier isolation")
	gs.load_save_data(snapshot)
	check(rs.state().packet and rs.state().materials.has(note),"Round-trip save restores materials and packet")
	check(chapters.current_chapter().role==gs.current_role and chapters.current_chapter().day==gs.current_day,"Loaded save aligns to role/day chapter")
	gs.current_day=7
	for d in range(1,8):
		rs.set_field(d,"today","第 %d 天的生活" % d)
		rs.set_field(d,"record","写下真实的感受，不必替空白编造经历。")
		rs.check_ledger(d)
	for key in ["discovered","changed","other"]: rs.set_field(2,key,"海边 · 下午 · 沿主街 · 想再走一遍")
	check(not rs.audit().requirements.exploration,"Freeform Day 2 answers do not replace field evidence")
	gs.current_location="port"; gs.current_minute=660; rs.visit("port")
	check(bool(rs.record_exploration("discover","port","第一次来这里，海鸥停在护栏。").ok),"Create the discovery record from an actual visit")
	gs.current_minute=780; rs.visit("port")
	check(bool(rs.record_exploration("revisit","port","午后的同一处护栏，影子转到另一边。").ok),"Create a different-time revisit record")
	gs.current_location="library"; rs.visit("library")
	check(bool(rs.record_exploration("shareplace","library","想带朋友来这里的窗边看书。").ok),"Create the place-to-share record")
	for kind in ["discover","revisit","shareplace"]: check(rs.file_material("explore_"+kind,"day_2"),"File distinct exploration "+kind)
	var economy = root.get_node("EconomySystem")
	for purchase in [["produce_stall","tomato"],["produce_stall","herbs"],["grocery","soap"]]:
		gs.current_location="produce_stall" if purchase[0]=="produce_stall" else "cafe"
		var transaction: Dictionary=economy.purchase(str(purchase[0]),str(purchase[1]))
		check(bool(transaction.get("ok",false)),"Actual living purchase "+str(purchase[1]))
		if bool(transaction.get("ok",false)): check(rs.file_material(str(transaction.receipt.id),"day_3"),"File sourced living receipt "+str(purchase[1]))
	rs.set_field(5,"free","我喜欢录下普通日子的声音。")
	rs.set_field(7,"why_stay","想继续听听这里的早晨。")
	rs.set_field(7,"choice","还没想好")
	rs.set_field(7,"signature","A")
	check(not rs.audit().ready,"Recognition remains required")
	var residents: Array=["mossner","xanni","chenyuan","maya","mingming","zhou_xiaoliu","beetman","xia_touming","yuxingqing","shi_yongqi","naonao","wu_wu"]
	for i in residents.size():
		root.get_node("RelationshipSystem").set_confirmation(residents[i],"granted")
		check(rs.assign_mark(residents[i],1+i/2),"File earned resident mark %d" % i)
	check(not rs.assign_mark("fake_resident",7),"Unrecognized person cannot sign")
	check(rs.audit().ready,"All genuine requirements accepted")
	gs.current_location="print_shop"
	router.active_space_id="print_studio"
	gs.current_minute=1080
	check(not rs.submit().ok,"18:00 deadline enforced")
	gs.current_minute=1079
	var ready_snapshot: Dictionary=gs.to_save_data().duplicate(true)
	check(rs.submit().ok,"Complete dossier accepted before deadline")
	check(not rs.set_field(1,"today","overwrite"),"Submitted original is immutable")
	check(not rs.submit().ok,"Submission is idempotent")
	gs.load_save_data(ready_snapshot)
	gs.current_minute=1000
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.6).timeout
	check(current_scene.has_node("GameplayShell"),"New shell present indoors")
	var shell=current_scene.get_node("GameplayShell")
	for mode in ["dossier","fieldbook","gallery","map","home","pause","controls","settings","counter","proofs","notebook"]:
		shell.open_paper(mode)
		await create_timer(.12).timeout
		check(is_instance_valid(shell.overlay),"Open overlay "+mode)
		if not is_instance_valid(shell.overlay): continue
		var panel=shell.overlay
		if mode=="dossier":
			await shot("requirements")
			panel.tab="days";panel.day=7;panel.build()
			await create_timer(.12).timeout
			await shot("day7")
		if mode=="map": await shot("map")
		check(not current_scene.stage.enabled,"Paper overlay pauses walking "+mode)
		panel.close()
		await create_timer(.12).timeout
	gs.current_day=3
	gs.current_location="residence"
	gs.current_minute=1150
	router.active_space_id="home_a"
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.5).timeout
	shell=current_scene.get_node("GameplayShell")
	shell.open_paper("organize")
	await create_timer(.2).timeout
	check(rs.can_organize(),"Evening home allows organize")
	await shot("organize")
	shell.overlay.close()
	await create_timer(.15).timeout
	gs.current_location="bus_stop"
	router.active_space_id=""
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	check(current_scene.has_node("GameplayShell"),"New shell present outdoors")
	await shot("town")
	var dialogue=load("res://scripts/ui/conversation_panel.gd").new()
	dialogue.npc="xanni"
	current_scene.add_child(dialogue)
	await create_timer(.5).timeout
	check(dialogue.speech_card.size.x<=440,"Dialogue uses a small speaker card")
	await shot("dialogue")
	dialogue.queue_free()
	var debug=load("res://scripts/meta/runtime_debug.gd").new()
	current_scene.add_child(debug)
	await create_timer(.1).timeout
	check(debug.report.text.contains("档案"),"Debug exposes real dossier audit state")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(.4).timeout
	current_scene._show_chapters()
	await process_frame
	check(current_scene.modal_overlay.visible,"Fourteen chapter menu opens")
	await shot("chapters")
	print("FINAL_RUNTIME ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
