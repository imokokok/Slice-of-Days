extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame; await create_timer(.3).timeout
func snapshot(id: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/reference-paper-review/"+id+".png")
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/reference-paper-review"))
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gs=root.get_node("GameState"); var router=root.get_node("SceneRouter"); var economy=root.get_node("EconomySystem")
	root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("B",2,true)
	gs.current_location="night_market"; gs.current_minute=720; gs.money=500; router.active_space_id="restaurant"
	change_scene_to_file("res://scenes/interactive_space.tscn"); await settle()
	economy.open_counter(current_scene,"restaurant"); await settle()
	var panel=get_nodes_in_group("economy_paper")[0]
	var accept=panel.find_child("AcceptProcurement",true,false)
	check(accept!=null and not accept.disabled,"An actionable procurement button exists before accepting the list")
	await snapshot("restaurant-list")
	accept.pressed.emit(); await settle()
	check(not economy.active_order().is_empty(),"Clipboard accepts and persists the real procurement order")
	check(panel.find_child("DeliverProcurement",true,false).disabled,"The clipboard cannot deliver missing ingredients")
	gs.current_location="produce_stall"
	for id in ["tomato","herbs","sea_beans"]: check(economy.purchase("produce_stall",id).ok,"Purchase actual "+id)
	gs.current_location="night_market"; panel.status=""; panel.build(); await settle()
	check(not panel.find_child("DeliverProcurement",true,false).disabled,"Delivery enables when the actual ingredients are held")
	var before: int=gs.money
	panel.find_child("DeliverProcurement",true,false).pressed.emit(); await settle()
	check(economy.active_order().delivered and gs.money>before,"Delivery through the new UI reimburses the actual receipts")
	check(panel.find_child("StartRestaurantWork",true,false)!=null,"Work action remains accessible below the scrolled content")
	var footer=panel.find_child("StartRestaurantWork",true,false)
	var receipt_scroll=panel.find_child("ProcurementReceipts",true,false).get_parent()
	check(not footer.get_global_rect().intersects(receipt_scroll.get_global_rect()),"Receipts never obscure the persistent work button")
	await snapshot("restaurant-ready")
	root.size=Vector2i(960,540); await settle()
	check(root.get_visible_rect().encloses(footer.get_global_rect()),"The work button remains inside the viewport at 960 by 540")
	await snapshot("restaurant-small")
	root.size=Vector2i(1280,720); panel.queue_free(); await settle()
	router.active_space_id=""; gs.current_location="cafe"; gs.current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	var hud=current_scene.get_node("GameplayShell")
	check(hud.clock_label.text.contains(str(gs.money)),"HUD ticket shows the real balance")
	var visible_objects: Array=hud.pocket_objects.filter(func(item): return item.visible)
	for i in visible_objects.size()-1:
		check(not visible_objects[i].get_global_rect().intersects(visible_objects[i+1].get_global_rect()),"Visible owned objects have independent click targets "+str(i))
	check(not hud.hints.get_global_rect().intersects(hud.pocket_objects.back().get_global_rect()),"The context action does not overlap the bottom inventory")
	await snapshot("street-hud")
	hud.open_paper("pause"); await settle()
	check(paused and is_instance_valid(hud.overlay),"Cassette pause actually pauses the world")
	var pause=hud.overlay
	await snapshot("pause-cassette")
	pause.find_child("Cassette_settings",true,false).pressed.emit(); await settle()
	check(pause.mode=="settings" and paused,"Settings opens inside the same paused folio")
	var settings=root.get_node("SettingsSystem")
	var volume: float=settings.music_volume()
	var slider=pause.find_child("music_volume",true,false)
	slider.value=37
	check(settings.music_volume()==37,"The cassette slider changes real music volume")
	slider.value=volume
	await snapshot("settings-cassette")
	var values=settings.values.duplicate(true)
	pause.find_child("Cassette_motion",true,false).pressed.emit(); await settle()
	check(settings.reduced_motion()!=bool(values.get("reduced_motion",false)),"The motion option changes the real setting")
	settings.set_reduced_motion(bool(values.get("reduced_motion",false)))
	pause.find_child("Cassette_back",true,false).pressed.emit(); await settle()
	pause.find_child("Cassette_resume",true,false).pressed.emit(); await settle()
	check(not paused and not is_instance_valid(hud.overlay),"Continue closes the cassette and resumes play")
	print("REFERENCE_PAPER_UI: ",checks," checks, ",failures," failures")
	quit(failures)
