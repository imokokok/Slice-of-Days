extends SceneTree
var gs
var router
var folder := "res://.runtime/open-source-polish/captures"
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await create_timer(.22).timeout
func shot(id: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Solmere · 开源素材与交互复查")
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter")
	change_scene_to_file("res://scenes/main_menu.tscn"); await shot("01-menu")
	current_scene._show_credits(); await shot("02-empty-credits"); current_scene._hide_modal()
	root.get_node("ChapterSystem").start_new_game()
	gs.current_location="residence"; router.town_day(.01); await settle()
	current_scene.set_process(false)
	await shot("03-street")
	var shell=current_scene.get_node("GameplayShell")
	shell.open_paper("dossier"); await shot("04-archive"); shell.overlay.close(); await settle()
	shell.open_paper("map"); await shot("05-map"); shell.overlay.close(); await settle()
	shell.open_paper("pause"); await shot("06-cassette"); shell.overlay.mode="settings"; shell.overlay.build(); await shot("07-settings"); shell.overlay.close(); await settle()
	shell.open_tool("recorder"); await settle()
	var recorder=shell.tool
	recorder.record_button.pressed.emit(); await create_timer(1.5).timeout; await shot("08-live-recording")
	recorder.record_button.pressed.emit(); await shot("09-recording-saved")
	recorder.queue_free(); await settle()
	gs.switch_to_role("B",2,true); gs.current_location="residence"; gs.current_minute=480
	router.enter_space("home_b"); await settle(); current_scene.set_process(false)
	shell=current_scene.get_node("GameplayShell"); shell.open_paper("notebook"); await shot("10-b-handwritten-agenda"); shell.overlay.close(); await settle()
	gs.current_location="cafe"; gs.current_minute=660
	router.town_day(.01); await settle(); current_scene.set_process(false)
	var shop=load("res://scripts/ui/shop_panel.gd").new(); current_scene.add_child(shop); await shot("11-shop")
	var item: Dictionary=shop.shop.items[0]
	shop._select(item); shop.purchase_button.pressed.emit(); await shot("12-checkout")
	shop.checkout_button.pressed.emit(); await shot("13-receipt")
	shop.queue_free(); await settle()
	var confirm=load("res://scripts/ui/components/confirm_sheet.gd").new(); confirm.heading="把今天收好"; confirm.description="这张确认单保留清楚的文字、足够的间距和完整的键盘操作。\n\n长说明在纸页内部滚动。Tab 不会跳到背后的场景。"; current_scene.add_child(confirm); await shot("14-confirm"); confirm.queue_free(); await settle()
	gs.switch_to_role("B",5,true); root.get_node("ChapterSystem").story().reveal_completed=true
	gs.current_location="record_store"; gs.current_minute=690; router.town_day(.01); await settle(); current_scene.set_process(false)
	current_scene._open_record_store(); await shot("15-record-shop")
	var records=current_scene.pocket_panel
	records.open_recorder(true); await settle()
	var work=records.modal.get_children().filter(func(child: Node): return child.get_script()!=null and child.get_script().resource_path.ends_with("StudioScreen.gd"))[0]
	work.find_child("ShopSource_wind",true,false).pressed.emit(); work.find_child("ShopSource_water",true,false).pressed.emit(); await shot("16-b-sound-materials")
	records.queue_free(); await settle()
	shell=current_scene.get_node("GameplayShell")
	shell.open_paper("settings")
	print("OPEN_POLISH_CAPTURE: 16 real game screens")
	if not OS.get_cmdline_user_args().has("--keep-open"): quit()
