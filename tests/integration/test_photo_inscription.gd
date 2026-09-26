extends SceneTree
var failures := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)

func screenshot(file: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(file))==OK,"QA screenshot is saved: "+file)

func mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=at; event.global_position=at
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	root.push_input(event,true)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	output=OS.get_environment("SOLMERE_TEST_OUTPUT")
	if not output.is_empty(): check(DirAccess.make_dir_recursive_absolute(output)==OK,"The QA output folder is available")
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("ChapterSystem").start_new_game()
	var state: Node=root.get_node("GameState")
	var film: Node=root.get_node("FilmSystem")
	var save: Node=root.get_node("SaveManager")
	var photo_font: Font=preload("res://scripts/photography/photo_style.gd").theme().default_font
	for character in "杂货店摄影拍照写字": check(photo_font.has_char(character.unicode_at(0)),"The photography theme includes the Chinese glyph "+character)
	photo_font=null
	state.current_location="cafe"; state.current_minute=600
	check(film.acquire_camera(false).ok,"The actual camera exchange starts the test")
	var test_root := "user://tests/photo_inscription_"+Crypto.new().generate_random_bytes(6).hex_encode()
	film.capture_root=test_root.path_join("captures")
	var store := PhotoLibrary.new()
	store.root_path=test_root.path_join("photos")
	var source: Image
	if ResourceLoader.exists("res://art/scene_atlas/01.jpg"):
		var texture: Texture2D=load("res://art/scene_atlas/01.jpg")
		source=texture.get_image()
	if source==null or source.is_empty():
		source=Image.create(640,360,false,Image.FORMAT_RGB8); source.fill(Color("80968c"))
	source.resize(640,360)
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var camera = load("res://scripts/town_sound/PocketCamera.gd").new()
	camera.source=source; camera.library=store
	camera.context={"location":"cafe","day":1,"role":"A","game_minute":600}
	stage.add_child(camera)
	await process_frame
	await process_frame
	camera.find_child("ZoomIn",true,false).pressed.emit()
	check(is_equal_approx(camera.zoom_value,1.3) and camera.cropped_image().get_width()<source.get_width(),"The rounded zoom control changes the real optical crop")
	camera.find_child("ZoomOut",true,false).pressed.emit()
	check(is_equal_approx(camera.zoom_value,1.0),"The zoom-out control restores normal magnification")
	var centered: Rect2i=camera.crop_rect()
	check(centered.position.y>0 and centered.end.y<source.get_height(),"Normal magnification reserves room for vertical composition")
	mouse_button(camera.find_child("PanUp",true,false).get_global_rect().get_center(),true)
	mouse_button(camera.find_child("PanUp",true,false).get_global_rect().get_center(),false)
	check(camera.crop_rect().position.y<centered.position.y,"A real mouse click on Up moves the photograph crop upward at 1x")
	await screenshot("photo-pan-up.png")
	camera.find_child("PanDown",true,false).pressed.emit()
	check(camera.crop_rect()==centered,"Down reverses the upward composition change")
	var down := InputEventKey.new(); down.keycode=KEY_DOWN; down.physical_keycode=KEY_DOWN; down.pressed=true
	root.push_input(down,true)
	check(camera.crop_rect().position.y>centered.position.y,"The keyboard Down arrow moves the real crop downward")
	down.pressed=false; root.push_input(down,true)
	await screenshot("photo-pan-down.png")
	camera.find_child("Recenter",true,false).pressed.emit()
	mouse_button(Vector2(800,450),true)
	check(camera.dragging,"The viewfinder receives a real pointer press for dragging")
	var drag := InputEventMouseMotion.new(); drag.position=Vector2(800,360); drag.global_position=drag.position
	drag.relative=Vector2(0,-90); drag.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag,true)
	mouse_button(Vector2(800,360),false)
	check(camera.crop_rect().position.y>centered.position.y and not camera.dragging,"Dragging vertically moves the actual crop and mouse release ends the drag")
	camera.find_child("PanLeft",true,false).pressed.emit()
	check(camera.crop_rect().position.x<centered.position.x,"Left moves the horizontal composition")
	for _step in 12: camera.find_child("PanDown",true,false).pressed.emit()
	check(camera.crop_rect().end.y<=source.get_height() and camera.pan.y==1.0,"Panning stops at the photograph edge without exposing blank pixels")
	camera.find_child("ZoomIn",true,false).pressed.emit()
	var zoomed: Rect2i=camera.crop_rect()
	camera.find_child("PanUp",true,false).pressed.emit()
	check(camera.crop_rect().position.y<zoomed.position.y,"Vertical composition also moves at enlarged magnification")
	camera.find_child("Recenter",true,false).pressed.emit()
	check(camera.pan==Vector2(.5,.5),"The center control restores the composition")
	var before_right: Rect2i=camera.crop_rect()
	camera.find_child("PanRight",true,false).pressed.emit()
	check(camera.crop_rect().position.x>before_right.position.x,"Right adjusts the framing before capture")
	await screenshot("photo-cartoon-viewfinder.png")
	var expected_shot: Image=camera.cropped_image()
	camera.take_photo()
	await create_timer(.5).timeout
	check(is_instance_valid(camera.capture_card),"The real shutter opens a writable white-border print")
	if not is_instance_valid(camera.capture_card): quit(1); return
	check(camera.capture_card.print_view.image.get_data()==expected_shot.get_data(),"The shutter captures exactly the moved composition shown in the viewfinder")
	check(camera.capture_card.print_view.note_input.get_parent()==camera.capture_card.print_view,"Writing happens inside the photo's white border")
	var note := "海边的风很轻。今天想记住这扇窗。"
	camera.capture_card.print_view.note_input.text=note
	camera.capture_card._update_status()
	var typing := InputEventKey.new()
	typing.keycode=KEY_C; typing.physical_keycode=KEY_C; typing.pressed=true
	camera._input(typing)
	check(not camera.is_queued_for_deletion(),"Typing C in a caption cannot close the camera")
	var used: int=film.active_roll().exposures_used
	camera.take_photo()
	check(int(film.active_roll().exposures_used)==used,"Writing cannot accidentally expose another frame")
	await screenshot("photo-after-shutter.png")
	camera.capture_card._save()
	await process_frame
	check(not camera.shutter.disabled and not is_instance_valid(camera.capture_card),"Saving returns to the viewfinder")
	check(film.active_roll().captures.back().notes==note,"The inscription belongs to the actual exposed frame")
	check(state.artifacts.get("photos",[]).is_empty(),"Annotating a preview does not bypass film processing")
	check(save.save_game() and save.load_game() and film.active_roll().captures.back().notes==note,"Unprocessed inscriptions survive a full game-save reload")
	var roll_id: String=film.active_roll().id
	check(film.dropoff(roll_id,"rush").ok,"The annotated roll can be sent for processing")
	state.current_minute+=180
	check((await film.pickup(roll_id)).ok,"The annotated roll develops through the existing pickup flow")
	var photo: Dictionary=store.list_photos().front()
	check(photo.notes==note and film.photo(str(photo.photo_id)).notes==note,"Pickup carries the note into both the album file and game artifact")
	var original_bytes := store.load_photo(str(photo.photo_id)).get_data()
	camera.queue_free()
	await process_frame
	var album = load("res://scripts/town_sound/PhotoAlbum.gd").new()
	album.library=store; stage.add_child(album)
	await process_frame
	check(album.prints[str(photo.photo_id)].note_label.text==note,"The album thumbnail renders the saved inscription")
	await screenshot("photo-album.png")
	album._activate_photo(photo)
	await process_frame
	var edited := "那天走得很慢，窗边的灯却一直亮着。"
	album.inscription.print_view.note_input.text=edited
	album.inscription._update_status()
	await screenshot("photo-edit-white-border.png")
	album.inscription._save()
	await process_frame
	check(store.list_photos().front().notes==edited and album.prints[str(photo.photo_id)].note_label.text==edited,"Editing updates the committed metadata and visible album card")
	check(save.save_game() and save.load_game() and film.photo(str(photo.photo_id)).notes==edited,"Edited inscriptions survive reopening the game")
	check(store.load_photo(str(photo.photo_id)).get_data()==original_bytes,"White-border writing preserves the original photo pixels")
	check(not film.write_photo_note(str(photo.photo_id),"字".repeat(81),store) and store.list_photos().front().notes==edited,"Oversized writing is rejected without discarding the saved note")
	check(not film.write_photo_note("not-a-photo","不能写",store),"Unknown photo identifiers cannot create stray note records")
	var other := store.save_photo(source,{"role":"B","capture_id":"other-role"})
	check(not film.write_photo_note(str(other.photo_id),"不能改另一位的照片",store),"The other protagonist's photo cannot be overwritten")
	for index in 7: store.save_photo(source,{"role":"A","capture_id":"page-test-"+str(index),"notes":"第 %d 张旅途照片" % (index+1)})
	album.queue_free()
	await process_frame
	var pages = load("res://scripts/town_sound/PhotoAlbum.gd").new()
	pages.library=store; stage.add_child(pages)
	await process_frame
	check(pages.prints.size()==8 and not pages.next_button.disabled,"The two-page album shows eight real photos and exposes the next page")
	var first_ids: Array=pages.prints.keys()
	await screenshot("photo-cartoon-album-full.png")
	pages.next_button.pressed.emit()
	check(pages.page==1 and pages.prints.size()==1 and pages.next_button.disabled,"The final album page shows the remaining photo exactly once")
	check(not first_ids.has(pages.prints.keys().front()),"Turning the page does not duplicate a photograph")
	pages.previous_button.pressed.emit()
	check(pages.page==0 and pages.prints.keys()==first_ids,"Returning a page preserves every photo identity")
	root.get_node("WorldSound").cue_pool.stop_bus("SoundEffects")
	for voice in root.get_node("WorldSound").cue_pool.get_children():
		if voice is AudioStreamPlayer: voice.stop(); voice.stream=null
	await create_timer(.1).timeout
	stage.queue_free()
	await process_frame
	await process_frame
	print("PHOTO_INSCRIPTION_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
