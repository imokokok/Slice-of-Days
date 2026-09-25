extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	var gs=root.get_node("GameState"); var saves=root.get_node("SaveManager")
	change_scene_to_file("res://scenes/town_day.tscn"); await create_timer(.5).timeout
	var shell=current_scene.get_node("GameplayShell"); shell.open_tool("recorder")
	var recorder=shell.tool; recorder.toggle_recording(); await create_timer(1.5).timeout
	check(recorder.recorder.frame_count>0,"Real PCM captured before testing storage failure")
	var original=saves.get_script(); var failing:=GDScript.new()
	failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload()==OK,"Failure fixture compiles")
	var before: int=gs.artifacts.get("samples",[]).size()
	saves.set_script(failing); recorder.toggle_recording(); await process_frame
	check(not recorder.saved and recorder.pending_wav!=null,"Failed save retains actual audio for retry")
	var id: String=str(recorder.pending_sample.get("id",""))
	check(not id.is_empty() and gs.artifacts.get("samples",[]).size()==before,"Failed state save does not award a duplicate sample")
	check(not recorder.finish_for_exit() and not recorder.is_queued_for_deletion(),"Cannot close away unsaved recording")
	recorder.toggle_recording()
	check(str(recorder.pending_sample.get("id",""))==id,"Repeated failed save retains the same audio file identity")
	saves.set_script(original); recorder.toggle_recording(); await process_frame
	check(recorder.saved and gs.artifacts.get("samples",[]).size()==before+1,"Retry adds exactly one saved recording")
	check(str(gs.artifacts.samples[-1].id)==id,"Saved recording references the original audio file")
	check(saves.load_game() and gs.artifacts.get("samples",[]).size()==before+1,"Recording survives reload")
	recorder.finish_for_exit(); await process_frame; await process_frame
	shell.open_paper("dossier"); var paper=shell.overlay
	saves.set_script(failing); paper.close()
	check(not paper.is_queued_for_deletion(),"Unsaved paper remains open after storage failure")
	saves.set_script(original); paper.close()
	check(paper.is_queued_for_deletion(),"Paper closes after successful retry")
	print("RECORDING_RETRY failures=",failures); quit(failures)
