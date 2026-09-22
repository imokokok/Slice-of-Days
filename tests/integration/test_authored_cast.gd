extends SceneTree
var checks := 0
var failures := 0
const CAST := ["mossner","xanni","chenyuan","maya","mingming","zhou_xiaoliu","beetman","xia_touming","yuxingqing","shi_yongqi","naonao","wu_wu"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state = root.get_node("GameState")
	var schedule = root.get_node("ScheduleSystem")
	var profiles = root.get_node("ResidentProfileSystem")
	var dialogue = root.get_node("DialogueSystem")
	var save = root.get_node("SaveManager")
	state.begin_new_game("A")
	check(schedule.residents.size()==12 and profiles.profiles.size()==12,"Exactly twelve canonical people")
	check(dialogue.linear_stories.size()==12 and dialogue.content.size()==12,"No hidden extra dialogue cast")
	check(schedule.residents.wu_wu.display_name=="CICI" and profiles.profiles.wu_wu.aliases.has("巫巫"),"CICI and Wuwu are one person")
	for day in range(1,8):
		for minute in range(480,1440,30):
			for place in root.get_node("ResidencySystem").locations:
				for id in schedule.residents_at(place,day,minute):
					if not CAST.has(id): check(false,"Unexpected scheduled NPC: "+id)
	for id in CAST:
		check(schedule.residents.has(id),"Named cast member remains reachable: "+id)
		check(not profiles.profiles[id].hobbies.is_empty(),"Source hobbies: "+id)
		for topic in profiles.topics_for(id):
			var answer: Array=dialogue.reply(id,"interest:"+str(topic.id))
			check(answer==topic.lines,"Selected source topic has its own actual branch: "+id+"/"+str(topic.id))
		var initial: Array=dialogue.linear_conversation(id)
		dialogue.complete_linear_conversation(id)
		check(dialogue.linear_conversation(id)!=initial,"Familiarity advances without replaying introduction: "+id)
		state.shared_state["linear_talk_counts_A"][id]=12
		var repeated: Array=dialogue.linear_conversation(id)
		dialogue.complete_linear_conversation(id)
		check(dialogue.linear_conversation(id)!=repeated,"Late revisits have distinct authored content: "+id)
	for relation in dialogue.relationship_notes:
		check(relation.people.all(func(id: String) -> bool: return CAST.has(id)),"Every relationship belongs to the cast: "+str(relation.id))
		for person in relation.people:
			check(not relation.lines_by_npc.get(person,[]).is_empty(),"Both ends of a relationship speak in their own voice: "+person)
		if relation.get("identity_known",true)==false:
			check(not " ".join(relation.lines_by_npc.mossner).contains("BEETMAN") and not " ".join(relation.lines_by_npc.beetman).contains("Mossner"),"Unrecognized pen pals do not reveal each other")
	check(dialogue.reply("grocery","greeting").is_empty() and dialogue.linear_conversation("town_resident_033").is_empty(),"Service/removed IDs cannot synthesize dialogue")
	check(not " ".join(dialogue.linear_stories.zhou_xiaoliu.episodes[0].map(func(b: Array) -> String: return str(b[1]))).contains("房租"),"Zhou is no longer assigned the old freelancer backstory")
	var seen := {}
	for i in 6:
		var lines: Array=dialogue.reply("xia_touming","relationship_followup")
		seen[" ".join(lines)]=true
	check(seen.size()>=3,"Relationships rotate across multiple people instead of always the first edge")
	# Real old-save upgrade, including inactive role and placed signature geometry.
	var old: Dictionary=state.to_save_data().duplicate(true)
	old.shared_state.erase("resident_cast_version")
	old.shared_state.linear_talk_counts_A={"ahe":3,"wu_wu":1,"town_resident_033":5}
	for role in ["A","B"]:
		old.role_states[role].confirmed_residents=["ahe","wu_wu","chen_chuan","town_resident_033"]
		old.role_states[role].encountered_residents=["ahe","wu_wu","chen_chuan","grocery"]
		old.role_states[role].relationships={"ahe":{"encounters":2,"confirmation":"granted","flags":["kept memory"]},"wu_wu":{"encounters":1,"confirmation":"unknown","flags":["pet photo"]},"town_resident_033":{"encounters":8}}
		old.role_states[role].artifacts.residency=root.get_node("ResidencySystem").state().duplicate(true)
		old.role_states[role].artifacts.residency.merge({"materials":{"recognition_ahe":{"id":"recognition_ahe","kind":"recognition","resident":"ahe","title":"阿禾的签记"}},"free_pages":{"recognition":[{"material":"recognition_ahe","kind":"recognition","text":"阿禾","x":319,"y":97,"rotation":.2}]}},true)
	state.load_save_data(old)
	check(state.confirmed_residents==["wu_wu","chenyuan"],"Aliases merge, removed background residents no longer inflate recognition")
	check(state.role_states.B.confirmed_residents==["wu_wu","chenyuan"],"Inactive role also migrates")
	check(state.relationships.wu_wu.flags.has("kept memory") and state.relationships.wu_wu.flags.has("pet photo"),"Merged relationship retains both memories")
	check(state.shared_state.linear_talk_counts_A.wu_wu==3,"Chat progress is retained without double counting")
	var piece: Dictionary=state.artifacts.residency.free_pages.recognition[0]
	check(piece.material=="recognition_wu_wu" and piece.text=="CICI" and piece.x==319 and piece.rotation==.2,"Signature identity updates without moving the player's collage")
	check(state.shared_state.legacy_resident_archive.role_states.A.confirmed_residents.has("town_resident_033"),"Retired data has a recoverable original backup")
	check(save.save_or_report("cast regression"),"Migrated save writes")
	state.begin_new_game("A")
	check(save.load_slot(1),"Migrated save reloads")
	check(state.confirmed_residents.size()==2 and state.shared_state.linear_talk_counts_A.wu_wu==3,"Repeat load does not reset progress or repeat migration")
	# Exercise actual world entry: the grocery is a place, not a thirteenth actor.
	state.begin_new_game("A");state.current_minute=660;state.current_location="cafe"
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	current_scene.set_process(false);current_scene.street.set_process(false)
	current_scene._refresh()
	check(not current_scene.street.presented_residents().any(func(p: Dictionary) -> bool: return p.id=="grocery"),"No grocery shopkeeper body")
	check(current_scene.street.hotspots.any(func(p: Dictionary) -> bool: return p.kind=="door" and p.id=="grocery"),"Grocery entrance still opens")
	current_scene._talk_nearby("grocery")
	check(not is_instance_valid(current_scene.conversation),"Cannot force a service object into a character conversation")
	var ask=load("res://scripts/meta/ask_panel.gd").new();ask.npc="maya";current_scene.add_child(ask)
	ask._choose("interests")
	check(ask.card.choices.get_child_count()==3,"Two real source topics and a working Back choice")
	var chosen: Array=[]
	ask.chosen.connect(func(topic: String) -> void: chosen.append(topic))
	ask.card.choices.get_child(0).pressed.emit()
	check(chosen==["interest:rain"],"Native topic button emits the intended branch")
	await process_frame
	check(not is_instance_valid(ask),"Choosing a topic closes its question sheet")
	current_scene.queue_free();await process_frame
	print("AUTHORED CAST checks=",checks," failures=",failures)
	quit(failures)
