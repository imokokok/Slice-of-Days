extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.get_node("ChapterSystem").start_new_game("A")
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.6).timeout
	var scene = current_scene
	var state = root.get_node("GameState")
	state.current_location="produce_stall"; state.current_minute=650
	state.shared_state.map_arrival="produce_stall"
	root.get_node("SceneRouter").town_day(.01); await create_timer(.6).timeout
	scene=current_scene
	for i in 4: await process_frame
	check(not is_instance_valid(scene.conversation),"Walking close to argument never forces conversation")
	check(not root.get_node("DialogueSystem").argument_pending(),"Retired misunderstanding game stays unavailable")
	scene._talk_nearby("beetman")
	await process_frame
	check(is_instance_valid(scene.conversation),"Player can start the conversation explicitly")
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.physical_keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape)
	await process_frame
	await process_frame
	check(not is_instance_valid(scene.conversation) and scene.street.enabled,"Esc exits unfinished argument and restores walking")
	check(not root.get_node("DialogueSystem").argument_state().get("finished",false),"Cancellation never grants completion")
	check(not is_instance_valid(scene.get_node("GameplayShell").overlay),"Same Esc does not also open pause")
	scene._talk_nearby("beetman"); await process_frame
	check(is_instance_valid(scene.conversation),"Cancelled conversation remains available")
	root.push_input(escape); await process_frame; await process_frame
	scene._show_line("居民","这段话可以随时离开。")
	root.push_input(escape); await process_frame; await process_frame
	check(not scene.event_overlay.visible and scene.street.enabled,"Esc exits ordinary event dialogue")
	print("OPTIONAL DIALOGUE failures=",failures)
	quit(failures)
