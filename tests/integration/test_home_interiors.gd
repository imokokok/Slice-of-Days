extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func settle() -> void:
	await process_frame
	while root.get_node("SceneRouter").transitioning: await process_frame
	await process_frame
func interact() -> void:
	var event:=InputEventKey.new(); event.keycode=KEY_E; event.physical_keycode=KEY_E; event.pressed=true
	root.push_input(event); await process_frame
	event.pressed=false; root.push_input(event); await settle()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gs=root.get_node("GameState"); var router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	for role in ["A","B"]:
		gs.switch_to_role(role,1 if role=="A" else 2,true); gs.current_minute=720
		gs.current_location=root.get_node("CoreLoopSystem").home()
		gs.shared_state.map_arrival=gs.current_location; router.town_day(.01); await settle()
		var doors: Array=current_scene.street.hotspots.filter(func(h):return str(h.kind)=="home")
		check(doors.size()==1,role+" owns one actual street doorway")
		if doors.is_empty(): quit(1); return
		current_scene.street.player_x=doors[0].x
		await interact()
		check(is_instance_valid(current_scene.pocket_panel),role+" enters the shared landing before the private room")
		current_scene.pocket_panel.find_child("EnterPrivateRoom",true,false).pressed.emit(); await settle()
		check(router.active_space_id=="home_"+role.to_lower() and current_scene.stage.indoor,role+" enters real indoor scene via E")
		if not current_scene.has_method("_hotspot_x"): quit(1); return
		var room=current_scene; var stage=room.stage; var shell=room.get_node("GameplayShell")
		var atlas=load("res://scripts/ui/scene_atlas.gd")
		check(atlas.plate(atlas.room(stage.room_kind))!=null,role+" loads the authored interior painting")
		check(not stage.hotspots.any(func(h):return str(h.kind)=="residency"),"Retired home application points are absent")
		var xs: Array=[]
		for i in room.objects.size():
			var x: float=room._hotspot_x(i)
			check(not xs.has(x),"Furniture never shares fallback coordinate "+str(x)); xs.append(x)
			stage.player_x=x; await process_frame
			check(stage.nearest_interactable().get("index",-1)==i,"Nearest prompt belongs to "+str(room.objects[i].id))
			check(shell._special().is_empty(),"Old service cannot replace room object prompt")
			if str(room.objects[i].kind)=="journal":
				await interact(); check(is_instance_valid(shell.overlay) and shell.overlay.mode=="notebook","Desk opens the shared hand-drawn notebook")
				if is_instance_valid(shell.overlay): shell.overlay.close(); await settle()
		stage.player_x=560; stage.set_process(false)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.runtime/home-captures")
		root.get_texture().get_image().save_png("res://.runtime/home-captures/"+role+".png")
		stage.player_x=145 if role=="A" else 90; await interact()
		check(router.active_space_id.is_empty() and current_scene.scene_file_path==router.TOWN_DAY,role+" exits through the painted door")
	print("HOME_INTERIORS: ",checks," checks / ",failures," failures"); quit(failures)
