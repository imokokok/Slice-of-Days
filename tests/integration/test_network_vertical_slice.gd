extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void: await create_timer(0.85).timeout
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	var chapters = root.get_node("ChapterSystem")
	var router = root.get_node("SceneRouter")
	var travel = root.get_node("TravelSystem")
	var graph = root.get_node("WorldGraph")
	var schedule = root.get_node("ScheduleSystem")
	var dialogue = root.get_node("DialogueSystem")
	chapters.start_new_game()
	check(chapters.chapter_sequence().size() == 7, "Exactly seven days")
	check(chapters.chapter_sequence()[1].role == "B" and chapters.chapter_sequence()[2].role == "B", "Days 2 and 3 must be B")
	check(state.money == 300 and state.role_states.B.money == 160, "Configured separate budgets")
	for location in travel.location_names:
		check(travel._shortest_walk_minutes("town_entrance",location) >= 0, "Every approved location reachable: " + location)
	check(travel.adjacency.town_entrance.size() > 2, "World graph branches")
	change_scene_to_file("res://scenes/town_day.tscn")
	await settle()
	check(current_scene.street.player_x == 150, "A starts at left edge")
	check(current_scene.street_order.size() == 3 and current_scene.street.world_width == 4800 and not current_scene.street_order.has("park"), "Public street remains a three-location branch with full-width illustrated scenes")
	var bus: Dictionary = travel.route("residence","park","bus","A",545)
	var taxi: Dictionary = travel.route("residence","park","taxi","A",545)
	check(bus.available and taxi.available and bus.cost < taxi.cost and bus.minutes > taxi.minutes, "Transit offers real time/money tradeoff")
	check(bus.wait == 10, "Bus waits until next timetable departure")
	check(not travel.route("town_entrance","park","bus","A",545).available, "Bus requires a stop")
	check(not travel.route("residence","park","bus","A",1400).available, "No buses after last departure")
	var money_before: int = state.money
	state.money = 0
	check(not travel.travel("park","taxi").ok and state.current_location == "town_entrance", "Unaffordable travel must not move or charge")
	state.money = money_before
	router.town_map("night_market")
	await settle()
	check(current_scene.selected == "night_market", "Map exposes selected destination quote")
	current_scene._depart("walk")
	await settle()
	check(state.current_location == "night_market" and current_scene.segment_id == "public_west", "Map travel returns to destination stage")
	state.current_minute = 700
	router.enter_space("restaurant")
	await settle()
	current_scene.stage.player_x = current_scene._hotspot_x(0)
	current_scene._select_object(0)
	current_scene._open_selected()
	await process_frame
	check(is_instance_valid(current_scene.conversation),"Kitchen first introduces the shopkeeper commission")
	current_scene.conversation._accept_offer()
	await process_frame
	current_scene._open_selected()
	await settle()
	check(current_scene.module_id == "cooking", "Kitchen enters existing cooking prototype")
	for token in ["lemon","bread","tomato"]: current_scene._toggle_token(token)
	current_scene.value_slider.value = 0.58
	current_scene._perform_primary_action()
	var before_cooking: int = state.current_minute
	current_scene._complete_choice("careful_menu")
	check(current_scene.completed and state.current_minute > before_cooking, "Cooking completes and settles time")
	router.return_from_gameplay()
	await settle()
	check(router.active_space_id == "restaurant" and current_scene.stage != null, "Minigame returns to original interior")
	check(not root.get_node("EchoSystem").at_location("night_market").is_empty(), "Cooking leaves a persistent visible echo")
	router.leave_space()
	await settle()
	router.travel_to("residence","taxi")
	await settle()
	router.enter_space("home_a")
	await settle()
	check(chapters.sleep_at_home(), "Day ends at own bed")
	await create_timer(4.5).timeout
	check(state.current_day == 2 and state.current_role == "B", "Day 1 A sleep must advance to Day 2 B")
	check(not state.shared_state.get("offscreen_B",[]).is_empty(), "B has low-risk traces from the missing day")
	state.current_minute = 540
	state.current_location = "town_entrance"
	dialogue.reply("zhou_xiaoliu","schedule_info")
	dialogue.reply("zhou_xiaoliu","rumor")
	var facts: Array = root.get_node("KnowledgeSystem").facts()
	check(facts.size() == 2 and float(facts[1].confidence) < 0.8, "Useful information and uncertain rumour remain distinct")
	check(schedule.activity_at("zhou_xiaoliu",2,540).location != schedule.activity_at("zhou_xiaoliu",2,850).location, "NPC moves by schedule")
	check(schedule.mood_at("zhou_xiaoliu",2,540) != schedule.mood_at("zhou_xiaoliu",2,700), "Mood changes independently of recognition")
	state.current_location = "town_entrance"
	router.active_space_id = ""
	router.town_day()
	await settle()
	current_scene._talk_nearby("zhou_xiaoliu")
	await process_frame
	current_scene._process(60.0)
	check(not current_scene.street.enabled and state.current_minute == 540, "Reading dialogue pauses world time")
	check(is_instance_valid(current_scene.conversation.text_label), "Shared stage conversation actually renders")
	current_scene.conversation._topics()
	check(current_scene.conversation.options.size() >= 5, "Conversation offers practical questions")
	current_scene.conversation._close()
	await process_frame
	graph.toggle_pin("record_store")
	router.journal()
	await settle()
	check(current_scene._today_text().contains("11:30") and current_scene._today_text().contains("唱片店"), "B Notebook contains learned timetable and pin")
	check(current_scene._today_text().contains("?"), "Notebook retains uncertainty marker")
	var save: Dictionary = state.to_save_data()
	state.begin_new_game()
	state.load_save_data(save)
	check(state.current_role == "B" and state.current_day == 2 and root.get_node("KnowledgeSystem").facts().size() == 2, "New save retains role, day and knowledge")
	check(not root.get_node("EchoSystem").at_location("night_market").is_empty(), "Day 1 echo survives Day 2 reload")
	state.current_location = "record_store"
	state.current_minute = 1200
	router.active_space_id = ""
	router.town_day()
	await settle()
	check(current_scene.street.hotspots.any(func(h: Dictionary) -> bool: return h.kind == "shop_closed"), "Missed shop leaves quiet closure, no failed quest")
	state.current_minute = 1259
	router.travel_to("park","taxi")
	await settle()
	check(current_scene.segment_id == "lookout" and not is_finite(current_scene.street.walk_limit), "Lookout is separate seaside stage open after 21:00")
	state.current_minute = 1200
	current_scene._refresh()
	check(is_finite(current_scene.street.walk_limit), "Lookout gate closed before 21:00")
	state.current_day = 6
	state.current_role = "A"
	state.shared_state.chapter_index = 5
	state.shared_state.sleep_pending = true
	check(not chapters.advance_chapter().get("ok",true), "Final day cannot silently select a role")
	check(chapters.choose_final_role("B"), "Day 7 choice explicitly accepted")
	chapters.advance_chapter()
	check(state.current_day == 7 and state.current_role == "B", "Final day follows chosen role")
	var legacy: Dictionary = state.to_save_data()
	legacy.save_version = 3
	legacy.current_role = "B"
	legacy.role_states.B.day = 1
	legacy.role_states.B.money = 73
	legacy.role_states.B.known_facts = ["旧存档里的私人记录"]
	state.load_save_data(legacy)
	check(state.current_day == 2 and state.current_role == "B" and state.money == 73 and state.known_facts.has("旧存档里的私人记录"), "V3 migration preserves old money and memories while aligning the day")
	var legacy_flat := {
		"save_version": 2,
		"current_role": "A",
		"current_day": 3,
		"current_minute": 735,
		"money": 91,
		"current_location": "cafeteria",
		"completed_events": ["legacy_event"],
		"known_facts": ["真实旧结构里的记录"],
	}
	state.load_save_data(legacy_flat)
	check(state.current_day == 4 and state.current_role == "A", "Flat legacy saves align to the next authored day for their role")
	check(state.current_minute == 735 and state.money == 91 and state.current_location == "night_market", "Flat legacy saves preserve time, money and aliased locations")
	check(state.has_event("legacy_event") and state.known_facts.has("真实旧结构里的记录"), "Flat legacy saves preserve progress and knowledge")
	print("NETWORK VERTICAL SLICE PASS" if failures == 0 else "NETWORK VERTICAL SLICE FAIL: %d" % failures)
	quit(failures)
