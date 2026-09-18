extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func press(town: Node, key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	town._unhandled_input(event)

func walk_to(town: Node, id: String) -> bool:
	for point in town.street.hotspots:
		if str(point.get("id", "")) == id:
			town.street.player_x = float(point.x)
			town.street.velocity = 0
			town.street.move_player(0, 0)
			return true
	return false

func drain(panel: Node) -> void:
	panel.typewriter = false
	var guard := 0
	while is_instance_valid(panel) and not panel.closing and panel.index < panel.lines.size() and guard < 80:
		panel._advance()
		guard += 1

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	root.gui_disable_input = true
	var state = root.get_node("GameState")
	var dialogue = root.get_node("DialogueSystem")
	var save = root.get_node("SaveManager")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location = "produce_stall"
	state.current_minute = 650
	state.shared_state["map_arrival"] = "produce_stall"
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	var town = current_scene
	town.set_process(false)
	town.street.set_process(false)
	town._refresh()
	check(walk_to(town, "beetman"), "The scheduled real vendor has a person hotspot")
	check(not town.street.hotspots.any(func(p: Dictionary) -> bool: return str(p.get("kind", "")) == "shop" and str(p.get("id", "")) == "produce_stall"), "The produce counter cannot bypass conversation")
	var before_minute: int = state.current_minute
	var before_money: int = state.money
	press(town, KEY_E)
	check(is_instance_valid(town.conversation) and town.conversation.npc == "beetman", "Normal E opens BEETMAN conversation")
	check(not is_instance_valid(town.pocket_panel), "E never forces the shop open")
	check(state.current_minute == before_minute + 15 and state.money == before_money, "One chat advances fifteen minutes without payment")
	var first = town.conversation
	check(first.line_ids[0] == "beetman.greeting.0.0", "First vendor line has the stable authored Inner Voice trigger")
	town._talk_nearby("beetman")
	check(state.current_minute == before_minute + 15, "Repeated input while speech is open does not charge again")
	drain(first)
	check(is_instance_valid(first.vendor_choices), "Finishing vendor smalltalk shows optional counter choices")
	first._vendor_action("shop")
	check(is_instance_valid(town.pocket_panel) and first.shopping, "Shop opens as the vendor conversation branch")
	check(state.current_minute == before_minute + 15 and state.money == before_money, "Opening the shop charges neither time nor money")
	var shop = town.pocket_panel
	var can: Dictionary = shop.shop.items.filter(func(i: Dictionary) -> bool: return str(i.id) == "sea_beans")[0].duplicate()
	can["shop_name"] = shop.shop.name
	shop._buy(can)
	shop._buy(can)
	check(state.money == before_money - 15 and int(state.inventory.get("sea_beans", 0)) == 1, "A double click purchases and charges one can")
	check(state.current_minute == before_minute + 15, "Can purchase does not charge another chat or shopping interval")
	shop.queue_free()
	await process_frame
	check(first.visible and not first.shopping and is_instance_valid(first.vendor_choices), "Closing shopping returns to the same conversation")
	first._vendor_action("chat")
	check(first.lines[0] != "别看罐子，先猜里面装什么。", "Next smalltalk rotates to another authored episode")
	check(state.current_minute == before_minute + 30, "Deliberately starting another chat has one chat cost")
	first._close()
	await process_frame
	town._refresh()
	walk_to(town, "beetman")
	press(town, KEY_1)
	var questions: Array = get_nodes_in_group("meta_modal").filter(func(n: Node) -> bool: return n.get_script() == load("res://scripts/meta/ask_panel.gd"))
	check(questions.size() == 1, "Normal 1 opens vendor questions")
	if not questions.is_empty():
		questions[0].chosen.emit("schedule_info")
		questions[0].queue_free()
		await process_frame
		check(is_instance_valid(town.conversation) and town.conversation.starting_topic == "schedule_info", "Questions use the existing NPC dialogue pipeline")
		check(state.current_minute == before_minute + 35, "Asking one question charges five minutes once")
		town.conversation._close()
		await process_frame

	# Walk up to the existing market pair and complete the same memory exchange.
	town._refresh()
	check(walk_to(town, "translation"), "The existing argument remains on the live street")
	press(town, KEY_E)
	check(is_instance_valid(town.conversation), "E starts the original two-person street conversation")
	var experience = town.conversation.get_child(0)
	experience._drain_lines()
	for index in [0,5,1,4,2,3]:
		check(experience._give(index,1-int(experience.MEMORIES[index].side)), "The original shared-memory exchange remains playable: " + str(index))
		experience._drain_lines()
	check(experience.finished, "Full existing argument can finish without choosing a side")
	var finish_minute: int = state.current_minute
	experience._advance_street()
	await process_frame
	await process_frame
	check(state.current_minute == finish_minute + 30, "Finishing the argument charges its time once")
	check(bool(dialogue.argument_state().seen) and bool(dialogue.argument_state().finished), "Seen and finished flags are both recorded")
	check(not town.street.hotspots.any(func(p: Dictionary) -> bool: return p.kind == "argument"), "A completed argument does not restart")
	check(town.street.hotspots.any(func(p: Dictionary) -> bool: return p.kind == "argument_observation"), "Afterward the real scene exposes an observation trigger")
	for person in ["ahe", "chen_chuan"]:
		check(walk_to(town, person), "Each original shopper remains individually reachable: " + person)
		press(town, KEY_E)
		check(is_instance_valid(town.conversation) and town.conversation.npc == person, "E opens an individual post-event dialogue: " + person)
		check(town.conversation.dialogue_id.contains("post_argument"), "Post-event pool is selected: " + person)
		check(not " ".join(town.conversation.lines).contains("争吵"), "Ordinary post-event smalltalk has no task or demand to judge: " + person)
		drain(town.conversation)
		await process_frame
	check(save.save_or_report("NPC patch test save"), "Post-event state saves")
	state.shared_state.clear()
	check(save.load_slot(1), "NPC patch save loads")
	check(bool(dialogue.argument_state().finished), "Finished state survives real Save / Load")
	check(dialogue.linear_conversation("ahe")[0][1].contains("薄荷"), "Post-event chat progress also survives Save / Load")
	var ended: Dictionary = dialogue.argument_state()
	state.current_minute = int(ended.minute) + dialogue.ARGUMENT_LINGER_MINUTES + 1
	check(not dialogue.argument_lingering(), "The immediate chat window has a finite duration")
	state.current_minute = 850
	check(dialogue.people_at("library").has("ahe") and dialogue.people_at("cafe").has("chen_chuan"), "Both shoppers resume separate real schedules")
	check(not dialogue.people_at("produce_stall").has("ahe"), "Schedule departure removes the temporary market presence")
	check(dialogue.linear_conversation("chen_chuan")[0][1].contains("明信片"), "Later encounters retain post-event ordinary conversation")
	print("PATCH NPCS PASS: %d checks" % checks if failures == 0 else "PATCH NPCS FAIL: %d / %d" % [failures, checks])
	quit(failures)
