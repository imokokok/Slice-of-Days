extends SceneTree
var failures:=0
var checks:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var gs=root.get_node("GameState"); var modules=root.get_node("GameplayModuleSystem"); var router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game(); gs.current_location="record_store"; gs.current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	check(router.gameplay_module("sound_sampling","route_audit"),"Ordinary sound entry opens")
	await settle()
	var screens=get_nodes_in_group("town_sound_workspace")
	check(screens.size()==1,"Entry creates one real recorder workspace")
	if screens.is_empty(): quit(1); return
	var screen=screens[0]
	check(screen.shop_mode and screen.can_edit_here(),"Production workspace has actual studio access")
	check(not router.gameplay_module("sound_sampling","second_click"),"Repeated entry cannot stack recorder UIs")
	await create_timer(2.8).timeout
	check(modules.pending_module_id().is_empty() and not bool(modules.state_for("sound_sampling").get("completed",false)),"Waiting cannot complete a sound work or leave a fake pending session")
	check(screen.recorder is FieldRecorder and not screen.recorder.capturing,"Recorder waits for explicit recording input")
	screen.request_close(); await settle()
	check(get_nodes_in_group("town_sound_workspace").is_empty(),"Closing returns to the same playable scene")
	check(router.gameplay_module("sound_sampling","reopen"),"Workspace reopens after closing")
	await settle(); get_nodes_in_group("town_sound_workspace")[0].request_close(); await settle()
	print("MUSIC_SOURCE_ROUTE: ",checks," checks, ",failures," failures"); quit(failures)
