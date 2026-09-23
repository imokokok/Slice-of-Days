extends SceneTree
const Motion = preload("res://scripts/ui/actor_motion.gd")
const Composition = preload("res://scripts/ui/street_composition.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	root.get_node("GameState").current_location="produce_stall"
	root.get_node("GameState").current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.4).timeout
	var stage = current_scene.street
	stage.set_process(false); stage.enabled=true
	stage.player_x=current_scene._place_center()+75
	var start: float=stage.player_x
	var frames: Dictionary={}
	for i in 100:
		stage.move_player(1,1.0/60.0)
		if stage.gait_weight>.08: frames[Motion.frame_at(stage.phase)]=true
	check(stage.player_x>start+300,"Walk advances through the real world")
	check(frames.size()==4,"Travel uses all four distinct contact/passing frames")
	var stop: float=stage.phase
	stage.enabled=false
	for i in 60: stage.move_player(1,1.0/60.0)
	check(stage.phase==stop and stage.gait_weight==0,"Blocked/modal movement settles without walking in place")
	stage.enabled=true
	for i in 100: stage.move_player(-1,1.0/60.0)
	check(stage.facing<0 and stage.velocity<0,"Turning follows leftward input")
	for seed_value in [0,3,11,21]:
		for t in [0.0,1.0,3.0]:
			for x in [0.0,1.0]:
				check(Motion.pose_point(Vector2(x,1),Vector2(100,184),t,seed_value)==Vector2((x-.5)*100,0),"Standing animation leaves both soles fixed")
	for resident in ["chenyuan","wu_wu","naonao","xia_touming","zhou_xiaoliu","maya"]:
		check(Composition.resident_feet(resident)>Composition.CURB+20 and Composition.resident_feet(resident)<=Composition.FEET-60,"Residents keep a real standing lane behind the player")
	for person in stage.presented_residents():
		var x := float(person.x)
		check(stage._actor_ground_at(x)-stage._npc_ground(str(person.id),x)>=80,"Passing feet never share the NPC standing plane")
		check(stage._actor_ground_at(x)<Composition.SIDEWALK_EDGE-6,"Passing remains on the pavement")
	check(stage.player_display.z_index>stage.original_resident.z_index,"Original-sheet NPC cannot render through the foreground player")
	# Optional visual evidence records the actual stage, not a mockup.
	var folder:=OS.get_environment("MOTION_CAPTURE_DIR")
	if not folder.is_empty() and DisplayServer.get_name()!="headless":
		stage.player_x=current_scene._place_center()+75
		stage.move_player(0,0); stage.facing=1; stage.gait_weight=1
		for i in 4:
			stage.phase=i*PI*.5+.01; stage.queue_redraw()
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/walk-%d.png"%i)
	print("STREET MOTION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
