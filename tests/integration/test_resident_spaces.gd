extends SceneTree
## Player-facing regression for room/street clones, plus exhaustive staging data checks.
var checks := 0
var failures := 0
var gs
var router
var dialogue
var schedule

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
	else: print("PASS ",message)
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
func key(code: int) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event); await process_frame
	event.pressed=false; root.push_input(event); await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/resident-spaces")
	root.get_texture().get_image().save_png("res://.runtime/resident-spaces/"+id+".png")
func walk(stage: Node, x: float) -> void:
	stage.enabled=true
	var count:=0
	while absf(stage.player_x-x)>22 and count<1500:
		stage.move_player(signf(x-stage.player_x),.04)
		await process_frame
		count+=1
	stage.velocity=0
	check(count<1500,"walk reaches its physical target")
func travel(place: String) -> void:
	var result: Dictionary=root.get_node("TravelSystem").travel(place,"walk")
	check(bool(result.get("ok",false)),"real travel to "+place)
	gs.shared_state.map_arrival=place; router.town_day(.01); await settle()
	current_scene.set_process(false); current_scene.street.set_process(false)
func enter(id: String) -> void:
	var doors: Array=current_scene.street.hotspots.filter(func(h):return str(h.get("kind",""))=="door" and str(h.get("id",""))==id)
	check(doors.size()==1,"one physical doorway for "+id)
	if doors.is_empty(): return
	await walk(current_scene.street,float(doors[0].x)); await key(KEY_E)
	check(router.active_space_id==id,"E enters "+id)
	current_scene.set_process(false); current_scene.stage.set_process(false)
func leave() -> void:
	await walk(current_scene.stage,90); await key(KEY_E)
	check(router.active_space_id.is_empty(),"E exits through the room door")
	current_scene.set_process(false); current_scene.street.set_process(false)
func visible_ids(stage: Node) -> Array:
	return stage.presented_residents().map(func(h):return str(h.id))
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter"); dialogue=root.get_node("DialogueSystem"); schedule=root.get_node("ScheduleSystem")
	change_scene_to_file("res://scenes/main_menu.tscn"); await create_timer(.3).timeout
	var new_game: Button=current_scene.find_child("NewGame",true,false)
	check(new_game!=null and not new_game.disabled,"New Game is a real enabled menu entry")
	var entered_at := Time.get_ticks_msec()
	new_game.pressed.emit()
	while current_scene==null or current_scene.scene_file_path!=router.TOWN_DAY: await process_frame
	await settle()
	check(Time.get_ticks_msec()-entered_at<5000,"New Game enters town directly without the opening movie")
	check(gs.current_day==1 and gs.current_role=="A","ordinary New Game starts Day 1 A")
	# Advance the production clock to the first opening, without granting events or moving an NPC.
	while gs.current_minute<540: gs.advance_world_clock(gs.REAL_SECONDS_PER_GAME_MINUTE)
	await travel("cafe")
	check(visible_ids(current_scene.street).has("mossner"),"Mossner is outside the grocery in his morning slot")
	var outside: Dictionary=dialogue.resident_placement("mossner")
	await capture("grocery-outside")
	await enter("grocery")
	check(not visible_ids(current_scene.stage).has("mossner"),"entering grocery cannot carry the outside resident inside")
	var minute_before: int=gs.current_minute
	current_scene._start_conversation("mossner")
	check(not is_instance_valid(current_scene.conversation) and gs.current_minute==minute_before,"an absent NPC cannot talk through a wall or charge time")
	await capture("grocery-inside")
	await leave()
	check(dialogue.resident_placement("mossner")==outside,"outside slot survives an in/out cycle")
	await travel("record_store")
	check(not visible_ids(current_scene.street).has("xanni"),"the indoor host is not duplicated on the connected street")
	await capture("records-outside")
	await enter("record_shop")
	check(visible_ids(current_scene.stage).count("xanni")==1,"one Xanni appears at the fixed workbench slot")
	var slot: float=dialogue.resident_placement("xanni").x
	await walk(current_scene.stage,slot-60)
	await key(KEY_W)
	check(is_instance_valid(current_scene.conversation),"W beside the actual indoor person opens conversation")
	await capture("records-conversation")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(current_scene.conversation),"closing conversation returns to the same room")
	await leave(); await enter("record_shop")
	check(visible_ids(current_scene.stage).count("xanni")==1 and is_equal_approx(float(dialogue.resident_placement("xanni").x),slot),"re-entering keeps one person at the same coordinate")
	await capture("records-return")
	check(root.get_node("SaveManager").save_or_report("Resident placement regression"),"real save succeeds")
	check(root.get_node("SaveManager").load_slot(root.get_node("SaveManager").active_slot),"real save reload succeeds")
	current_scene._refresh_people()
	check(is_equal_approx(float(dialogue.resident_placement("xanni").x),slot),"save reload does not move the resident")
	# Data fixtures below are explicitly separate from the player-entry checks above.
	var snapshot: Dictionary=gs.to_save_data().duplicate(true)
	var rooms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/world/interactive_spaces.json")).spaces
	for npc in schedule.residents:
		for activity in schedule.residents[npc].schedule:
			var placement: Dictionary=schedule.staging_for(npc,activity)
			check(not placement.is_empty(),"authored activity has a fixed slot: "+str(activity.id))
			if not str(placement.get("space","")).is_empty():
				check(rooms.any(func(r):return str(r.id)==str(placement.space) and str(r.location_id)==str(placement.location)),"room belongs to the scheduled location")
	for day in range(1,6):
		gs.current_day=day
		for minute in [550,700,850,1090,1150,1210,1330]:
			gs.current_minute=minute
			var seen: Array=[]
			for place in schedule.staging.locations:
				var ids: Array=dialogue.people_at(place,"")
				for room in rooms:
					if str(room.location_id)==str(place): ids.append_array(dialogue.people_at(place,str(room.id)))
				seen.append_array(ids)
			var unique: Dictionary={}
			for npc in seen: unique[npc]=true
			check(seen.size()==unique.size(),"one world appearance per resident on day %d at %d"%[day,minute])
	gs.current_day=2; gs.current_minute=850
	var maya_slot: Dictionary=dialogue.resident_placement("maya")
	gs.current_minute=950
	check(dialogue.resident_placement("maya").x==maya_slot.x,"Maya stays put when another reader arrives")
	gs.current_day=1; gs.current_minute=1210
	check(dialogue.people_at("record_store","").has("xanni") and not dialogue.people_at("record_store","record_shop").has("xanni"),"authored late visit stays outside the closed shop")
	gs.load_save_data(snapshot)
	print("RESIDENT_SPACES: ",checks," checks / ",failures," failures")
	quit(failures)
