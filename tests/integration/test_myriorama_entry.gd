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
	var router = root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location = "tarot_stall"
	state.current_minute = 900
	router.active_space_id = "tarot_shop"
	router.interactive_space()
	await create_timer(0.7).timeout
	var room = current_scene
	room._start_conversation("xia_touming")
	await process_frame
	var talk = room.conversation
	talk.typewriter = false
	check(talk.offer.get("module","") == "tarot","Xia naturally invites the player after greeting")
	for i in range(talk.lines.size()): talk._advance()
	await process_frame
	var index := -1
	for i in range(room.objects.size()):
		if room.objects[i].get("kind","") == "tarot": index = i
	check(index >= 0,"Tarot table is present")
	if index < 0: quit(1); return
	room._select_object(index)
	room.stage.player_x = room._hotspot_x(index)
	room._open_selected()
	await create_timer(0.8).timeout
	var host = current_scene
	check(host.module_id == "tarot" and host.experience.deck.size() == 18,"Invitation table loads uploaded Myriorama with eighteen cards")
	check(not host._experience_completed(),"Opening or reading help cannot complete the story")
	host.experience.truth_draft = "尚未说完的推理"
	host.experience.save_session()
	host._cancel()
	await create_timer(0.8).timeout
	check(router.active_space_id == "tarot_shop" and state.current_location == "tarot_stall","Leaving returns to the tarot shop")
	router.gameplay_module("tarot","space:tarot_shop:table")
	await create_timer(0.8).timeout
	host = current_scene
	check(host.experience.truth_draft == "尚未说完的推理","Returning restores main-save tarot progress")
	host.experience.solmere_completed = true
	host.experience.new_case("doors")
	check(not host._experience_completed(),"Choosing a new story resets completion")
	print("MYRIORAMA ENTRY PASS" if failures == 0 else "MYRIORAMA ENTRY FAIL")
	quit(failures)
