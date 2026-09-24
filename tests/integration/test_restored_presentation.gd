extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame; await create_timer(.25).timeout
func snap(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/atmosphere-review/"+name+".png")
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/atmosphere-review"))
	var gs=root.get_node("GameState"); var router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game(); gs.current_location="produce_stall"; gs.current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	var stage=current_scene.street
	stage.player_x=current_scene._place_center()-120; stage.move_player(0,0); stage.enabled=false
	var lock=Control.new(); lock.add_to_group("meta_modal"); current_scene.add_child(lock)
	var residents=root.get_node("ScheduleSystem").residents
	check(residents.size()==12,"The authored twelve-resident roster is unchanged")
	check(stage.original_resident.texture.resource_path=="res://art/user_scenes/zhou_xiaoliu.png","The supplied Zhou Xiaoliu character sheet is restored")
	var names: Array=residents.keys()
	for page in 3:
		stage.hotspots.clear(); stage.neighboring_residents.clear(); stage.presence.residents.clear()
		for i in 4: stage.hotspots.append({"kind":"person","id":names[page*4+i],"x":stage.camera_x+260+i*340})
		stage.queue_redraw(); await settle()
		for i in 4:
			var id: String=names[page*4+i]
			check(stage.presented_residents().any(func(row): return str(row.id)==id) and not str(residents[id].display_name).is_empty(),"Restored resident keeps the authored identity: "+id)
		await snap("restored-residents-"+str(page+1))
	lock.queue_free(); await settle()
	for role in ["A","B"]:
		gs.switch_to_role(role,1 if role=="A" else 2,true)
		gs.current_location="residence" if role=="A" else "dorm"; gs.current_minute=660
		router.active_space_id="home_a" if role=="A" else "home_b"
		change_scene_to_file("res://scenes/interactive_space.tscn"); await settle()
		check(current_scene.stage.room_kind==router.active_space_id,"Existing home interior retained for "+role)
		check(current_scene.stage.get_script().get_script_constant_map().PROTAGONIST_ART.resource_path=="res://art/user_scenes/protagonist_colored.png","Original protagonist artwork is restored: "+role)
		await snap("restored-home-"+role)
	router.active_space_id=""; gs.current_location="cafe"; gs.current_minute=1080
	root.get_node("WorldAtmosphere").reset_to_clock()
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	current_scene.street.player_x=current_scene._place_center()-130; current_scene.street.move_player(0,0)
	var hud=current_scene.get_node("GameplayShell")
	var face=hud.clock_back.get_theme_stylebox("panel")
	check(face.bg_color.a==1 and face.bg_color.get_luminance()>.75,"Clock uses an opaque warm paper face")
	var ink: Color=hud.clock_label.get_theme_color("font_color")
	check((face.bg_color.srgb_to_linear().get_luminance()+.05)/(ink.srgb_to_linear().get_luminance()+.05)>=7,"Clock text keeps at least 7:1 luminance contrast against paper")
	check(hud.next_button.get_theme_stylebox("normal").bg_color.a==1,"Direction card remains opaque against day and night")
	await snap("restored-coastal-hud")
	print("RESTORED_PRESENTATION: ",checks," checks, ",failures," failures")
	quit(failures)
