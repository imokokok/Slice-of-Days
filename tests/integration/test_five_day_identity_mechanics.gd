extends SceneTree
## Pure state regression for observation, identity inference and Day 5 practice.

var checks := 0
var failures := 0
var state
var chapter
var relationships


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)


func object_row(id: String, owner: String, day: int, kind: String, title: String, places: Array) -> Dictionary:
	return {
		"id": id,
		"source_id": id,
		"owner": owner,
		"day": day,
		"type": kind,
		"view_kind": kind,
		"title": title,
		"places": places,
		"discovered_by": [owner],
		"payload": {},
	}


func collect_visible_text(node: Node, rows: Array[String]) -> void:
	if node is Label or node is RichTextLabel or node is BaseButton:
		rows.append(str(node.text))
	for child in node.get_children():
		collect_visible_text(child, rows)


func capture(name: String) -> void:
	var folder:=OS.get_environment("FIVE_DAY_CAPTURE_DIR")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(2)
		return
	state = root.get_node("GameState")
	chapter = root.get_node("ChapterSystem")
	relationships = root.get_node("RelationshipSystem")
	chapter.start_new_game()
	relationships.record_encounter("xanni", "day1_sound_delivery")
	state.switch_to_role("B", 2, true)
	relationships.record_encounter("shi_yongqi", "day2_kitchen_delivery")
	state.shared_state["everyday_objects"] = {
		"B_2_recipe": object_row("B_2_recipe", "B", 2, "recipe", "饭店今天的做法", ["residence", "print_shop"]),
		"B_2_receipt": object_row("B_2_receipt", "B", 2, "receipt", "夹在做法旁的采购小票", ["residence", "print_shop"]),
		"A_1_record": object_row("A_1_record", "A", 1, "record", "唱片机旁的唱片", ["dorm", "print_shop"]),
		"A_3_letter": object_row("A_3_letter", "A", 3, "letter", "寄出信件的留底", ["dorm", "print_shop"]),
	}

	state.switch_to_role("A", 3, true)
	state.current_location = "residence"
	chapter.day_state().main_completed = true
	chapter.observe_everyday_object("B_2_recipe")
	chapter.observe_everyday_object("B_2_recipe")
	check(not bool(chapter.story().A_noticing), "re-reading one object cannot prove another person")
	chapter.observe_everyday_object("B_2_receipt")
	var a_summary: Dictionary = chapter.observation_summary("A")
	check(bool(chapter.story().A_noticing) and a_summary.kinds.size() == 2, "two source kinds confirm Day 3 inconsistency")
	check(chapter.narrative_lines("mossner").any(func(beat: Array) -> bool: return str(beat[1]).contains("饭店今天的做法")), "Day 3 dialogue names an object the player actually read")
	check(chapter.record_identity_response("mossner", "clarify"), "A can correct Mossner's mistaken attribution")
	check(chapter.identity_response("mossner", "A") == "clarify", "A's clarification is stored by role and NPC")
	check(chapter.record_identity_response("mossner", "clarify") and not chapter.record_identity_response("mossner", "defer"), "identity response is idempotent and cannot be silently replaced")
	check(relationships.has_flag("mossner", "identity_response_clarify"), "clarification is retained in A's private relationship state")
	chapter.on_conversation_completed("mossner")
	check(relationships.identity_stage("mossner") == "notices_inconsistency", "Mossner retains the Day 3 identity stage")

	state.switch_to_role("B", 4, true)
	state.current_location = "dorm"
	chapter.day_state().main_completed = true
	chapter.observe_everyday_object("A_1_record")
	chapter.observe_everyday_object("A_3_letter")
	var b_summary: Dictionary = chapter.observation_summary("B")
	check(bool(chapter.story().B_noticing) and b_summary.kinds == ["record", "letter"], "Day 4 requires two different retained works")
	check(chapter.record_identity_response("naonao", "defer"), "B can wait for both people before explaining the mismatch")
	check(chapter.identity_response("naonao", "B") == "defer", "B's deferred response is stored separately")
	chapter.on_conversation_completed("naonao")
	state.current_location = "chess_stall"
	check(chapter.arrange_meeting(), "evidence-backed Day 4 conversation can arrange the meeting")
	check(relationships.identity_stage("naonao") == "suspects_two_people", "Naonao records suspicion before the reveal")

	state.switch_to_role("A", 5, true)
	state.current_location = "print_shop"
	var meeting: Array = chapter.meeting_lines()
	check(meeting.size() >= 4, "meeting has a resumable multi-beat structure")
	check(meeting.any(func(line: String) -> bool: return line.contains("采购小票")) and meeting.any(func(line: String) -> bool: return line.contains("唱片")), "meeting pays off both roles' observed objects")
	check(chapter.finish_reveal(), "final acknowledgement completes the reveal")
	check(relationships.identity_stage("mossner") == "identity_confirmed" and relationships.identity_stage("naonao") == "identity_confirmed", "reveal confirms every NPC who retained evidence")
	check(relationships.identity_stage("xanni") == "identity_confirmed" and relationships.identity_stage("shi_yongqi") == "identity_confirmed", "reveal also updates the Day 1 and Day 2 collaborators")
	var mossner_reaction: Array=root.get_node("DialogueSystem").identity_reaction_lines("mossner")
	check(mossner_reaction.any(func(beat: Array)->bool:return str(beat[1]).contains("直接说")), "Mossner's confirmed reaction echoes A's clarification")
	root.get_node("DialogueSystem").complete_identity_reaction("mossner")
	check(root.get_node("DialogueSystem").identity_reaction_lines("mossner").is_empty(), "a staged identity reaction is not repeated after completion")
	state.switch_to_role("B", 5, true)
	var naonao_reaction: Array=root.get_node("DialogueSystem").identity_reaction_lines("naonao")
	check(naonao_reaction.any(func(beat: Array)->bool:return str(beat[1]).contains("等见面")), "Naonao's confirmed reaction echoes B's decision to wait")
	state.switch_to_role("A", 5, true)

	var result := {"context":{"current_character":"A", "day":5, "location":"night_market"}}
	chapter.register_cross_domain_result("cooking", result)
	chapter.register_cross_domain_result("cooking", result)
	check(str(result.craft_perspective) == "cross_domain", "opposite-domain work records the acting perspective")
	check(chapter.story().cross_domain_practice.A == ["cooking"], "repeating one activity cannot duplicate Day 5 practice")
	check(chapter.next_cross_domain_activity("A").is_empty(), "one optional opposite-domain experience satisfies the post-reveal suggestion")
	check(chapter.journey_audit().cross_domain_practice.A == ["cooking"], "journey audit exposes optional practice without making it an ending gate")
	check(chapter.journey_audit().identity_responses.A.mossner.choice == "clarify", "journey audit exposes the identity response without turning it into a gate")
	var ending: Dictionary=chapter.ending_reflections()
	check(ending.recognitions.size() == 4, "ending reflection includes all four main collaborators")
	check(ending.recognitions.any(func(row: Dictionary)->bool:return str(row.npc)=="mossner" and str(row.response.get("choice",""))=="clarify"), "ending reflection carries the player's correction choice")
	check(ending.practices.any(func(row: Dictionary)->bool:return str(row.role)=="A" and str(row.module_id)=="cooking"), "ending reflection carries optional cross-domain practice")
	state.shared_state["public_traces"]={}
	for item in state.shared_state.everyday_objects.values(): state.shared_state.public_traces[str(item.id)]=item.duplicate(true)

	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var translated_meeting := str(root.get_node("LocalizationSystem").text("你也来赴约了。我看到的《饭店今天的做法》，是你留下的吗？"))
	check(translated_meeting.begins_with("You came to the meeting too."), "dynamic meeting evidence uses the English template")
	var translated_pair:=str(root.get_node("LocalizationSystem").text("《饭店今天的做法》和《夹在做法旁的采购小票》"))
	check(not translated_pair.contains("和") and translated_pair.contains(" and "), "paired evidence titles do not retain Chinese joiners in English")
	check(root.get_node("LocalizationSystem").text("这是可选尝试，不影响结束旅程；日程页仍可切换视角。").begins_with("This is optional"), "optional practice guidance is localized")
	var ending_scene: Node=load("res://scenes/ending.tscn").instantiate()
	root.add_child(ending_scene)
	await process_frame
	await capture("identity-ending-top")
	var ending_text: Array[String]=[]
	collect_visible_text(ending_scene,ending_text)
	var cjk:=RegEx.new(); cjk.compile("[㐀-鿿]")
	var untranslated_ending:=ending_text.filter(func(value: String)->bool:return cjk.search(value)!=null)
	if not untranslated_ending.is_empty(): print("UNTRANSLATED_ENDING ",untranslated_ending)
	check(ending_text.any(func(value: String)->bool:return value.contains("How the Town Learned")), "ending renders the identity reflection section")
	check(untranslated_ending.is_empty(), "new ending reflection renders without Chinese remnants in English")
	var reflection_scroll: ScrollContainer=ending_scene.get_node("ReflectionScroll")
	check(reflection_scroll.get_v_scroll_bar().max_value>reflection_scroll.size.y, "ending overflow has a usable vertical scroll range")
	reflection_scroll.scroll_vertical=int(reflection_scroll.get_v_scroll_bar().max_value)
	await process_frame
	check(reflection_scroll.scroll_vertical>0, "ending can scroll to the NPC and cross-domain reflections")
	await capture("identity-ending-scrolled")
	ending_scene.queue_free()
	TranslationServer.set_locale(original_locale)

	print("FIVE_DAY_IDENTITY_MECHANICS: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(failures)
