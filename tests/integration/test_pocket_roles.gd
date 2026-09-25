extends SceneTree
var gs
var router
var life
var characters
var agenda
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS ",message)
	else: failures+=1; push_error(message)
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
	if is_instance_valid(current_scene): current_scene.set_process(false)
func close_paper(shell: Node) -> void:
	if is_instance_valid(shell.overlay): shell.overlay.close()
	await process_frame
func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://.runtime/pocket-role-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(file+".png"))==OK,"capture "+file)
func key(shell: Node, action: String) -> void:
	var event := InputEventAction.new(); event.action=action; event.pressed=true
	shell._handle_shortcut(event)
func has_text(node: Node, phrase: String) -> bool:
	if node is Label or node is Button:
		if str(node.text).contains(phrase): return true
	for child in node.get_children():
		if has_text(child,phrase): return true
	return false

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter"); life=root.get_node("LifeSystem"); characters=root.get_node("CharacterSystem"); agenda=load("res://scripts/core/daily_agenda.gd")
	root.get_node("CoreLoopSystem").set_process(false); root.get_node("ChapterSystem").set_process(false)
	root.get_node("ChapterSystem").start_new_game(); gs.current_location="residence"
	router.town_day(.01); await settle()
	var shell=current_scene.get_node("GameplayShell")
	check(shell.get_node("Pocket_recorder").visible and not shell.get_node("Pocket_notebook").visible,"A carries only recorder, not notebook")
	check(shell.pocket_objects.filter(func(item: Button): return item.visible).size()==5,"A has five contiguous pocket icons")
	key(shell,"open_notebook"); check(not is_instance_valid(shell.overlay),"A notebook shortcut cannot bypass ownership")
	router.journal(); check(not is_instance_valid(shell.overlay),"legacy journal route cannot open notebook for A")
	await capture("a-pocket")
	key(shell,"open_recorder"); await process_frame
	check(is_instance_valid(shell.tool) and shell.tool.is_in_group("mobile_recorder"),"A recorder shortcut opens real field recorder")
	check(shell.tool.live_screen!=null,"recorder retains live scene screen")
	await capture("a-recorder")
	shell.tool.queue_free(); await process_frame
	shell.open_paper("dossier"); await process_frame
	check(shell.overlay.find_child("ObjectTab_notebook",true,false)==null and not has_text(shell.overlay,"随身本"),"A archive contains no notebook tab or label")
	shell.overlay._guidance_action({"action":"heard"}); check(shell.overlay.mode=="leads","A can still track heard clues without a notebook")
	await close_paper(shell)
	gs.switch_to_role("B",2,true); gs.current_location="residence"; gs.current_minute=480
	router.town_day(.01); await settle(); shell=current_scene.get_node("GameplayShell")
	check(shell.get_node("Pocket_notebook").visible and not shell.get_node("Pocket_recorder").visible,"B carries notebook, not recorder")
	await capture("b-pocket")
	key(shell,"open_recorder"); check(not is_instance_valid(shell.tool),"B recorder hotkey cannot bypass ownership")
	shell.open_tool("recorder"); check(not is_instance_valid(shell.tool),"direct tool request cannot give recorder to B")
	shell.open_paper("sound_library"); await process_frame
	check(not has_text(shell.overlay,"新录音"),"B sound collection contains no recorder action")
	shell.overlay._home_action("recorder"); await process_frame
	check(not is_instance_valid(shell.tool) and is_instance_valid(shell.overlay),"secondary recorder action also respects ownership")
	await close_paper(shell)
	key(shell,"open_notebook"); await process_frame
	check(shell.overlay.notebook_section=="schedule" and shell.overlay.find_child("NotebookAgenda",true,false)!=null,"B notebook opens directly on today's agenda")
	check(has_text(shell.overlay,"14:00—18:00") and has_text(shell.overlay,"地点：饭店"),"agenda shows actual shift time and workplace")
	check(has_text(shell.overlay,"23:59") and has_text(shell.overlay,"00:00"),"agenda explicitly shows home deadline and midnight")
	var before_minute: int=gs.current_minute
	var preview: Dictionary=agenda.next_row()
	check(preview.id=="d2_b_restaurant_service" and gs.current_minute==before_minute,"reading agenda has no time or completion side effects")
	await close_paper(shell)
	check(life.add_plan("rest",540,"walk").ok,"B can reserve a real morning home activity")
	var plan_id: String=life.state().plans[-1].id
	gs.add_appointment({"id":"pocket_appointment","day":2,"start":600,"end":630,"label":"和居民在海边见面","location":"seafront"})
	gs.add_appointment({"id":"other_day","day":4,"start":600,"end":630,"label":"未来的约定","location":"seafront"})
	check(agenda.next_row().id==plan_id,"next activity follows chronology, not fixed-job priority")
	check(not agenda.rows().any(func(row: Dictionary): return str(row.id)=="other_day"),"today agenda excludes other days")
	check(agenda.free_windows()==[[480,540],[570,600],[630,840],[1080,1439]],"available windows subtract both plan and appointment")
	key(shell,"open_notebook"); await process_frame
	check(has_text(shell.overlay,"09:00—09:30") and has_text(shell.overlay,"回家歇一会儿"),"added plan is immediately visible in B notebook")
	check(not has_text(shell.overlay,"scheduled"),"raw appointment status is never displayed")
	await capture("b-agenda")
	shell.overlay.find_child("AgendaRoute",true,false).pressed.emit(); await process_frame
	check(shell.overlay.mode=="map" and shell.overlay.map_selected=="residence","agenda location button selects real destination on map")
	await close_paper(shell)
	check(life.cancel_plan(plan_id).ok,"plan cancellation uses real persistence")
	check(agenda.rows().any(func(row: Dictionary): return str(row.id)==plan_id and row.status=="cancelled"),"cancelled intent remains marked cancelled, not complete")
	check(agenda.free_windows()==[[480,600],[630,840],[1080,1439]],"cancelled intent releases its free window")
	check(life.add_plan("quiet",480,"walk").ok,"reserve immediate home activity")
	router.active_space_id="home_b"
	check(life.everyday("quiet").ok,"actual timed home activity executes")
	check(agenda.rows().any(func(row: Dictionary): return row.title=="安静整理今天的思绪" and row.status=="done"),"agenda completion reflects actual activity")
	router.active_space_id=""
	gs.spend_time(640-gs.current_minute)
	check(agenda.rows().any(func(row: Dictionary): return row.id=="pocket_appointment" and row.status=="missed"),"missed real appointment is not called complete")
	check(root.get_node("SaveManager").save_game() and root.get_node("SaveManager").load_game(),"role-specific plans persist through save reload")
	gs.switch_to_role("A",3,true)
	check(not life.state().plans.any(func(row: Dictionary): return str(row.id)==plan_id),"B plans do not leak into A")
	gs.switch_to_role("B",4,true); gs.current_minute=480
	root.get_node("RelationshipSystem").add_flags("shi_yongqi",["completed_shift"])
	check(life.adjust_shift("swap").ok,"can swap an actual future shift")
	gs.switch_to_role("B",5,true)
	check(agenda.rows().any(func(row: Dictionary): return int(row.start)==540 and row.place=="饭店"),"agenda derives swapped 09:00 shift from live calendar")
	gs.shared_state.character_switch_enabled=true; root.get_node("ChapterSystem").story().reveal_completed=true
	gs.current_location="residence"; router.town_day(.01); await settle(); shell=current_scene.get_node("GameplayShell")
	key(shell,"open_notebook"); await process_frame
	shell.overlay.find_child("AgendaEdit",true,false).pressed.emit(); await process_frame
	var choose=shell.overlay.find_child("Choose_A",true,false)
	check(choose!=null,"B schedule exposes unlocked fifth-day role switch")
	if choose!=null: choose.pressed.emit()
	await process_frame; await process_frame
	check(gs.current_role=="A" and shell.overlay.mode=="day_schedule","switching B to A immediately retires B's notebook")
	check(not has_text(shell.overlay,"随身本"),"A planner has no notebook label after switching")
	await close_paper(shell); await process_frame
	check(shell.get_node("Pocket_recorder").visible and not shell.get_node("Pocket_notebook").visible,"same HUD updates ownership after role switch")
	# Leave a readable B agenda available for a native-window inspection.
	gs.switch_to_role("B",2,true); gs.current_minute=480; gs.current_location="residence"; router.town_day(.01); await settle()
	shell=current_scene.get_node("GameplayShell"); key(shell,"open_notebook"); await process_frame
	print("POCKET_ROLES: ",checks," checks / ",failures," failures")
	if failures==0 and OS.get_cmdline_user_args().has("--keep-open"):
		DisplayServer.window_set_title("Solmere · A/B 随身物品"); current_scene.set_process(true); return
	quit(failures)
