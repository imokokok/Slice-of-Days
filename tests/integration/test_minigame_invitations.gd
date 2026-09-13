extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location = "produce_stall"
	state.shared_state["map_arrival"] = "produce_stall"
	state.current_minute = 700
	var dialogue = root.get_node("DialogueSystem")
	check(dialogue.notebook_leads().size() == 7,"Notebook leads to each invitation host")
	var panel = load("res://scripts/ui/conversation_panel.gd").new()
	panel.npc = "beetman"
	root.add_child(panel)
	panel.typewriter = false
	check(panel.offer.is_empty(),"Ordinary greeting comes before the invitation")
	for i in range(panel.lines.size()): panel._advance()
	check(panel.offer.get("module","") == "translation","NPC volunteers invitation after chatting without player selecting a task topic")
	check(not dialogue.should_invite("beetman"),"Invitation is remembered so reopening does not nag")
	panel._decline_offer()
	panel._show_topic("greeting")
	for i in range(panel.lines.size()): panel._advance()
	check(panel.offer.is_empty(),"Declined invitation leaves ordinary conversation available")
	panel.queue_free()
	await process_frame
	var hours = dialogue.reply("xanni","schedule_info")
	check(str(hours[0]).begins_with("我") and not str(hours[0]).contains("Xanni"),"Xanni uses first person for her own hours")
	for person in dialogue.content:
		var first = dialogue.reply(person,"small_talk")
		var second = dialogue.reply(person,"small_talk")
		check(first.size() >= 3 and first != second,"Residents have varied multi-line conversations: " + str(person))
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.7).timeout
	var town = current_scene
	check(not town.street.hotspots.any(func(h: Dictionary) -> bool: return str(h.kind) == "module" and str(h.id) == "translation"),"Produce stall must not directly launch misunderstanding")
	var trigger: Dictionary = {}
	for h in town.street.hotspots:
		if h.kind == "invitation": trigger = h; break
	check(not trigger.is_empty(),"Produce stall provides a conversation invitation hotspot")
	if trigger.is_empty():
		quit(1)
		return
	town.street.player_x = float(trigger.x)
	town._interact()
	await process_frame
	check(town.conversation.npc == "beetman" and town.conversation.lines.size() >= 3,"BEETMAN explains the misunderstanding before entry")
	var minute: int = state.current_minute
	town.conversation._decline_offer()
	check(root.get_node("GameplayModuleSystem").pending_module_id().is_empty() and state.current_minute == minute,"Declining must neither launch nor charge")
	town.conversation._show_topic("minigame_hook")
	town.conversation.typewriter = false
	for i in range(town.conversation.lines.size()): town.conversation._advance()
	check(town.conversation.options.size() == 2,"Invitation presents accept and decline after reading")
	town.conversation._accept_offer()
	await create_timer(0.8).timeout
	check(current_scene.module_id == "translation","Accepting produce-stall dialogue starts misunderstanding")
	check(dialogue.notebook_leads().any(func(n: Dictionary) -> bool: return n.place == "produce_stall" and n.heading == "答应的事"),"Accepted invitation updates notebook direction")
	check(str(state.shared_state.pending_module.source_event_id).begins_with("street:produce_stall:invitation:"),"Invitation preserves street source for correct cost and return")
	current_scene._cancel()
	await create_timer(0.8).timeout
	check(state.current_location == "produce_stall" and current_scene.scene_file_path.ends_with("town_day.tscn"),"Leaving returns to produce stall")
	state.current_location = "night_market"
	check(root.get_node("DialogueSystem").invitation_for("beetman").is_empty(),"Misunderstanding offer must not appear away from produce stall")
	print("MINIGAME INVITATION PASS" if failures == 0 else "MINIGAME INVITATION FAIL")
	quit(failures)
