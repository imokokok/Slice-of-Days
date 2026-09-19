extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS ",title)
	else: failures += 1; push_error(title)
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.gui_disable_input=true
	var gs=root.get_node("GameState")
	var rs=root.get_node("ResidencySystem")
	var router=root.get_node("SceneRouter")
	gs.begin_new_game("A")
	gs.current_location="cafe"
	gs.current_minute=600
	root.get_node("FilmSystem").notice_camera()
	check(root.get_node("FilmSystem").acquire_camera(false).ok,"A buys the camera through the grocery-counter state change")
	gs.current_location="print_shop"
	router.active_space_id="print_studio"
	check(rs.collect_packet().contains("六份"),"Tool journey has a collected packet")
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.5).timeout
	var host=current_scene
	var shell=host.get_node("GameplayShell")
	check(shell.hints is Control and not shell.hints is Panel,"Context key hints float without a scenery-blocking panel")
	check(not shell.hint_label.text.contains("[bgcolor="),"Context key hints render without background badges")
	check(shell.hint_label.text.contains("[b]W[/b]  进入对话"),"Context key and action text remain visible")
	shell._unhandled_input(key(KEY_TAB))
	await create_timer(.15).timeout
	check(is_instance_valid(shell.overlay) and shell.overlay.mode=="map","Tab opens paper map through real input handler")
	var minute: int=gs.current_minute
	await create_timer(4.3).timeout
	check(gs.current_minute==minute,"Reading map consumes no game time")
	var map=shell.overlay.map_board
	var old_scale: float=map.scale.x
	var wheel:=InputEventMouseButton.new()
	wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.position=Vector2(200,200)
	map._gui_input(wheel)
	check(map.scale.x>old_scale,"Map zoom operates")
	shell.overlay._input(key(KEY_ESCAPE))
	await create_timer(.15).timeout
	check(not is_instance_valid(shell.overlay),"Esc closes map without leaving scene")
	if DisplayServer.get_name()!="headless":
		await shell.open_tool("camera")
		await create_timer(.3).timeout
		check(is_instance_valid(shell.tool) and not shell.tool.focus_active,"Camera begins held, leaving the street visible")
		var camera_click:=InputEventMouseButton.new()
		camera_click.button_index=MOUSE_BUTTON_LEFT
		camera_click.pressed=true
		shell.tool._input(camera_click)
		await create_timer(.3).timeout
		check(is_instance_valid(shell.tool) and shell.tool.focus_active and shell.tool.source!=null,"LMB opens the rendered 3:2 viewfinder")
		shell.tool.library.root_path="user://final_test_photos"
		shell.tool.take_photo()
		await create_timer(.6).timeout
		check(int(root.get_node("FilmSystem").active_roll().get("exposures_used",0))==1,"Space-equivalent shutter records one raw film exposure")
		check(gs.artifacts.get("photos",[]).is_empty(),"Raw exposures wait for development before entering Gallery")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/final_camera.png")
		shell.tool._unhandled_input(key(KEY_C))
		await create_timer(.2).timeout
		check(not is_instance_valid(shell.tool),"C puts camera away")
	shell.open_tool("recorder")
	await create_timer(.15).timeout
	check(is_instance_valid(shell.tool),"Light recorder opens")
	if DisplayServer.get_name()!="headless":
		var lite=shell.tool
		lite.store_path="user://final_test_samples"
		lite._input(key(KEY_R))
		await create_timer(1.3).timeout
		lite._input(key(KEY_SPACE))
		await create_timer(1.2).timeout
		lite._input(key(KEY_R))
		await create_timer(.25).timeout
		check(lite.saved and lite.pending_wav==null,"Real TownWorld audio is captured and saved")
		check(gs.artifacts.get("samples",[]).size()==1,"Saved recording enters role's FieldBook")
		check(lite.marks.size()==1,"Space adds an actual timestamp marker")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/final_recorder.png")
		shell.tool._input(key(KEY_ESCAPE))
	else: shell.tool.queue_free()
	await create_timer(.2).timeout
	check(get_nodes_in_group("world_tool").is_empty(),"Tools release their input and time state")
	gs.current_minute=1150
	gs.current_location="residence"
	router.active_space_id="home_a"
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.4).timeout
	shell=current_scene.get_node("GameplayShell")
	current_scene.stage.player_x=460
	shell._unhandled_input(key(KEY_E))
	await create_timer(.15).timeout
	check(is_instance_valid(shell.overlay) and shell.overlay.mode=="organize","E at desk opens full organize mode")
	var note: String=rs.add_note("海边的风很轻。")
	var target=shell.overlay._drop(shell.overlay.body,"day_1",Vector2(0,0),Vector2(10,10),"test")
	check(target._can_drop_data(Vector2.ZERO,{"residency_material":note}),"Paper target accepts material drag")
	target._drop_data(Vector2.ZERO,{"residency_material":note})
	await create_timer(.15).timeout
	check(rs.state().pages[0].keep.has(note),"Drop handler actually moves material into page")
	shell.overlay.close()
	await create_timer(.15).timeout
	shell._unhandled_input(key(KEY_H))
	await create_timer(.15).timeout
	check(shell.overlay.mode=="home","H opens editorial Home")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/final_home.png")
	print("FINAL_TOOLS ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
