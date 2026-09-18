extends SceneTree
## Domain integration with controlled location/time fixtures. Production map/door
## inputs are covered by test_patch_residency. Here purchases, paper buttons,
## explore forms, recognition events, drag handlers and disk saves are real.
var failures := 0
var checks := 0
var gs: Node
var rs: Node
var economy: Node
var router: Node
var relationships: Node
var paper: Control

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func named(target: String) -> bool:
	var b := paper.find_child(target,true,false) as Button
	if not is_instance_valid(b) or b.disabled: return false
	b.pressed.emit()
	await settle()
	return true

func text_button(parent: Node, caption: String) -> bool:
	for candidate in parent.find_children("*","Button",true,false):
		var b := candidate as Button
		if b.text == caption and not b.disabled:
			b.pressed.emit()
			await settle()
			return true
	return false

func open_paper(mode: String, tab := "packet") -> void:
	if is_instance_valid(paper): paper.queue_free(); await settle()
	paper = load("res://scripts/residency/paper_overlay.gd").new()
	paper.mode = mode
	paper.tab = tab
	root.add_child(paper)
	await settle()

func file_paper(id: String, caption := "夹入当前日  F") -> bool:
	paper._show_detail(id)
	await settle()
	if not is_instance_valid(paper.detail): return false
	return await text_button(paper.detail,caption)

func context(location: String, space: String, minute: int) -> void:
	gs.current_location = location
	gs.current_minute = minute
	router.active_space_id = space
	gs.commit_active_role_state()

func purchase(shop: String, item: String) -> String:
	var before: Array = economy.state().receipts.keys()
	var panel = load("res://scripts/ui/shop_panel.gd").new()
	panel.shop_id = shop
	root.add_child(panel)
	await settle()
	var title := ""
	for product in economy.stock(shop):
		if str(product.id) == item: title = str(product.name); break
	var pressed := false
	for row in panel.item_list.get_children():
		var labels: Array = row.find_children("*","Label",true,false)
		if labels.any(func(label: Label) -> bool: return label.text.begins_with(title+"  ·")):
			pressed = await text_button(row,"买一个")
			break
	check(pressed,"Shop purchase control works for "+item)
	panel.queue_free()
	await settle()
	for id in economy.state().receipts:
		if not before.has(id): return str(id)
	return ""

func exploration(kind: String, location: String, observation: String) -> void:
	paper.tab = "exploration"; paper.build()
	await settle()
	var places := paper.find_child("ExploreLocation",true,false) as OptionButton
	if places == null: check(false,"Exploration has actual visited-place selector"); return
	var index: int = rs.state().visits.keys().find(location)
	places.select(index); places.item_selected.emit(index)
	await settle()
	var kinds := paper.find_child("ExploreKind",true,false) as OptionButton
	index = ["discover","revisit","shareplace"].find(kind)
	kinds.select(index); kinds.item_selected.emit(index)
	var input := paper.find_child("ExploreObservation",true,false) as TextEdit
	input.text = ""; input.insert_text_at_caret(observation)
	await settle()
	check(await named("CreateExploreRecord"),"Actual explore form submits "+kind)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.gui_disable_input = true
	gs = root.get_node("GameState")
	rs = root.get_node("ResidencySystem")
	economy = root.get_node("EconomySystem")
	router = root.get_node("SceneRouter")
	relationships = root.get_node("RelationshipSystem")
	gs.begin_new_game("A")
	context("print_shop","print_studio",600)
	await open_paper("counter")
	check(await named("CollectStarterPacket"),"Collect the actual six-paper packet")
	check(rs.state().packet and rs.state().pages.size() == 7,"Packet keeps exactly seven separate portfolio pages")
	if not rs.state().packet: quit(1); return
	await open_paper("dossier","requirements")
	for target in ["living_receipts","receipt_categories","exploration","recognition_circles"]:
		paper.tab = "requirements"; paper.build(); await settle()
		check(await named("Requirement_"+target),"Checklist links to usable "+target+" papers")
	# Real store purchase -> one financial transaction -> one physical receipt.
	context("night_market","restaurant",730)
	check(bool(economy.accept_procurement().ok),"Restaurant issues an actual procurement order")
	context("produce_stall","",735)
	var receipt_ids: Array[String] = []
	for item in ["tomato","herbs","sea_beans"]:
		var id: String = await purchase("produce_stall",item)
		check(not id.is_empty(),"Purchased "+item+" has a uniquely sourced receipt")
		if id.is_empty(): quit(1); return
		receipt_ids.append(id)
		check(await file_paper(id),"Receipt is filed with the actual paper control")
	check(int(rs.audit().progress.living_receipts.count) == 3,"Three real purchases count as three filed living receipts")
	check(not rs.audit().requirements.receipt_categories,"Three food receipts cannot satisfy two uses")
	var count_before: int = rs.state().materials.size()
	context("night_market","restaurant",760)
	check(bool(economy.deliver_procurement().ok),"Delivering procurement stamps and reimburses original receipts")
	check(rs.state().materials.size() == count_before,"Reimbursement creates no duplicate paper or wage proof")
	check(bool(rs.state().materials[receipt_ids[0]].reimbursed) and str(rs.state().filing[receipt_ids[0]]) == "day_1","Reimbursement updates the same already-filed paper")
	check(rs.audit().requirements.living_receipts,"Stamped original receipts remain valid living records")
	check(not rs.audit().requirements.income,"Reimbursement is excluded from Income Proof")
	context("cafe","grocery",775)
	var soap_id: String = await purchase("grocery","soap")
	check(not soap_id.is_empty() and await file_paper(soap_id),"A household purchase supplies a distinct use")
	check(rs.audit().requirements.receipt_categories,"Food and household satisfy two real purposes")
	var counterfeit := {"id":"unbacked","kind":"receipt","total":12,"category":"food","valid_for_living_record":true,"source":"missing_transaction"}
	check(not rs.valid_living_receipt(counterfeit,rs.state().ledger),"A receipt without its real ledger transaction is rejected")
	# Writing generic Day 2 answers cannot stand in for visits and observations.
	gs.current_day = 2
	for key in ["discovered","changed","other"]: rs.set_field(2,key,"我在海边写了几句。")
	check(not rs.audit().requirements.exploration,"Portfolio wording alone never grants three exploration records")
	context("port","",660); rs.visit("port")
	await exploration("discover","port","第一次走到码头，栏杆上停了两只海鸥。")
	check(await file_paper("explore_discover"),"Discovery paper can be placed into today's portfolio")
	await exploration("revisit","port","想再看看港口的光。")
	check(not rs.state().materials.has("explore_revisit"),"A single visit cannot manufacture different-time evidence")
	check(gs.use_free_time(60),"Actual free-time clock crosses from morning into afternoon")
	rs.visit("port")
	await exploration("revisit","port","午后同一处栏杆的影子转向岸边。")
	check(await file_paper("explore_revisit"),"A second actual time period supports a revisit paper")
	context("library","library",840); rs.visit("library")
	await exploration("shareplace","library","想带朋友来窗边，一起听书页和海风。")
	check(await file_paper("explore_shareplace"),"The willing-to-share record stays separately identifiable")
	check(rs.audit().requirements.exploration and rs.audit().exploration_kinds.size() == 3,"All three distinct observation types are required and counted")
	var visit_count: int = rs.state().visit_history.library.size()
	rs.visit("library")
	check(rs.state().visit_history.library.size() == visit_count,"Refreshing one time period does not invent a revisit")
	# Create -> actual counter handover -> proof -> explicit filing -> later ripple.
	context("night_market","restaurant",750)
	var modules := root.get_node("GameplayModuleSystem")
	modules.unlock("cooking")
	check(modules.complete("cooking",{"label":"番茄香草小菜"}),"An actual completed module creates a work source")
	root.get_node("EchoSystem").record_module("cooking",{"label":"番茄香草小菜"})
	check(not rs.proof_status("module_cooking_0").accepted,"Creation alone has no acceptance")
	check(not rs.collect_proof("module_cooking_0").contains("已放入"),"Unplaced work cannot get Contribution Proof")
	check(not gs.shared_state.get("world_artifacts",{}).get("contributions",[]).any(func(row: Dictionary) -> bool: return row.get("source_material","") == "module_cooking_0"),"Creation alone leaves no public placement")
	await open_paper("proofs")
	check(await named("PlaceContribution_module_cooking_0"),"Actual kitchen counter accepts the finished dish")
	check(rs.proof_status("module_cooking_0").accepted,"Accepted work records its physical town placement")
	check(await named("CollectProof_module_cooking_0"),"Counter issues the accepted work's actual proof")
	check(not rs.audit().requirements.contribution,"Unfiled proof remains loose until the player chooses")
	check(await file_paper("proof_module_cooking_0","夹入证明"),"Contribution proof files through its paper UI")
	check(rs.audit().requirements.contribution,"Placed work plus collected and filed proof passes contribution")
	var contribution_count: int = gs.shared_state.world_artifacts.contributions.size()
	var balance: int = gs.money
	check(not bool(rs.accept_contribution("module_cooking_0","night_market").ok),"Repeated handover cannot duplicate a world contribution")
	rs.collect_proof("module_cooking_0")
	check(gs.money == balance and gs.shared_state.world_artifacts.contributions.size() == contribution_count,"Repeated proof/handover pays nothing and duplicates nothing")
	gs.earn_money(160,"料理班次工资",{"work_minutes":90,"kind":"income","issuer":"night_market"})
	var wage_id := "wage_"+str(gs.money_ledger.back().transaction_id)
	paper.build(); await settle()
	check(await named("CollectProof_"+wage_id),"A real credited wage can receive its counter proof")
	check(await file_paper("proof_"+wage_id,"夹入证明") and rs.audit().requirements.income,"Only the filed paid-work proof satisfies income")
	context("record_store","record_shop",900)
	modules.unlock("sound_sampling")
	modules.complete("sound_sampling",{"label":"海边采样"})
	check(not bool(rs.accept_contribution("module_sound_sampling_0","record_store").ok),"A sound draft cannot skip the actual record pressing/archive step")
	check(not rs.proof_status("module_sound_sampling_0").accepted,"Unarchived sound remains a created work")
	gs.current_day = 3
	var echoes: Array = root.get_node("EchoSystem").at_location("night_market")
	check(echoes.any(func(row: Dictionary) -> bool: return str(row.get("text","")).contains("下次还有吗")),"A later day exposes the actual contribution's town response")
	# One repeated source cannot be farmed into recognition.
	for _repeat in 4: relationships.record_encounter("recordist","same_conversation",["听完了同一次谈话"])
	check(int(relationships.summary("recordist").encounters) == 1,"Same stable conversation source counts once")
	check(str(relationships.request_confirmation("recordist").get("status","")) == "refused","One encounter still cannot earn recognition")
	var groups: Dictionary = {"food":[],"arts":[],"community":[],"coast":[]}
	for resident in root.get_node("ScheduleSystem").residents:
		var data: Dictionary = root.get_node("ScheduleSystem").residents[resident]
		var circle: String = rs.recognition_circle(str(resident))
		if bool(data.get("draft",false)) and groups.has(circle) and groups[circle].size() < 3: groups[circle].append(str(resident))
	check(groups.values().all(func(ids: Array) -> bool: return ids.size() == 3),"Existing town has twelve ordinary residents across four real circles")
	await open_paper("dossier","recognition")
	var earned: Array[String] = []
	for circle in groups:
		for resident in groups[circle]:
			for visit in 4: relationships.record_encounter(str(resident),"v3_shared_activity_%d" % visit,["不同的共同经历"])
			check(str(relationships.request_confirmation(str(resident)).get("status","")) == "granted","Different shared encounters can earn "+str(resident)+" recognition")
			earned.append(str(resident))
			check(await file_paper("recognition_"+str(resident),"夹入认可"),"Earned signature has a usable physical filing control")
		if earned.size() == 3: check(not rs.audit().requirements.recognition_circles,"Three signatures from one circle cannot satisfy four circles")
	check(rs.audit().requirements.recognition and rs.audit().requirements.recognition_circles,"Twelve earned signatures from four circles satisfy both requirements")
	if earned.is_empty(): quit(1); return
	# Use the real Night Organize drag handlers and persist their placement.
	var mark_id := "recognition_"+earned[0]
	rs.file_material(mark_id,"loose")
	context("residence","home_a",1140)
	await open_paper("organize")
	var target: Control
	for node in paper.find_children("*","Panel",true,false):
		if node.get_script() == load("res://scripts/residency/paper_piece.gd") and str(node.destination) == "recognition": target = node; break
	check(is_instance_valid(target),"Night table has an actual Recognition drop target")
	if is_instance_valid(target):
		var drag := {"residency_material":mark_id}
		check(target._can_drop_data(Vector2.ZERO,drag),"Earned signature can be dragged into the recognition folder")
		target._drop_data(Vector2.ZERO,drag); await settle()
	check(str(rs.state().filing.get(mark_id,"")) == "recognition","Night drag writes the saved paper destination")
	check(root.get_node("SaveManager").save_game(),"All new material metadata and world traces save successfully")
	var materials_count: int = rs.state().materials.size()
	gs.switch_to_role("B",1,true)
	check(not rs.state().packet and rs.state().materials.is_empty(),"B keeps a separate seven-page dossier and materials")
	check(root.get_node("SaveManager").load_game(),"V3 paper state reloads from disk")
	check(rs.state().materials.size() == materials_count,"Reload does not duplicate receipts, signatures, or proofs")
	check(rs.audit().requirements.living_receipts and rs.audit().requirements.exploration and rs.audit().requirements.contribution,"Real receipt, exploration and contribution evidence survives load")
	check(str(rs.state().filing.get(mark_id,"")) == "recognition" and bool(rs.state().materials[receipt_ids[0]].reimbursed),"Drag destination and original receipt reimbursement stamp survive load")
	check(rs.state().pages.size() == 7 and not rs.set_field(8,"today","extra"),"V3 retains a seven-page portfolio with no fabricated eighth day")
	print("V3_RESIDENCY ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)
