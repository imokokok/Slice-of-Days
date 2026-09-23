extends SceneTree
var failures:=0
var checks:=0
var gs: Node
var film: Node
var save: Node
func _initialize()->void: call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures+=1;push_error(label)
	else: print("PASS ",label)
func run()->void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):quit(1);return
	# Photo-action controls are located by their Chinese source captions.
	TranslationServer.set_locale("zh_CN")
	root.gui_disable_input=true
	gs=root.get_node("GameState")
	film=root.get_node("FilmSystem")
	save=root.get_node("SaveManager")
	var test_root:="user://v3_film_"+str(OS.get_process_id())
	film.capture_root=test_root+"/raw"
	film.library.root_path=test_root+"/developed"
	root.get_node("MetaExperience").catalog.toggles.marginalia=false
	root.get_node("ChapterSystem").start_new_game()
	gs.current_location="cafe"
	gs.current_minute=660
	check(not film.camera_available(false),"A starts without bypassing the camera purchase choice")
	film.notice_camera()
	var camera_money := int(gs.money)
	check(film.acquire_camera(false).ok and gs.money==camera_money-240,"A directly buys the used camera at the configured price")
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	current_scene.street.set_process(false)
	check(film.camera_available(false),"A's purchased visual tool is available in normal play")
	check(film.active_roll().film_type=="normal" and film.active_roll().exposures_used==0,"A's purchase includes one unused 24-exposure normal roll")
	var camera=load("res://scripts/town_sound/PocketCamera.gd").new()
	camera.source=Image.create(320,180,false,Image.FORMAT_RGB8)
	camera.source.fill(Color("68aeb8"))
	camera.library.root_path=film.library.root_path
	camera.context={"location":"cafe","title":"杂货店窗边"}
	current_scene.add_child(camera)
	await process_frame
	check(camera.focus_active and camera.finder_layer.visible,"Camera opens directly in the full-screen viewfinder")
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	camera._input(click)
	await process_frame
	check(camera.focus_active and camera.finder_layer.visible,"LMB raises the real viewfinder")
	var crop: Image=camera.cropped_image()
	check(crop.get_width()*9==crop.get_height()*16,"Saved frame matches the full-screen 16:9 viewfinder")
	camera._scroll(1)
	check(is_equal_approx(camera.zoom_value,1.3),"Scroll advances to 1.3x")
	camera._scroll(1)
	camera._scroll(1)
	check(is_equal_approx(camera.zoom_value,1.6),"Scroll is capped at 1.6x")
	var shutter:=InputEventKey.new()
	shutter.physical_keycode=KEY_SPACE
	shutter.keycode=KEY_SPACE
	shutter.pressed=true
	camera._input(shutter)
	check(film.active_roll().exposures_used==1,"Space consumes one exposure through the camera")
	check(camera.flash.modulate.a>0,"Shutter gives a short black mechanical frame")
	await create_timer(.26).timeout
	check(camera.flash.modulate.a<.01,"Black frame clears immediately")
	var small:=Image.create(96,64,false,Image.FORMAT_RGB8)
	small.fill(Color("b69265"))
	for i in 23: check(not film.capture(small,{"title":"真实曝光"},camera.library).is_empty(),"Exposure "+str(i+2)+" committed")
	var roll_id:=str(film.active_roll().id)
	check(film.active_roll().state=="EXPOSED_FULL" and film.active_roll().exposures_used==24,"24 shots fill one roll")
	check(film.capture(small,{}).is_empty(),"A full roll rejects exposure 25")
	check(gs.artifacts.get("photos",[]).is_empty(),"Unprocessed captures are absent from Gallery and Dossier")
	check(save.save_game() and save.load_game(),"Active roll persists through real save/load")
	check(film.active_roll().exposures_used==24,"Exposure count survives reload")
	camera.queue_free()
	await process_frame
	gs.current_location="cafe"
	var money:=int(gs.money)
	var dropped: Dictionary=film.dropoff(roll_id,"rush")
	check(dropped.ok and gs.money==money-42,"Rush drop-off charges the configured actual fee")
	check(film.active_roll().is_empty(),"Dropped-off roll leaves the camera")
	check(gs.artifacts.film_tickets.size()==1 and root.get_node("ResidencySystem").state().materials.has("processing_"+roll_id),"A real processing ticket enters Loose Papers")
	check(not film.dropoff(roll_id,"rush").ok and gs.money==money-42,"Repeated drop-off cannot charge again")
	check(not (await film.pickup(roll_id)).ok,"Processing cannot be picked up early")
	gs.spend_time(179)
	check(film.state().rolls[roll_id].state=="PROCESSING","179 game minutes are insufficient for Rush")
	gs.spend_time(1)
	check(film.state().rolls[roll_id].state=="READY_FOR_PICKUP","Actual clock makes Rush ready after 180 minutes")
	gs.current_location="bookstore"
	check(not (await film.pickup(roll_id)).ok,"Ready photos still require visiting the grocery counter")
	gs.current_location="cafe"
	check((await film.pickup(roll_id)).ok,"Counter pickup develops and hands over the real photographs")
	check(film.developed_photos().size()==24 and film.library.list_photos().size()==24,"All 24 developed photographs enter persistent Gallery")
	check(not (await film.pickup(roll_id)).ok and film.developed_photos().size()==24,"Duplicate pickup creates no extra copies or payment")
	var photo: Dictionary=film.developed_photos()[0]
	for key in ["roll_id","film_type","capture_path","developed_path","shown_to_npcs","used_in_collage","submitted_to_dossier"]: check(photo.has(key),"Developed metadata keeps "+key)
	check(FileAccess.file_exists(str(photo.capture_path)) and FileAccess.file_exists(str(photo.developed_path)),"Original capture and developed PNG both remain available")
	var residency=root.get_node("ResidencySystem")
	residency._sync_sources()
	check(residency.set_cover_photo(str(photo.id)),"A developed photo can be attached to the residency dossier cover")
	check(str(residency.state().cover_photo_id)==str(photo.id),"The selected dossier cover photo is saved in residency state")
	var dossier=load("res://scripts/residency/paper_overlay.gd").new()
	dossier.mode="dossier"
	dossier.tab="packet"
	current_scene.add_child(dossier)
	await process_frame
	check(is_instance_valid(dossier.find_child("DossierCoverPhoto",true,false)),"The residency dossier renders the attached photo on its cover")
	dossier.queue_free()
	await process_frame
	var actions=film.open_photo_actions(str(photo.id),current_scene)
	await process_frame
	press(actions,"带到拼贴桌")
	check(film.state().collage_selection==photo.id,"Photo action actually selects the copy for collage")
	gs.current_location="residence"
	actions.rebuild()
	press(actions,"摆在房间里")
	check(film.state().room_display.has(photo.id),"Photo action stores the paper copy in the actual room")
	actions.queue_free()
	await process_frame
	var display=load("res://scripts/photography/room_photo_display.gd").new()
	current_scene.add_child(display)
	check(display.get_child_count()>0,"Room photo string renders the saved photo copy")
	check(film.mark_photo_use(str(photo.id),"npc","maya") and film.photo(str(photo.id)).shown_to_npcs.has("maya"),"Showing a photograph records a real NPC encounter")
	var letter=load("res://extensions/collage_letter/Main.tscn").instantiate()
	letter.save_path=test_root+"/letter.json"
	letter.preview_path=test_root+"/letter.png"
	letter.stage="WORKBENCH"
	current_scene.add_child(letter)
	await create_timer(.6).timeout
	var index:=-1
	for i in letter.materials.size():
		if str(letter.materials[i].get("photo_id",""))==str(photo.id): index=i;break
	check(index>=0,"Real collage workbench reads developed photos as printable sources")
	if index>=0:
		check(letter.material_images[index].get_pixel(150,60)!=Color("faf7ee"),"RGB camera image is printed into the RGBA paper copy")
		letter.browser_category="全部"; letter.browser_index=index; letter.take_material()
		var original = letter.active
		original.position=Vector2(205,685)
		letter.use_tool("mat"); letter.take_knife()
		letter._split_focused(PackedVector2Array([Vector2(20,20),Vector2(160,20),Vector2(160,120),Vector2(20,120)]),"knife")
		letter.save_game()
		check(str(letter.active.photo_id)==str(photo.id) and not letter.active.cut_history.is_empty(),"Existing craft knife cuts the player's photo")
		var snapshot: Dictionary=letter.snapshot(); letter.restore_snapshot(snapshot)
		check(letter.papers.get_children().any(func(piece: Node) -> bool: return str(piece.photo_id)==str(photo.id)),"Photo source IDs survive workshop restore")
		check(film.photo(str(photo.id)).used_in_collage,"Saving collage writes real photo usage metadata")
		check(film.library.load_photo(str(photo.id))!=null,"Cutting a paper copy preserves the Gallery original")
	letter.queue_free()
	display.queue_free()
	await process_frame
	root.get_node("ChapterSystem").start_new_game()
	gs.switch_to_role("B",2,true)
	gs.current_location="cafe"
	gs.current_minute=660
	check(not film.camera_available(false),"B's fresh game starts without the camera")
	film.notice_camera()
	var before_time:=int(gs.current_minute)
	var exchange: Dictionary=film.acquire_camera(true)
	check(exchange.ok,"B can help label real old stock to receive the used camera")
	check(exchange.receipt.kind=="handover" and exchange.receipt.total==0 and exchange.receipt.help_minutes==25,"Camera exchange hands over a real non-cash receipt")
	check(gs.current_minute==before_time+25 and film.active_roll().film_type=="expired","B help consumes 25 minutes and gives one expired-stock roll")
	check(not film.acquire_camera(true).ok and gs.current_minute==before_time+25,"Repeated help cannot repeat time or camera rewards")
	film.capture(small,{"title":"旧库存试拍"},film.library)
	var expired_id:=str(film.active_roll().id)
	money=int(gs.money)
	check(film.dropoff(expired_id,"standard").ok and gs.money==money-12,"Shop help applies the first Standard price naturally")
	check(int(film.state().rolls[expired_id].ready_day)==gs.current_day+1 and int(film.state().rolls[expired_id].ready_minute)==600,"Standard pickup is actually scheduled for next morning")
	check(save.save_game() and save.load_game() and film.state().rolls[expired_id].state=="PROCESSING","Processing and first-discount state survive reload")
	print("V3_FILM ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(failures)

func press(parent: Node,text: String)->void:
	for child in parent.get_children():
		if child is Button and child.text==text: child.pressed.emit();return
		press(child,text)
