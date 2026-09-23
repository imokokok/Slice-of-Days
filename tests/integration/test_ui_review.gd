extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
	else: print("PASS ",message)
func settle() -> void: await process_frame; await process_frame
func click(node: Control) -> void:
	var at := node.get_global_transform_with_canvas()*(node.size*.5)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=at; event.global_position=at; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func snap(name: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/review-captures")
	root.get_texture().get_image().save_png("res://.runtime/review-captures/"+name+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gs=root.get_node("GameState"); var save=root.get_node("SaveManager"); var residency=root.get_node("ResidencySystem")
	if OS.get_cmdline_user_args().has("--reload-only"):
		check(save.load_game("user://ui_review.json"),"Fresh process loads the UI review save")
		var pieces: Array=residency.state().free_pages.collage
		check(pieces.size()==2 and pieces[0].id!=pieces[1].id,"Both independently placed IDs survive restart")
		check(pieces.any(func(p):return p.rotation>.1 and p.scale>1.0 and p.x>400),"Position, scale and rotation survive restart")
		check(pieces.all(func(p):return p.page=="collage" and not p.source_asset.is_empty()),"Page and real source references survive restart")
		print("UI_REVIEW_RELOAD: ",checks," checks / ",failures," failures"); quit(failures); return
	root.get_node("ChapterSystem").start_new_game()
	gs.current_location="cafe"; gs.current_minute=660; gs.shared_state.map_arrival="cafe"
	change_scene_to_file("res://scenes/town_day.tscn"); await create_timer(.5).timeout
	var shell=current_scene.get_node("GameplayShell")
	var economy=root.get_node("EconomySystem")
	check(economy.set_cart_quantity("grocery","misprint_postcard",1).ok,"Real shop offers the collage postcard")
	check(economy.purchase_cart("grocery").ok,"Postcard is bought through the real checkout")
	residency._sync_sources()
	var collected: Array=residency.state().materials.values().filter(func(m):return str(m.id).begins_with("collage_"))
	check(collected.size()==1,"Purchased paper reaches the actual material library once")
	if collected.is_empty(): quit(1); return
	var source_id := str(collected[0].id)
	residency._sync_sources(); check(residency.state().materials.values().filter(func(m):return str(m.id)==source_id).size()==1,"Repeated sync does not duplicate a paper")
	await click(shell.get_node("Pocket_notebook"))
	check(is_instance_valid(shell.overlay),"Mouse click opens notebook")
	if not is_instance_valid(shell.overlay): quit(1); return
	var paper=shell.overlay
	await click(paper.body.get_node("OpenCollage"))
	check(is_instance_valid(paper.canvas),"Visible notebook entrance opens the real collage editor")
	if not is_instance_valid(paper.canvas): quit(1); return
	await click(paper.body.get_node("AddCollageMaterial"))
	check(is_instance_valid(paper.detail),"Visible Add Material button opens the material tray")
	if not is_instance_valid(paper.detail): quit(1); return
	var cutout=paper.detail.find_child("Material_"+source_id,true,false)
	check(cutout!=null,"Actual purchased postcard has an independently clickable cutout")
	if cutout==null: quit(1); return
	await click(cutout)
	check(paper.canvas.pieces.size()==1,"One ordinary mouse click places the real paper")
	if paper.canvas.pieces.is_empty(): quit(1); return
	check(not is_instance_valid(paper.detail),"Placement closes the tray without hiding the editor")
	var piece: Control=paper.canvas.item_nodes.values()[0]
	await click(piece)
	var start := piece.get_global_transform_with_canvas()*(piece.size*.5)
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.position=start; press.pressed=true; root.push_input(press,true)
	await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=start+Vector2(154,39); motion.relative=Vector2(154,39); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion,true)
	await process_frame
	press.position=motion.position; press.pressed=false; root.push_input(press,true); await settle()
	check(paper.canvas.pieces[0].x>400,"Actual mouse drag moves the placed material")
	paper.canvas.transform_selected("rotate_right"); paper.canvas.transform_selected("larger")
	var first: Dictionary=paper.canvas.pieces[0].duplicate(true)
	await click(paper.body.get_node("AddCollageMaterial")); await click(paper.detail.find_child("Material_"+source_id,true,false))
	check(paper.canvas.pieces.size()==2 and paper.canvas.pieces[0].id!=paper.canvas.pieces[1].id,"Adding another copy produces a distinct placed object")
	paper.canvas.transform_selected("back")
	check(paper.canvas.pieces[1].id==first.id,"Change Layer changes persisted ordering")
	await snap("collage")
	paper.close(); await settle()
	await click(shell.get_node("Pocket_notebook")); paper=shell.overlay; await click(paper.body.get_node("OpenCollage"))
	check(paper.canvas.pieces.size()==2 and paper.canvas.pieces.any(func(p):return p.id==first.id and p.x==first.x and p.rotation==first.rotation),"Closing and reopening retains collage geometry")
	check(save.save_game("user://ui_review.json"),"Collage saves through the production save system")
	paper.close(); await settle()
	await click(shell.get_node("Pocket_map")); paper=shell.overlay
	check(paper.map_board.get_children().filter(func(n):return n is Button).size()==15,"Map has all fifteen real independent location buttons")
	await snap("map")
	await click(paper.map_board.get_node("Destination_record_store"))
	check(paper.map_selected=="record_store" and paper.body.has_node("MapDetails"),"Map marker opens actual destination information")
	paper.close(); await settle()
	await click(shell.get_node("Pocket_recorder"))
	var recorder=shell.tool
	await click(recorder.face.get_node("RecordToggle")); await create_timer(2.5).timeout
	check(recorder.recorder.capturing and recorder.recorder.frame_count>0,"Recording receives real audio frames")
	check(recorder.live_screen.frames_seen>20 and recorder.live_screen.energy>0,"Live picture updates and reacts to captured audio")
	await snap("live-recorder")
	await click(recorder.face.get_node("RecordToggle"))
	check(recorder.saved and recorder.playback.stream!=null,"Live view preserves actual recording save")
	recorder.finish_for_exit(); await settle()
	gs.current_minute=1080; current_scene.street.camera_x=5960; current_scene.street.player_x=6630
	current_scene.street.set_process(false)
	await snap("lighthouse-transition")
	print("UI_REVIEW: ",checks," checks / ",failures," failures"); quit(failures)
