extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func sample(node: Control) -> Color:
	await process_frame
	await RenderingServer.frame_post_draw
	var at: Vector2=node.get_global_rect().get_center()
	return root.get_texture().get_image().get_pixelv(Vector2i(at))
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720)
	root.get_node("ChapterSystem").start_new_game()
	var background:=ColorRect.new(); background.color=Color("3b786b"); background.size=Vector2(1280,720); root.add_child(background)
	var recorder=load("res://scripts/residency/recorder_lite.gd").new(); root.add_child(recorder)
	await create_timer(.5).timeout
	var picture: ColorRect=recorder.live_screen.world_picture
	var first: Color=await sample(picture)
	check(first.is_equal_approx(background.color),"Preview displays pixels from the world, not the recorder shell")
	background.color=Color("bb8548")
	var second: Color=await sample(picture)
	check(second.is_equal_approx(background.color) and not first.is_equal_approx(second),"World changes appear live without recursively copying the UI")
	recorder.toggle_recording(); await create_timer(1.6).timeout
	check(recorder.recorder.frame_count>0 and recorder.live_screen.frames_seen>5,"Live picture runs during actual PCM capture")
	recorder.toggle_recording(); await process_frame
	check(recorder.saved and recorder.playback.stream is AudioStreamWAV,"Stop persists real audio and allows playback")
	recorder._play_last(); await process_frame; await process_frame
	check(recorder.playback.playing and not picture.visible,"Saved playback shows the saved sound score, not the current street")
	recorder.playback.stop(); await process_frame
	check(picture.visible,"Returning to recording restores the live view")
	recorder.queue_free(); background.queue_free(); await process_frame
	print("LIVE_RECORDING_PICTURE: ",checks," checks / ",failures," failures"); quit(failures)
