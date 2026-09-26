extends SceneTree
## Captures actual camera/film/album controls using an isolated demo save.
## Set SOLMERE_PHOTO_CAPTURE_DIR; use --fixed-fps 12 and -- --isolated-save.
var fps := 12
var frame_index := 0
var folder := ""
var timeline: Array = []
var caption: Label
var overlay: CanvasLayer
var cursor: DemoCursor
var library := PhotoLibrary.new()
var gs: Node
var film: Node

class DemoCursor extends Control:
	var clicking := false
	func _draw() -> void:
		if clicking: draw_circle(Vector2(4,4),22,Color("e9dca6",.55))
		var arrow := PackedVector2Array([Vector2.ZERO,Vector2(3,25),Vector2(10,17),Vector2(18,22),Vector2(22,17),Vector2(14,12),Vector2(24,8)])
		draw_colored_polygon(arrow,Color("fcfaf0"))
		var line := arrow.duplicate(); line.append(Vector2.ZERO)
		draw_polyline(line,Color("23332c"),2,true)

func _initialize() -> void:
	call_deferred("run")

func pause(seconds: float) -> void:
	for _frame in maxi(1,roundi(seconds*fps)):
		await process_frame
		RenderingServer.force_draw()
		var image := root.get_texture().get_image()
		if image.save_png(folder.path_join("frame%08d.png" % frame_index))!=OK:
			push_error("Could not save photo walkthrough frame"); quit(3); return
		frame_index+=1

func stage(title: String) -> void:
	caption.text=title
	timeline.append({"frame":frame_index,"stage":title})
	print("PHOTO_DEMO_STAGE ",frame_index," ",title)

func sound(cue: String) -> void:
	timeline.append({"frame":frame_index,"cue":cue})

func checkpoint(id: String) -> void:
	root.get_texture().get_image().save_png(folder.path_join("checkpoints").path_join(id+".png"))

func find_button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and not child.disabled and child.is_visible_in_tree() and not child.is_queued_for_deletion() and child.text.begins_with(prefix): return child
		var nested := find_button(child,prefix)
		if nested!=null: return nested
	return null

func click(button: Button, cue := "click") -> void:
	if button==null:
		push_error("Walkthrough button was not available"); quit(4); return
	cursor.position=button.get_global_rect().get_center()
	cursor.show(); cursor.queue_redraw()
	await pause(.35)
	cursor.clicking=true; cursor.queue_redraw()
	sound(cue)
	button.pressed.emit()
	await pause(.17)
	cursor.clicking=false; cursor.queue_redraw()
	await pause(.45)
	cursor.hide()

func write_text(field: TextEdit, text: String) -> void:
	field.grab_focus()
	field.text=""
	field.text_changed.emit()
	cursor.position=field.global_position+Vector2(8,18)
	cursor.show()
	await pause(.5)
	cursor.hide()
	for character in text:
		field.insert_text_at_caret(character)
		sound("focus")
		await pause(.12)

func drag_frame(camera: Control, from: Vector2, to: Vector2) -> void:
	cursor.position=from; cursor.show(); cursor.clicking=true; cursor.queue_redraw()
	var press := InputEventMouseButton.new(); press.position=from; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	camera.preview_frame.gui_input.emit(press)
	var previous := from
	for step in 18:
		var at := from.lerp(to,float(step+1)/18)
		var motion := InputEventMouseMotion.new(); motion.position=at; motion.relative=at-previous; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		camera.preview_frame.gui_input.emit(motion)
		cursor.position=at
		await pause(1.0/fps)
		previous=at
	press.position=to; press.pressed=false; camera.preview_frame.gui_input.emit(press)
	cursor.clicking=false; cursor.queue_redraw()
	await pause(.6)
	cursor.hide()

func setup_overlay() -> void:
	overlay=CanvasLayer.new(); overlay.layer=128; root.add_child(overlay)
	var bar := Panel.new(); bar.position=Vector2(270,3); bar.size=Vector2(1060,43)
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new(); face.bg_color=Color("182a24",.94); face.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel",face); overlay.add_child(bar)
	caption=Label.new(); caption.position=Vector2(16,6); caption.size=Vector2(1028,31)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://art/ui/fonts/xiaolai/Xiaolai-Regular.ttf"))
	caption.add_theme_font_size_override("font_size",23); caption.add_theme_color_override("font_color",Color("faf7ee"))
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; bar.add_child(caption)
	cursor=DemoCursor.new(); cursor.mouse_filter=Control.MOUSE_FILTER_IGNORE; cursor.hide(); overlay.add_child(cursor)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	folder=OS.get_environment("SOLMERE_PHOTO_CAPTURE_DIR")
	if folder.is_empty(): quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-fps="): fps=clampi(int(argument.trim_prefix("--capture-fps=")),2,24)
	DirAccess.make_dir_recursive_absolute(folder.path_join("checkpoints"))
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs=root.get_node("GameState"); film=root.get_node("FilmSystem")
	root.get_node("ChapterSystem").start_new_game()
	gs.current_location="cafe"; gs.current_minute=600
	if not film.acquire_camera(false).ok: push_error("Camera setup failed"); quit(5); return
	library.root_path="user://tests/photo_video_"+Crypto.new().generate_random_bytes(6).hex_encode()
	film.capture_root=library.root_path.path_join("negatives")
	gs.current_location="town_entrance"; gs.commit_active_role_state()
	change_scene_to_file("res://scenes/town_day.tscn")
	await process_frame
	await process_frame
	current_scene.set_process(false)
	setup_overlay()
	stage("01 / 取景 · 拍下小镇里的一刻")
	await pause(2)
	overlay.hide()
	await current_scene._open_pocket_camera()
	await process_frame
	overlay.show()
	var camera: Control=current_scene.pocket_panel
	camera.library=library
	await pause(2.5)
	stage("01 / 上下移动构图 · 1× 也可以调整位置")
	var original: Rect2i=camera.crop_rect()
	await click(camera.find_child("PanUp",true,false))
	if camera.crop_rect().position.y>=original.position.y: push_error("Up did not move the real frame"); quit(11); return
	await pause(1.2)
	checkpoint("01a-pan-up")
	await click(camera.find_child("PanDown",true,false))
	await click(camera.find_child("PanDown",true,false))
	if camera.crop_rect().position.y<=original.position.y: push_error("Down did not move the real frame"); quit(11); return
	await pause(1.2)
	checkpoint("01b-pan-down")
	await click(camera.find_child("Recenter",true,false))
	stage("01 / 拖动构图 · 上下左右自由移动")
	await drag_frame(camera,Vector2(850,490),Vector2(700,340))
	if camera.pan.y<=.5 or camera.pan.x<=.5: push_error("Dragging did not change both framing axes"); quit(11); return
	await pause(1.2)
	checkpoint("01c-drag-framing")
	await click(camera.find_child("Recenter",true,false))
	stage("01 / 圆形取景控件 · 放大与还原构图")
	await click(camera.find_child("ZoomIn",true,false))
	await pause(1.3)
	await click(camera.find_child("ZoomOut",true,false))
	await pause(1.3)
	checkpoint("01-viewfinder")
	await click(camera.shutter,"shutter")
	await pause(.7)
	if not is_instance_valid(camera.capture_card): push_error("No writable capture print"); quit(6); return
	stage("02 / 拍完照片 · 直接在下方白边写字")
	await pause(1.5)
	await write_text(camera.capture_card.print_view.note_input,"海边的风很轻。今天想记住这片海。")
	await pause(3)
	checkpoint("02-writing")
	stage("03 / 保存文字 · 随底片一起留在胶卷里")
	await click(camera.capture_card.save_button,"paper")
	await pause(1.8)
	await click(camera.finder_layer.get_node("CameraBack"))
	await pause(.4)
	gs.current_location="cafe"; gs.commit_active_role_state()
	var counter: Control=film.open_counter(current_scene)
	stage("04 / 摄影柜台 · 送洗这卷带有文字的底片")
	await pause(3)
	await click(find_button(counter,"加急"))
	await pause(2.5)
	checkpoint("03-processing-confirmation")
	await click(find_button(counter,"确认"))
	await pause(3)
	await click(find_button(counter,"收好小票"),"paper")
	await pause(2)
	stage("05 / 等待冲洗 · 演示跳过游戏内的 180 分钟")
	await pause(2)
	gs.current_minute+=180; gs.commit_active_role_state(); film.update_processing(); counter.rebuild()
	await pause(2.5)
	await click(find_button(counter,"拿回照片"),"paper")
	while counter.working: await pause(.5)
	await pause(2)
	checkpoint("04-picked-up")
	await click(find_button(counter,"返回"))
	var photos := library.list_photos()
	if photos.is_empty(): push_error("No developed photo"); quit(7); return
	var photo: Dictionary=photos.front()
	stage("06 / 打开相册 · 白边上的文字随照片保留下来")
	overlay.hide()
	await current_scene._open_pocket_camera()
	overlay.show()
	camera=current_scene.pocket_panel
	camera.library=library
	await pause(.8)
	await click(camera.find_child("OpenGallery",true,false),"paper")
	var album: Control=current_scene.pocket_panel
	if album==null or album.get_script()!=load("res://scripts/town_sound/PhotoAlbum.gd"):
		push_error("Camera gallery did not open the album"); quit(10); return
	if album.prints.size()!=photos.size(): push_error("Camera gallery lost its photo library"); quit(10); return
	await pause(3)
	checkpoint("05-album")
	await click(find_button(album,"翻看"),"paper")
	await pause(2)
	stage("07 / 再次编辑 · 为这一刻补上一句话")
	var revised := "那天走得很慢，海面却一直亮着。"
	await write_text(album.inscription.print_view.note_input,revised)
	await pause(3)
	checkpoint("06-revising")
	await click(album.inscription.save_button,"paper")
	await pause(2)
	await click(find_button(album,"返回"))
	stage("08 / 关闭相册、重新载入存档 · 再次确认文字")
	if not root.get_node("SaveManager").save_game() or not root.get_node("SaveManager").load_game():
		push_error("Photo demo save/reload failed"); quit(8); return
	await pause(1.5)
	album=load("res://scripts/town_sound/PhotoAlbum.gd").new()
	album.library=library; current_scene._show_pocket_panel(album)
	await pause(2)
	await click(find_button(album,"翻看"),"paper")
	await pause(3.5)
	if album.inscription.print_view.writing()!=revised: push_error("Reopened inscription differs"); quit(9); return
	checkpoint("07-reloaded")
	await click(album.inscription.save_button,"paper")
	await click(find_button(album,"返回"))
	stage("09 / 把写好字的照片摆在房间里")
	gs.current_location="residence"; gs.commit_active_role_state()
	root.get_node("SceneRouter").enter_space("home_a")
	while root.get_node("SceneRouter").transitioning: await pause(.25)
	current_scene.set_process(false)
	await pause(1.5)
	var actions: Control=film.open_photo_actions(str(photo.photo_id),current_scene)
	await pause(3)
	checkpoint("08-photo-actions")
	await click(find_button(actions,"摆在房间里"),"paper")
	await pause(2)
	await click(find_button(actions,"返回"))
	await pause(3.5)
	checkpoint("09-room-print")
	stage("完成 / 拍照 → 白边写字 → 冲洗 → 相册修改 → 保存与陈列")
	await pause(3)
	for cue in ["click","paper","focus","shutter"]:
		root.get_node("WorldSound").make_ui(cue).save_to_wav(folder.path_join(cue+".wav"))
	var file := FileAccess.open(folder.path_join("timeline.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":fps,"frames":frame_index,"events":timeline},"\t")); file.close()
	print("PHOTO_INSCRIPTION_WALKTHROUGH_COMPLETE frames=",frame_index," fps=",fps)
	quit()
