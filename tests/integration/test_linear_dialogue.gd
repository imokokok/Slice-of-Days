extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var dialogue = root.get_node("DialogueSystem")
	state.begin_new_game("B")
	state.shared_state.typewriter = false
	for npc in dialogue.linear_stories:
		var first: Array = dialogue.linear_conversation(npc)
		# Some post-argument and counter conversations are intentionally brief
		# everyday exchanges. They still need a complete back-and-forth, but they
		# should not be padded to the length of the main residents' story episodes.
		check(first.size() >= 3,"Each resident has a complete first conversation: "+npc)
		check(first.any(func(b: Array) -> bool: return b[0] == "player"),"Player participates instead of only listening to exposition")
		dialogue.complete_linear_conversation(npc)
		check(dialogue.linear_conversation(npc) != first,"Next conversation develops a different beat: "+npc)
	state.begin_new_game("B")
	state.current_location = "print_shop"
	state.shared_state.typewriter = false
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.5).timeout
	current_scene._talk_nearby("zhou_xiaoliu")
	var panel = current_scene.conversation
	check(panel.find_children("*","Button",true,false).is_empty(),"No numbered topics, response menu, continue button or goodbye button exists")
	var click := InputEventMouseButton.new()
	click.position = Vector2(700,760)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	await process_frame
	check(panel.index == 1 and panel.speaker_label.text == root.get_node("LocalizationSystem").text("你"),"Clicking the dialogue advances one line and shows the current speaker")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP")+"/solmere-linear-dialogue.png")
	for i in range(panel.index,panel.lines.size()): panel._advance()
	await process_frame
	check(not is_instance_valid(current_scene.conversation),"Final line closes naturally without an extra farewell choice")
	var saved: Dictionary = state.to_save_data().duplicate(true)
	state.begin_new_game("A")
	state.load_save_data(saved)
	check(dialogue.linear_conversation("zhou_xiaoliu")[0][1].contains("这个娃娃"),"A save reload remembers which conversation comes next")
	current_scene._talk_nearby("zhou_xiaoliu")
	current_scene.conversation._close()
	await process_frame
	check(dialogue.linear_conversation("zhou_xiaoliu")[0][1].contains("这个娃娃"),"Leaving early does not skip an unread story")
	current_scene.queue_free()
	await create_timer(0.4).timeout
	print("LINEAR DIALOGUE PASS" if failures == 0 else "LINEAR DIALOGUE FAIL")
	quit(failures)
