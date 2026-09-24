extends SceneTree
var gs
var router
var shell
var planner
var failures := 0
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
	current_scene.set_process(false)
	root.get_node("WorldAtmosphere").reset_to_clock()
func shot(id: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var folder := OS.get_environment("SOLMERE_QA_CAPTURE_DIR")
	if folder.is_empty(): folder=ProjectSettings.globalize_path("res://.runtime/daily-life-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	if root.get_texture().get_image().save_png(folder.path_join(id+".png"))!=OK: failures+=1
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	gs.current_minute=480; gs.current_location="residence"
	router.enter_space("home_a"); await settle()
	shell=current_scene.get_node("GameplayShell"); shell.open_paper("day_schedule"); await process_frame
	planner=shell.overlay.find_child("DayFivePlanner",true,false)
	await shot("today")
	planner.find_child("LifeTab_plan",true,false).pressed.emit(); await process_frame
	planner.find_child("AddPlan",true,false).pressed.emit(); await process_frame
	await shot("plan")
	shell.overlay.close(); await process_frame
	gs.switch_to_role("B",2,true); gs.current_minute=800; gs.current_location="night_market"
	router.enter_space("restaurant"); await settle()
	shell=current_scene.get_node("GameplayShell"); shell.open_paper("day_schedule"); await process_frame
	planner=shell.overlay.find_child("DayFivePlanner",true,false); planner.find_child("LifeTab_work",true,false).pressed.emit(); await process_frame
	await shot("work")
	shell.overlay.close(); await process_frame
	gs.switch_to_role("A",1,true); gs.current_location="record_store"; gs.spend_time(610-gs.current_minute)
	router.enter_space("record_shop"); await settle()
	var puzzle=root.get_node("PeoplePuzzleSystem")
	puzzle.act("xanni","observe"); gs.spend_time(690-gs.current_minute); puzzle.act("xanni","help")
	shell=current_scene.get_node("GameplayShell"); shell.open_paper("day_schedule"); await process_frame
	planner=shell.overlay.find_child("DayFivePlanner",true,false); planner.find_child("LifeTab_people",true,false).pressed.emit(); await process_frame
	await shot("people")
	print("DAILY_LIFE_CAPTURE: 4 pages / ",failures," failures")
	if OS.get_cmdline_user_args().has("--keep-open"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); DisplayServer.window_set_size(Vector2i(1280,720)); DisplayServer.window_set_position(Vector2i(120,80)); DisplayServer.window_set_title("Solmere · 日程与生活机制")
		planner.tab="me"; planner.rebuild(); current_scene.set_process(true); return
	quit(failures)
