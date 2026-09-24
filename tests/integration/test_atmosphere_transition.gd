extends SceneTree
var checks := 0
var failures := 0
var gs: Node
var sky: Node
const Composition = preload("res://scripts/ui/street_composition.gd")
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame; await create_timer(.25).timeout
func snapshot(file: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/atmosphere-review/"+file+".png")
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/atmosphere-review"))
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); sky=root.get_node("WorldAtmosphere")
	root.get_node("ChapterSystem").start_new_game(); gs.current_minute=1020; gs.current_location="cafe"
	sky.reset_to_clock(); sky.set_process(false)
	# Test every minute, including midnight, rather than only three screenshots.
	var palette_jump := 0.0
	var weight_jump := 0.0
	for at in 1440:
		var a := Composition.daylight(at); var b := Composition.daylight(at+1)
		palette_jump=maxf(palette_jump,Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b)))
		var w: Vector3 = sky.sky_weights(at)
		weight_jump=maxf(weight_jump,w.distance_to(sky.sky_weights(at+1)))
		if absf(w.x+w.y+w.z-1)>.00001: failures+=1
	check(palette_jump<.018,"Whole-day ambient palette has no threshold jump")
	check(weight_jump<.025,"Sky weights are continuous across all time boundaries")
	check(failures==0,"All sky weights remain normalized")
	gs.current_minute=1200
	var before: float=sky.minute
	sky.advance_visual(1.0/60.0,1200)
	check(sky.minute-before<.14,"Three-hour time cost cannot change sky in one frame")
	before=sky.minute; sky.advance_visual(20.0,1200)
	check(sky.minute-before<=.801,"A long stalled frame cannot skip the transition")
	var saw_dusk := false
	var saw_blue_hour := false
	for i in 60*40:
		sky.advance_visual(1.0/60.0,1200)
		saw_dusk=saw_dusk or sky.blend.y>.97
		saw_blue_hour=saw_blue_hour or (sky.blend.y>.25 and sky.blend.z>.25)
	check(saw_dusk and saw_blue_hour,"Time jumps still pass through sunset and blue hour")
	check(absf(sky.minute-1200)<.1,"Transition settles at the correct current time")
	check(gs.current_minute==1200,"Visual interpolation never changes transaction time")
	gs.current_minute=1080; sky.reset_to_clock()
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	current_scene.street.enabled=false
	await snapshot("sunset-start")
	gs.spend_time(120)
	sky.set_process(true)
	await settle()
	check(sky.minute<1085,"Actual rendered world stays continuous after spend_time")
	var stage=current_scene.street
	var backdrop=stage.get_children().filter(func(n):return n.get_script()!=null and n.get_script().resource_path.ends_with("coast_backdrop.gd"))[0]
	check(backdrop.panorama.material.get_shader_parameter("blend").distance_to(sky.blend)<.001,"Sky shader consumes the shared presentation state")
	check(stage.material.get_shader_parameter("daylight").distance_to(Vector3(sky.light.r,sky.light.g,sky.light.b))<.001,"Street and actors use the same current light as the sky")
	await snapshot("after-time-cost")
	before=sky.minute
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	current_scene.street.enabled=false
	check(absf(sky.minute-before)<5,"Recreating a street does not reset an ongoing transition")
	sky.set_process(false)
	for i in 60*7: sky.advance_visual(1.0/60.0,1200)
	await settle(); await snapshot("blue-hour")
	for i in 60*30: sky.advance_visual(1.0/60.0,1200)
	await settle(); await snapshot("night-settled")
	gs.current_day=2; gs.current_minute=780; sky.reset_to_clock()
	var old_rain: float=sky.rain
	sky.advance_visual(1.0/60,840)
	check(sky.rain-old_rain<.003,"Rain does not pop on when a time cost crosses weather onset")
	for i in 60*20: sky.advance_visual(1.0/60,840)
	check(sky.rain>.95,"Rain reaches its saved forecast after a gradual onset")
	gs.current_day=3; gs.current_minute=540
	root.get_node("SceneRouter").town_day(.05)
	await create_timer(.65).timeout
	check(sky.day==3 and absf(sky.minute-540)<1,"New chapter initializes at the correct time under the opaque curtain")
	print("ATMOSPHERE_TRANSITION: ",checks," checks, ",failures," failures")
	quit(failures)
