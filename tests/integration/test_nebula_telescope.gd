extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var modules = root.get_node("GameplayModuleSystem")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location="park"; state.current_minute=1260
	router.gameplay_module("contemplation","street:park")
	await create_timer(2.0).timeout
	var host = current_scene
	var sky = host.experience
	check(sky is Node3D and sky.camera is Camera3D,"Real 3D telescope scene")
	check(sky.entries.size()==5,"Five observation sources with published/observed 3D structures")
	check(not sky.solmere_completed,"Old discoveries cannot complete a new session")
	check(sky.volume.sample_count>30000 and sky.volume.depth_range.y-sky.volume.depth_range.x>3,"Published model has real 3D depth")
	var before: Transform3D=sky.camera.transform
	var press := InputEventMouseButton.new()
	press.position=Vector2(750,380); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	root.push_input(press,true)
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(90,30); motion.position=press.position+motion.relative; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	press.pressed=false; root.push_input(press,true)
	await process_frame
	check(not sky.camera.transform.is_equal_approx(before),"Viewport mouse input rotates camera")
	check(not sky.chrome.visible and sky.sky_drag.is_visible_in_tree(),"Dragging removes all chrome without disabling the 3D viewport")
	var before_zoom: float=sky.distance
	var wheel := InputEventMouseButton.new(); wheel.position=Vector2(750,380); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true
	root.push_input(wheel,true); await process_frame
	check(sky.distance<before_zoom,"Mouse wheel zooms while the entire interface is hidden")
	var reveal := InputEventAction.new(); reveal.action="nebula_interface"; reveal.pressed=true
	root.push_input(reveal,true); await process_frame
	check(sky.chrome.visible,"Input Map action restores hidden observation controls")
	reveal.pressed=false; root.push_input(reveal,true)
	var saved: Vector2=sky.angles
	sky.select_nebula(0)
	check(sky.volume.sample_count>300000,"Official Pillars model imported at increased surface density")
	sky.select_nebula(2)
	check(sky.entries[2].model.ends_with("crab_observed.tscn") and sky.volume.components.size()>0,"Crab uses the published NASA geometry")
	sky.select_nebula(3)
	check(sky.entries[3].model.ends_with("cygnus_observed.tscn") and sky.volume.components.size()>0,"Cygnus Loop uses the published NASA geometry")
	sky.select_nebula(4)
	check(sky.entries[4].model.ends_with("casa_observed.tscn") and sky.volume.components.size()>=7,"Cassiopeia A retains independently coloured observed layers")
	sky.select_nebula(0)
	check(sky.get_node_or_null("StarField")==null,"Nebula inspection has no decorative starfield")
	check(sky.hint.get_theme_font_size("font_size")>=23,"Observation input remains readable")
	sky._toggle_science(); await process_frame
	check(is_instance_valid(sky.science_panel) and sky.entries[0].science.size()>=4,"A real scrollable science panel explains the selected nebula")
	var close_intro=sky.science_panel.find_child("CloseIntroduction",true,false)
	check(close_intro is Button,"Introduction has a close button outside its scrolling text")
	close_intro.pressed.emit(); await process_frame
	check(not is_instance_valid(sky.science_panel),"Introduction can be closed without exiting observation")
	sky.select_nebula(2)
	check(sky.volume.depth_range.y-sky.volume.depth_range.x>5,"Official Eta Carinae model retains its depth")
	sky.select_nebula(0)
	check(sky.angles.is_equal_approx(saved),"Each nebula keeps its view")
	sky.reset_view()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/nebula-orion.png")
		var valid_root: String=sky.library.root_path
		sky.library.root_path="res://project.godot/not-a-directory"
		await sky.collect()
		check(not sky.solmere_completed and sky.pending_image!=null,"Failed photo save retains image without awarding progress")
		sky.library.root_path=valid_root
		await sky.collect()
		check(sky.solmere_completed and sky.session_photos.size()==1,"Only successful real capture earns observation")
		var photo: Dictionary=sky.session_photos[0]
		check(FileAccess.file_exists(photo.developed_path),"Actual photograph exists")
		check(not root.get_node("FilmSystem").photo(photo.id).is_empty(),"Observation uses canonical gallery data")
		check(root.get_node("ResidencySystem").state().materials.has(photo.id),"Photo usable in portfolio")
		sky.open_gallery(); await process_frame
		check(is_instance_valid(sky.gallery),"Observation gallery opens")
		sky.close_gallery()
		sky._return()
		await create_timer(1.0).timeout
		check(current_scene.scene_file_path.ends_with("town_day.tscn"),"Cancel returns to world")
		check(not root.get_node("FilmSystem").photo(photo.id).is_empty(),"Cancel preserves earned photo")
		check(not modules.state_for("contemplation").completed,"Cancel does not silently complete gameplay")
		check(root.get_node("SaveManager").load_game(),"Saved game reloads")
		check(not root.get_node("FilmSystem").photo(photo.id).is_empty(),"Photo persists after load")
		router.gameplay_module("contemplation","street:park")
		await create_timer(1.0).timeout
		host=current_scene; sky=host.experience
		await sky.collect()
		var minute_before: int=state.current_minute
		sky.finish_requested.emit()
		await create_timer(1.0).timeout
		check(modules.state_for("contemplation").completed,"Finish produces existing module result")
		check(state.current_minute==minute_before+30,"Existing observation time cost charged once")
		check(not modules.latest_outcome("contemplation").interaction.photo_ids.is_empty(),"Outcome references canonical photo")
		router.gameplay_module("contemplation","street:park")
		await create_timer(1.0).timeout
		host=current_scene; sky=host.experience
	sky.open_constellations(); await process_frame
	var old=sky.legacy
	old.adjustment=old.solution; old.look_offset=Vector2.ZERO; old.update_layout()
	check(old.checker.measure(old.camera,old.data)<.05,"Original constellation puzzle is still solvable")
	var cancel := InputEventAction.new()
	cancel.action="ui_cancel"; cancel.pressed=true
	root.push_input(cancel,true)
	cancel.pressed=false; root.push_input(cancel,true)
	await process_frame
	check(current_scene==host and not is_instance_valid(sky.legacy),"One Escape returns from constellation to nebula, not out of the telescope")
	check(sky.camera.current,"Returning from constellation restores nebula camera")
	sky.select_nebula(0)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/nebula-pillars.png")
	sky.select_nebula(2)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/nebula-eta.png")
	sky.select_nebula(0)
	print("NEBULA PASS" if failures==0 else "NEBULA FAIL "+str(failures))
	if not OS.get_cmdline_user_args().has("--keep-open"): quit(failures)
