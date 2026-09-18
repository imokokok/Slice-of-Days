extends SceneTree
## Uses the production new-game callback, map controls, E/F/H input handlers,
## paper controls and disk saves. No residency state is injected for the smoke journey.
var failures := 0
var checks := 0
var gs: Node
var rs: Node
var router: Node
var save: Node

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS ",title)
	else: failures += 1; push_error(title)

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func click_named(parent: Node, target: String) -> bool:
	var button := parent.find_child(target,true,false) as Button
	if not is_instance_valid(button) or button.disabled: return false
	button.pressed.emit()
	await process_frame
	await process_frame
	return true

func click_text(parent: Node, target: String) -> bool:
	for candidate in parent.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.text != target or button.disabled: continue
		button.pressed.emit()
		await process_frame
		await process_frame
		return true
	return false

func close_paper(shell: Node) -> void:
	if is_instance_valid(shell.overlay): shell.overlay._input(key(KEY_ESCAPE))
	await create_timer(.12).timeout

func travel(destination: String, method: String) -> bool:
	var shell = current_scene.get_node("GameplayShell")
	shell._unhandled_input(key(KEY_TAB))
	await create_timer(.1).timeout
	if not is_instance_valid(shell.overlay): return false
	shell.overlay._map_select(destination)
	var clicked: bool = await click_named(shell.overlay,"TravelWalk" if method == "walk" else "TravelTaxi")
	await create_timer(.85).timeout
	return clicked and gs.current_location == destination

func walk_to(stage: Control, target: float) -> void:
	# The same movement kernel used by A/D, also available in headless regression runs.
	stage.enabled = true
	for _step in 1200:
		if absf(stage.player_x-target) < 8: break
		stage.move_player(signf(target-stage.player_x),1.0/60.0)
	stage.velocity = 0
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/patch_"+name+".png")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	# UI-copy assertions are intentionally checked against the Chinese source locale.
	TranslationServer.set_locale("zh_CN")
	root.gui_disable_input = true
	gs = root.get_node("GameState")
	rs = root.get_node("ResidencySystem")
	router = root.get_node("SceneRouter")
	save = root.get_node("SaveManager")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(.35).timeout
	current_scene._on_new_game_pressed()
	await create_timer(1.75).timeout
	check(gs.current_day == 1 and gs.current_role == "A","Production new-game flow starts A on Day 1")
	check(current_scene.has_node("GameplayShell"),"Normal town scene has the residency entry")
	check(not rs.state().packet,"New journey does not grant an invisible starter packet")
	check(await travel("print_shop","walk"),"Reach community centre through the actual map walk button")
	var door: Dictionary = {}
	for hotspot in current_scene.street.hotspots:
		if str(hotspot.get("kind","")) == "door" and str(hotspot.get("id","")) == "print_studio": door = hotspot; break
	check(not door.is_empty(),"Community centre has a normal enterable door")
	if door.is_empty(): quit(1); return
	await walk_to(current_scene.street,float(door.x))
	current_scene._unhandled_input(key(KEY_E))
	await create_timer(.85).timeout
	check(router.active_space_id == "print_studio","E at the door enters the community interior")
	if router.active_space_id != "print_studio": quit(1); return
	await walk_to(current_scene.stage,450)
	var shell = current_scene.get_node("GameplayShell")
	shell._unhandled_input(key(KEY_E))
	await create_timer(.12).timeout
	check(is_instance_valid(shell.overlay) and shell.overlay.mode == "counter","E at the real counter opens packet collection")
	if not is_instance_valid(shell.overlay): quit(1); return
	if int(gs.current_minute) < 540:
		var before_wait: int = gs.current_minute
		check(await click_named(shell.overlay,"WaitForCommunityCounter"),"Morning arrival can wait at the actual counter until opening")
		check(int(gs.current_minute) >= 540 and int(gs.current_minute) > before_wait,"Waiting advances real game time to the 09:00 opening")
	check(await click_named(shell.overlay,"CollectStarterPacket"),"Counter's collect control is usable")
	check(rs.state().packet,"Collect button changes the saved packet state")
	if not rs.state().packet:
		push_error("Packet collection failed at %s, location=%s, room=%s: %s" % [gs.clock_text(),gs.current_location,router.active_space_id,shell.overlay.feedback.text])
		quit(1); return
	check(rs.state().materials.values().filter(func(item: Dictionary) -> bool: return item.kind == "official").size() == 6,"Packet contains exactly six independent official documents")
	check(shell.overlay.mode == "dossier" and shell.overlay.tab == "starter","First collection lays out the six-paper folio")
	check(shell.overlay.find_children("Starter_*","Button",true,false).size() == 6,"First collection exposes all six starter papers as real controls")
	await shot("starter_packet")
	await close_paper(shell)
	shell._unhandled_input(key(KEY_F))
	await create_timer(.1).timeout
	check(is_instance_valid(shell.overlay) and shell.overlay.tab == "days" and shell.overlay.show_dossier_reference,"F opens the received seven-day folio through production input")
	check(await click_text(shell.overlay,"返回档案首页"),"The illustrated folio returns to the interactive dossier home")
	check(shell.overlay.tab == "packet" and not shell.overlay.show_dossier_reference,"The illustrated folio returns to the dossier home")
	check(await click_named(shell.overlay,"DossierTab_packet"),"Dossier home reopens the received starter packet")
	check(shell.overlay.tab == "starter","The received starter papers remain reachable after closing the dossier")
	for id in ["welcome","seven_days","requirements","portfolio","folder","map"]:
		var folio = shell.overlay
		folio.mode = "dossier"; folio.tab = "starter"; folio.show_dossier_reference = false; folio.build()
		await process_frame
		var opened: bool = await click_named(folio,"Starter_"+id)
		check(opened,"Open independent starter paper "+id)
		if not opened: quit(1); return
		var expected := {"welcome":"document","seven_days":"document","requirements":"requirements","portfolio":"days","folder":"cover"}
		check(folio.mode == "map" if id == "map" else folio.tab == expected[id],"Starter document has its real function: "+id)
		if id == "portfolio":
			for d in range(1,8):
				check(await click_named(folio,"PortfolioDay_%d" % d),"Portfolio turns to page %d / 7" % d)
				check(folio.day == d,"Page index stays within the seven-page book")
			var future_fields: Array = folio.body.find_children("*","TextEdit",true,false)
			check(not future_fields.is_empty(),"The last portfolio page contains its actual form controls")
			if future_fields.is_empty(): quit(1); return
			check(not (future_fields[0] as TextEdit).editable,"Future page can be read and waits for its day to be written")
	var folio = shell.overlay
	folio.mode = "dossier"; folio.tab = "requirements"; folio.build()
	await process_frame
	check(int(rs.audit().progress.pages.count) == 0,"Requirements initially reads zero completed pages")
	check(await click_named(folio,"Requirement_pages"),"Requirements links into the actual portfolio")
	var inputs: Array = folio.body.find_children("*","TextEdit",true,false)
	check(inputs.size() >= 2,"Day one exposes TODAY and RECORD inputs")
	if inputs.size() < 2: quit(1); return
	(inputs[0] as TextEdit).insert_text_at_caret("今天领到了资料袋。")
	(inputs[1] as TextEdit).insert_text_at_caret("从车站走到社区中心，海风一直跟着。")
	await process_frame
	check(str(rs.state().pages[0].today).contains("资料袋"),"Writing the day sheet changes the live portfolio")
	await click_named(folio,"DossierTab_requirements")
	await process_frame
	check(int(rs.audit().progress.pages.count) == 1,"Dynamic requirements shows the real 1 / 7 progress")
	await shot("requirements")
	await close_paper(shell)
	# A taxi creates a genuine transaction and receipt, through the same MapUI.
	check(await travel("residence","taxi"),"Actual return taxi creates a fare transaction")
	var receipts: Array = rs.state().materials.values().filter(func(item: Dictionary) -> bool: return item.kind in ["receipt","ticket"])
	check(not receipts.is_empty(),"A real travel receipt enters loose papers")
	shell = current_scene.get_node("GameplayShell")
	shell._unhandled_input(key(KEY_F))
	await create_timer(.1).timeout
	check(await click_text(shell.overlay,"打开可编辑档案"),"Illustrated folio opens the interactive filing tabs")
	check(await click_named(shell.overlay,"DossierTab_loose"),"Loose-papers tab opens")
	var receipt_buttons: Array = shell.overlay.body.find_children("*","Button",true,false)
	check(receipt_buttons.any(func(b: Button) -> bool: return b.text.contains("交通") or b.text.contains("打车") or b.text.contains("出租")),"Unfiled receipt is visible in the actual dossier")
	await close_paper(shell)
	check(save.save_game(),"Journey and portfolio save to disk")
	var count: int = rs.state().materials.size()
	var snapshot: Dictionary = gs.to_save_data().duplicate(true)
	gs.switch_to_role("B",1,true)
	check(not rs.state().packet and str(rs.state().pages[0].today).is_empty(),"B owns an independent packet and seven pages")
	check(save.load_game(),"Disk save reload succeeds")
	check(rs.state().packet and str(rs.state().pages[0].today).contains("资料袋"),"Load restores the received packet and written page")
	check(rs.state().materials.size() == count,"Load preserves every receipt without duplicating papers")
	check(await travel("print_shop","walk"),"Return to community after load")
	door = {}
	for hotspot in current_scene.street.hotspots:
		if str(hotspot.get("kind","")) == "door" and str(hotspot.get("id","")) == "print_studio": door = hotspot; break
	if not door.is_empty():
		await walk_to(current_scene.street,float(door.x))
		current_scene._unhandled_input(key(KEY_E))
		await create_timer(.85).timeout
		await walk_to(current_scene.stage,450)
		shell = current_scene.get_node("GameplayShell")
		shell._unhandled_input(key(KEY_E))
		await create_timer(.1).timeout
		await click_named(shell.overlay,"CollectStarterPacket")
		check(rs.state().materials.values().filter(func(item: Dictionary) -> bool: return item.kind == "official").size() == 6,"Revisiting counter after load does not issue a second set")
		await close_paper(shell)
	# Additional physical-paper regression uses the real earned-recognition event.
	gs.load_save_data(snapshot)
	root.get_node("RelationshipSystem").set_confirmation("xanni","granted")
	check(rs.state().materials.has("recognition_xanni"),"Actual recognition signal creates a draggable signed paper")
	check(rs.file_material("recognition_xanni","recognition"),"Recognition paper files into its dedicated section")
	check(int(rs.audit().progress.recognition.count) == 1,"Recognition checklist counts actual filed, earned marks")
	check(rs.file_material("recognition_xanni","day_1"),"Recognition paper can move into an actual day page")
	check(rs.state().pages[0].marks.has("xanni") and int(rs.audit().progress.recognition.count) == 1,"Moving a signed paper never duplicates recognition credit")
	check(not rs.file_material("starter_welcome","personal"),"Official documents stay separate from the seven portfolio pages")
	print("PATCH_RESIDENCY ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)
