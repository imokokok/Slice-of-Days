extends SceneTree
var checks := 0
var failures := 0
var gs: Node
var router: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func settle() -> void:
	await create_timer(.35).timeout
	while router.transitioning: await process_frame
	await process_frame
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.gui_disable_input=true
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter")
	var chapter=root.get_node("ChapterSystem")
	var graph=root.get_node("WorldGraph")
	var save=root.get_node("SaveManager"); save.active_slot=2
	chapter.start_new_game()
	for place in graph.config.business_hours:
		var hours: Array=graph.config.business_hours[place]
		check(not graph.location_status(place,int(hours[0])-1).open,place+" closes before opening")
		check(graph.location_status(place,int(hours[0])).open,place+" opens exactly on time")
		check(not graph.location_status(place,int(hours[1])).open,place+" closes exactly on time")
	var guidance=root.get_node("GuidanceSystem")
	gs.current_minute=490
	for level in range(4):
		guidance.help_level=level
		check(str(guidance.next_step().context).contains("营业时间"),"Idle help preserves the closed shop's opening hours at level "+str(level))
	guidance.help_level=0
	gs.current_minute=1260
	check(not root.get_node("GameplayModuleSystem").entry_check("sound_sampling").ok,"Closed record shop cannot start music")
	check(root.get_node("GuidanceSystem").next_step().location!="record_store","Night guidance never sends player to closed record shop")
	gs.current_minute=1350
	check(root.get_node("GuidanceSystem").next_step().location==root.get_node("CoreLoopSystem").home(),"Late guidance points home")
	gs.current_minute=660
	for location in ["bus_stop","record_store","residence","park"]:
		gs.current_location=location; router.town_day(); await settle()
		var street=current_scene.street
		var signs: Array=street.hotspots.filter(func(h): return h.kind=="transport")
		check(signs.size()==(3 if street.world_width>=6400 else 2),location+" has only two or three signs across entire road")
		check(signs[0].x==110 and signs[-1].x==street.world_width-110,location+" has both end signs")
		street.player_x=110
		check(street.nearest_interactable().kind=="transport",location+" end sign can be used")
	gs.current_location="cafe"; router.town_day(); await settle()
	var street=current_scene.street
	check(not street.hotspots.any(func(h): return h.kind=="door" and h.id=="grocery"),"Grocery remains an outdoor counter without an invented interior")
	gs.current_location="record_store"; router.town_day(); await settle(); street=current_scene.street
	var doors: Array=street.hotspots.filter(func(h): return h.kind=="door")
	check(not doors.is_empty(),"Record shop has a physical doorway")
	if not doors.is_empty():
		var door: Dictionary=doors[0]
		street.hotspots.clear(); street.hotspots.append(door); street.hotspots.append({"kind":"person","id":"wu_wu","x":door.x+70})
		street.player_x=door.x+70
		check(street.nearest_interactable().kind=="door","Nearby NPC cannot intercept doorway interaction")
		street.player_x=door.x+street.DOOR_REACH+2
		check(street.nearest_interactable().is_empty(),"Door remains unavailable beyond reach")
		street.player_x=door.x-70
		current_scene._interact(); await settle()
		check(current_scene.scene_file_path==router.INTERACTIVE_SPACE,"Offset within doorway reach really enters the room")
	var card=load("res://scripts/ui/components/dialogue_card.gd").new(); current_scene.add_child(card)
	card.speaker_label.text="居民"; card.text_label.text="你好。"; card.layout()
	var box: Rect2=card.get_global_rect()
	card.text_label.text="你慢慢看。想买些什么、冲洗照片，或者聊一聊今天路上遇到的事情，都可以。"; card.layout()
	check(card.get_global_rect()==box,"Short and long speech retain identical position and dimensions")
	check(card.text_label.get_minimum_size().y<=card.text_label.size.y,"Long wrapped dialogue fits reserved reading area")
	card.queue_free()
	var direction=load("res://scripts/ui/components/direction_card.gd").new(); current_scene.add_child(direction)
	direction.present(root.get_node("GuidanceSystem").next_step())
	check(direction.size.x<=320 and direction.size.y<=144,"Guidance keeps compact fixed dimensions")
	direction.queue_free()
	var sky=load("res://scripts/ui/coast_backdrop.gd")
	check(sky.weights(720)==Vector3(1,0,0) and sky.weights(1110)==Vector3(0,1,0) and sky.weights(1320)==Vector3(0,0,1),"Day, dusk and night use distinct actual plates")
	for minute in range(0,1440,15):
		var weights: Vector3=sky.weights(minute)
		check(is_equal_approx(weights.x+weights.y+weights.z,1),"Sky blends conserve brightness at "+str(minute))
	chapter.start_new_game(); gs.current_location="bus_stop"; router.town_day(); await settle()
	gs.current_minute=1438; gs.clock_remainder=0
	gs.add_journal_entry({"kind":"note","text":"午夜前写下的句子"})
	gs.advance_world_clock(4.0)
	check(gs.current_minute==1439,"23:58 advances to 23:59, never skips home deadline")
	await create_timer(1).timeout; await settle()
	check(gs.current_location=="residence" and router.active_space_id=="home_a","23:59 returns the active character to their real home")
	gs.current_minute=1439; gs.clock_remainder=0
	gs.advance_world_clock(4.0)
	check(gs.current_minute==1440,"The next minute is exactly midnight")
	await create_timer(4).timeout; await settle()
	check(gs.current_day==2 and gs.current_role=="B","Midnight transitions directly from Day 1 A to Day 2 B")
	check(chapter.day_state(1).get("ended_at_midnight",false) and not chapter.day_state(1).main_completed,"Deadline does not fabricate unfinished main activity completion")
	check(save.save_game("user://night_interaction_roundtrip.json"),"Midnight result persists")
	chapter.start_new_game()
	check(save.load_game("user://night_interaction_roundtrip.json") and gs.current_day==2 and gs.current_role=="B","Reload restores the new day and correct private role")
	print("NIGHT_INTERACTION: ",checks," checks / ",failures," failures")
	quit(failures)
