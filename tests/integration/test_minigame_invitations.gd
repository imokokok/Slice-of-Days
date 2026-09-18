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
	state.current_location = "record_store"
	state.current_minute = 700
	var dialogue = root.get_node("DialogueSystem")
	check(dialogue.notebook_leads().size() == 7,"Notebook leads to each invitation host")
	var panel = load("res://scripts/ui/conversation_panel.gd").new()
	panel.npc = "xanni"
	root.add_child(panel)
	panel.typewriter = false
	check(panel.lines[0].contains("咳嗽"),"Ordinary character conversation comes before the invitation")
	check(panel.offer.get("module","") == "sound_sampling","Invitation is woven into the forward-moving dialogue")
	panel._close()
	await process_frame
	check(not dialogue.invitation_accepted("sound_sampling"),"Leaving mid-conversation does not accept an unread invitation")
	panel = load("res://scripts/ui/conversation_panel.gd").new()
	panel.npc = "xanni"
	root.add_child(panel)
	panel.typewriter = false
	for i in range(panel.lines.size()): panel._advance()
	check(panel.closing and dialogue.invitation_accepted("sound_sampling"),"Last line records the invitation and naturally ends the conversation")
	check(not dialogue.should_invite("xanni"),"Invitation is remembered so reopening does not nag")
	await process_frame
	var hours = dialogue.reply("xanni","schedule_info")
	check(str(hours[0]).begins_with("我") and not str(hours[0]).contains("Xanni"),"Xanni uses first person for her own hours")
	for person in dialogue.content:
		var first = dialogue.reply(person,"small_talk")
		var second = dialogue.reply(person,"small_talk")
		check(first.size() >= 3 and first != second,"Residents have varied multi-line conversations: " + str(person))
	state.current_location = "produce_stall"
	state.shared_state["map_arrival"] = "produce_stall"
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.7).timeout
	var town = current_scene
	check(dialogue.invitation_for("beetman").is_empty(),"The argument is encountered directly, without a vendor invitation")
	var trigger: Dictionary = {}
	for h in town.street.hotspots:
		if h.kind == "argument": trigger = h; break
	check(not trigger.is_empty(),"Two arguing shoppers are present beside the produce stall")
	if trigger.is_empty():
		quit(1)
		return
	town.street.player_x = float(trigger.x)-105
	town.street.move_player(0,0)
	var minute: int = state.current_minute
	town.street.enabled = true
	town._try_market_encounter()
	await create_timer(0.8).timeout
	check(current_scene == town and is_instance_valid(town.conversation),"The encounter opens words on the same street without changing scenes")
	check(dialogue.notebook_leads().any(func(n: Dictionary) -> bool: return n.place == "produce_stall" and n.heading == "路上听见的事"),"Notebook points to the argument itself")
	check(root.get_node("GameplayModuleSystem").pending_module_id().is_empty(),"Talking does not open an extension session or a minigame page")
	town.conversation.get_child(0).leave_requested.emit()
	await process_frame
	check(state.current_minute == minute,"Leaving without finishing does not charge time")
	town.street.enabled = true
	town._try_market_encounter()
	check(not is_instance_valid(town.conversation),"Remaining beside the pair must not force the conversation open again")
	town._interact()
	var experience = town.conversation.get_child(0)
	experience._drain_lines()
	check(experience.waiting,"The argument pauses for the player to exchange memories")
	# Drop on the actual NPC in the continuously rendered street.
	for sample in [[experience._thought_rect(0).get_center(),true],[experience._head(1)+Vector2(0,85),false]]:
		var at: Vector2 = experience.get_global_transform_with_canvas() * sample[0]
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = sample[1]
		root.push_input(event,true)
		await process_frame
	check(experience.decoded[0],"A memory dropped on the visible person works in the scaled game window")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP")+"/solmere-supplied-art/market-conversation.png")
	for index in [5,1,4,2,3]:
		experience._drain_lines()
		check(experience._give(index,1-int(experience.MEMORIES[index].side)),"Both shoppers can share each memory during the conversation")
	experience._drain_lines()
	check(experience.finished,"Six memories lead to the reconciliatory final lines")
	experience._advance_street()
	await process_frame
	check(current_scene == town and not is_instance_valid(town.conversation),"The final spoken line resumes the same street automatically")
	check(state.current_minute == minute+30,"Completed conversation accounts for time once")
	check(root.get_node("GameplayModuleSystem").latest_outcome("translation").interaction.mode == "conversation","Conversation result remains available to the notebook and story")
	check(root.get_node("GameplayModuleSystem").pending_module_id().is_empty(),"No pending game remains after the street conversation")
	var follow_up: Dictionary = {}
	for point in town.street.hotspots:
		if str(point.get("id", "")) == "ahe": follow_up = point
	check(not follow_up.is_empty(),"One of the existing shoppers remains individually reachable after the argument")
	if not follow_up.is_empty():
		town.street.player_x = float(follow_up.x)
		town._interact()
		check(is_instance_valid(town.conversation) and town.conversation.dialogue_id.contains("post_argument"),"Talking again opens ordinary post-event smalltalk")
		if is_instance_valid(town.conversation): town.conversation._close()
	state.current_location = "night_market"
	check(root.get_node("DialogueSystem").invitation_for("beetman").is_empty(),"Misunderstanding offer must not appear away from produce stall")
	current_scene.queue_free()
	await create_timer(0.4).timeout
	print("MINIGAME INVITATION PASS" if failures == 0 else "MINIGAME INVITATION FAIL")
	quit(failures)
