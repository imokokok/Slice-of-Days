extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.get_node("GameState").begin_new_game("A")
	var script = load("res://scripts/residency/living_objects.gd")
	if script == null: quit(1); return
	var paper = script.new()
	paper.mode="dossier"
	root.add_child(paper)
	await process_frame
	for tab in ["requirements","personal","life","recognition","final","days"]:
		paper.archive_tab=tab; paper.build()
		check((paper.body.get_node_or_null("PortfolioDay_01") != null)==(tab=="days"),"Only portfolio has day tabs: "+tab)
	paper.archive_tab="personal"; paper.build()
	check(paper.canvas.pieces.is_empty(),"Personal starts blank")
	paper.canvas.add_piece({"kind":"text","text":"我的海边","w":180,"h":90},Vector2(220,150))
	paper.canvas.transform_selected("rotate_right")
	paper.canvas.transform_selected("larger")
	paper.archive_tab="days"; paper.day=1; paper.build()
	check(paper.canvas.pieces.is_empty(),"Day one independent from Personal")
	paper.canvas.add_piece({"kind":"text","text":"第一天"},Vector2(120,100))
	paper.day=2; paper.build()
	check(paper.canvas.pieces.is_empty(),"Day two independent")
	paper.archive_tab="personal"; paper.build()
	check(paper.canvas.pieces.size()==1 and paper.canvas.pieces[0].rotation>0,"Personal transformations survive switches")
	var before: Dictionary = root.get_node("GameState").to_save_data().duplicate(true)
	root.get_node("GameState").load_save_data(before)
	paper.build()
	check(paper.canvas.pieces.size()==1,"Composition survives save serialization")
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(220,150)
	paper.canvas._gui_input(press)
	var motion := InputEventMouseMotion.new(); motion.position=Vector2(350,240)
	paper.canvas._gui_input(motion)
	var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false
	paper.canvas._input(release)
	check(paper.canvas.pieces[0].x==350 and not paper.canvas.dragging,"Drag commits when released outside sheet")
	paper.canvas.drawing=true
	press.position=Vector2(300,60); paper.canvas._gui_input(press)
	motion.position=Vector2(380,100); paper.canvas._gui_input(motion)
	paper.canvas._input(release)
	check(paper.canvas.pieces.size()==2 and paper.canvas.pieces[1].kind=="drawing","Draw stroke becomes movable material")
	paper.canvas.selected=1; paper.canvas.transform_selected("back")
	check(paper.canvas.pieces[0].kind=="drawing","Layer order changes")
	paper.canvas.transform_selected("remove")
	check(paper.canvas.pieces.size()==1,"Removal persists")
	var residency = root.get_node("ResidencySystem")
	var note_id: String = residency.add_note("测试素材")
	if OS.get_cmdline_user_args().has("--screenshots"):
		for i in 6:
			residency.state().materials["tray_example_"+str(i)]={"kind":["note","receipt","sound","recognition"][i%4],"title":["海边捡来的字句","海盐豆罐头 · 15 元","午后的海浪","CICI 留下的签名","一封折起来的信","和居民一起散步"][i]}
	paper._material_tray()
	var spread: Node = paper.detail.find_child("LooseMaterials",true,false)
	check(spread!=null and spread.get_child_count()>0,"Material tray contains loose cutouts")
	if spread!=null:
		check(not spread.get_child(0) is Button and spread.get_child(0).rotation!=0,"Materials are scattered paper instead of button rows")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://ui_material_collage.png")
	paper.canvas._drop_data(Vector2(400,150),{"residency_material":note_id})
	check(paper.canvas.pieces.size()==2,"Collected material can enter composition")
	for mode in ["notebook","gallery","sound_library","pause","settings"]:
		paper.mode=mode; paper.build(); check(paper.body.size==Vector2(1340,750),"Consistent frame "+mode)
	if OS.get_cmdline_user_args().has("--screenshots"):
		for tab in ["requirements","personal","days","final"]:
			paper.mode="dossier"; paper.archive_tab=tab; paper.build()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://ui_"+tab+".png")
		print("UI captures: ",ProjectSettings.globalize_path("user://"))
	var state = root.get_node("GameState")
	check(not residency.submit_free_application().ok,"Early submission rejected")
	state.current_day=7
	var original_marks: Array = state.confirmed_residents.duplicate()
	state.confirmed_residents.clear()
	for i in 12: state.confirmed_residents.append("test_"+str(i))
	var data: Dictionary = residency.state()
	data.free_pages.life=[{"kind":"text","text":"海风","x":200,"y":100}]
	data.free_pages.notebook=[{"kind":"text","text":"只给自己看","x":200,"y":100}]
	for i in 7: data.free_pages["day_%d" % (i+1)]=[{"kind":"text","text":"今日","x":200,"y":100}]
	data.final_answers={"0":"抵达","1":"人","2":"海","3":"今天","4":"邻居","signature":"A"}
	check(residency.submit_free_application().ok,"Complete free application submits")
	check(root.get_node("ChapterSystem").residency_audit("A").passed,"Ending recognizes submitted free-paper application")
	check(not data.submitted.snapshot.free_pages.has("notebook"),"Private notebook never enters application snapshot")
	paper.mode="dossier"; paper.archive_tab="personal"; paper.build()
	check(paper.canvas.read_only,"Submitted archive is sealed")
	paper.mode="notebook"; paper.build()
	check(not paper.canvas.read_only,"Private notebook remains writable")
	state.confirmed_residents.assign(original_marks)
	paper.queue_free()
	await process_frame
	root.get_node("ChapterSystem").start_new_game("A")
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.5).timeout
	var shell: Control
	for child in current_scene.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("gameplay_shell.gd"): shell=child
	check(is_instance_valid(shell),"Playable scene uses living object shell")
	if is_instance_valid(shell):
		shell.time_notice_age=8; shell._process(.01)
		check(not shell.folder.visible and not shell.clock_label.visible and not shell.next_button.visible,"Exploration has no permanent HUD")
		shell.open_paper("dossier")
		await process_frame
		check(is_instance_valid(shell.overlay),"Archive opens in live scene")
		if OS.get_cmdline_user_args().has("--screenshots"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://ui_live_archive.png")
		shell.overlay.close()
		await process_frame
		check(not shell._blocked(),"Closing archive releases exploration")
	print("LIVING UI failures=",failures)
	quit(failures)
