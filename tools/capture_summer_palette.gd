extends SceneTree
## Real scene captures with a frozen presentation clock, isolated from player saves.
var gs
var router
var atmosphere
var failures := 0
var captured := 0
var before := false
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
func capture(place: String, room: String, day: int, minute: int, caption: String) -> void:
	gs.current_day=day; gs.current_minute=minute; gs.current_location=place
	gs.shared_state.map_arrival=place
	if room.is_empty(): router.town_day(.01)
	else: router.enter_space(room)
	await settle()
	current_scene.set_process(false)
	var stage = current_scene.street if room.is_empty() else current_scene.stage
	stage.set_process(false); stage.enabled=false
	stage.player_x=current_scene._place_center()-120 if room.is_empty() else 913.6
	stage.move_player(0,0)
	if place=="residence" and room.is_empty(): stage.camera_x=0
	atmosphere.reset_to_clock(); atmosphere.set_process(false)
	stage._update_world_finish(); stage._sync_original_resident()
	stage.queue_redraw(); stage.player_display.queue_redraw()
	if not before:
		if not stage.material is ShaderMaterial or stage.material.get_shader_parameter("amount")!=1.0:
			push_error("World color material missing: "+caption); failures+=1
		if not stage.player_display.use_parent_material:
			push_error("Player is outside the shared world grade"); failures+=1
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("SOLMERE_QA_CAPTURE_DIR")
	if folder.is_empty(): folder=ProjectSettings.globalize_path("res://.runtime/summer-palette")
	folder=folder.path_join("before" if before else "after")
	DirAccess.make_dir_recursive_absolute(folder)
	var result:=root.get_texture().get_image().save_png(folder.path_join(caption+".png"))
	if result!=OK: push_error("Screenshot failed: "+caption); failures+=1
	captured+=1
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	before=OS.get_cmdline_user_args().has("--before")
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter"); atmosphere=root.get_node("WorldAtmosphere")
	root.get_node("ChapterSystem").start_new_game()
	for preset in [[1,720,"day"],[1,1095,"sunset"],[1,1230,"night"],[2,900,"rain"]]:
		await capture("residence","",preset[0],preset[1],"home-"+preset[2])
		await capture("cafe","",preset[0],preset[1],"street-"+preset[2])
	await capture("record_store","record_shop",1,720,"records-day")
	await capture("residence","home_a",1,720,"room-a-day")
	await capture("residence","home_b",2,1230,"room-b-night")
	await capture("residence","",1,720,"home-final")
	print("SUMMER_PALETTE_CAPTURE: ",captured," captures / ",failures," failures")
	if not before and failures==0 and OS.get_cmdline_user_args().has("--keep-open"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_set_position(Vector2i(120,80))
		DisplayServer.window_set_title("Solmere · 夏日配色")
		current_scene.set_process(true); current_scene.street.set_process(true)
		current_scene.street.enabled=true
		atmosphere.set_process(true)
		return
	quit(failures)
