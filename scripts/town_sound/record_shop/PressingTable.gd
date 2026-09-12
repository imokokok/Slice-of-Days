extends Control
var room: Control
var model: Arrangement
var audio: AudioStreamWAV
var profile: Dictionary
var seed_value := 23817
var step := 0
var locked := false
var dragging := false
var drag_position := Vector2.ZERO
var cover: Image
var texture: ImageTexture
var title_input: LineEdit
var artist_input: LineEdit
var note_input: LineEdit
var instructions: Label
var next_button: Button
var preview: VisualCanvas
var cover_viewport: SubViewport
var cover_container: SubViewportContainer
var crop_overlay: Control
var crop_slider: HSlider
var cover_time := 0.0
var sound: AudioStreamPlayer
var saved_record: Dictionary = {}
var library := LocalRecordLibrary.new()
var progress := 0.0
var holding := false
var hold_seconds := 0.0
var stamp_picked := false
var serial := 1
var summary_label: Label
var cover_sources: HBoxContainer
var pending_photo: Image
var photo_preview: TextureRect
var cover_source := "visual"
var source_photo_id := ""
const STEPS := ["01 / 签下唱片信息", "02 / 留下封面画面", "03 / 打印纸质封套", "04 / 对齐中心标签", "05 / 压制与冷却", "06 / 收进防尘内袋", "07 / 装入封面外套", "08 / 封住袋口", "09 / 盖下收录印章", "10 / 插入编号卡", "11 / 交给唱片店老板", "LOCAL RECORDINGS"]
const HINTS := ["给作品写下标题、作者和一句话。", "拖动滑条取景，暂停后留下这一帧。", "点击打印机的绿色按钮，看封套从出纸口慢慢出来。", "拿起右侧圆形标签，对准唱片中心孔后松手。", "按住机器右侧红色把手 1 秒，等待压盘下降、刻纹与冷却。", "握住唱片边缘，拖向右侧内袋开口。", "拿起装好唱片的内袋，滑进右侧印好封面的外套。", "把小圆封签移到外套上沿，不要贴在封面正中。", "先点右侧木柄印章拿起，再点封套右下角落章。", "将右侧编号纸卡插进左侧封套下沿的卡槽。", "把完整唱片递到柜台托盘，老板会接过并上架。", "这段声音已经在店里有了一个位置。"]

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1000, 720)
	serial = library.list_records().size() + 1
	var column := VBoxContainer.new()
	column.position = Vector2(36, 28)
	column.size.x = 970
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(room.studio.label("SOLMERE / LOCAL PRESSING", 28))
	instructions = room.studio.label("老板：行，这个我收。慢慢包，架子上有位置。", 18)
	column.add_child(instructions)
	title_input = LineEdit.new()
	title_input.placeholder_text = "TITLE / 唱片标题"
	title_input.max_length = 60
	column.add_child(title_input)
	artist_input = LineEdit.new()
	artist_input.placeholder_text = "ARTIST / 作者"
	artist_input.max_length = 40
	column.add_child(artist_input)
	note_input = LineEdit.new()
	note_input.placeholder_text = "ONE LINE NOTE / 一句话，留空也可以"
	note_input.max_length = 160
	column.add_child(note_input)
	summary_label = room.studio.label("", 17)
	column.add_child(summary_label)
	summary_label.hide()
	cover_sources = HBoxContainer.new()
	column.add_child(cover_sources)
	cover_sources.add_child(room.studio.button("选择程序画面", func() -> void:
		pending_photo = null
		cover_source = "visual"
		source_photo_id = ""
		photo_preview.hide()
		cover_container.show()
		next_button.text = "暂停并使用当前帧"))
	cover_sources.add_child(room.studio.button("从本地相册选封面", select_photo_cover))
	cover_sources.hide()
	next_button = room.studio.button("完成命名", advance)
	column.add_child(next_button)
	cover_container = SubViewportContainer.new()
	cover_container.position = Vector2(50, 350)
	cover_container.size = Vector2(480, 270)
	cover_container.stretch = true
	cover_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(cover_container)
	cover_viewport = SubViewport.new()
	cover_viewport.size = Vector2i(480, 270)
	cover_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cover_container.add_child(cover_viewport)
	preview = VisualCanvas.new()
	preview.size = Vector2(480, 270)
	preview.configure(audio, model.prompt, seed_value)
	cover_viewport.add_child(preview)
	cover_container.hide()
	photo_preview = TextureRect.new()
	photo_preview.position = Vector2(50, 350)
	photo_preview.size = Vector2(480, 270)
	photo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_preview.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(photo_preview)
	photo_preview.hide()
	crop_slider = HSlider.new()
	crop_slider.position = Vector2(50, 630)
	crop_slider.size = Vector2(480, 30)
	crop_slider.min_value = 0
	crop_slider.max_value = 1
	crop_slider.value = 0.5
	crop_slider.tooltip_text = "封面裁切：左右移动取景"
	add_child(crop_slider)
	crop_slider.hide()
	crop_overlay = Control.new()
	crop_overlay.position = Vector2(50, 350)
	crop_overlay.size = Vector2(480, 270)
	crop_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	crop_overlay.draw.connect(func() -> void:
		if step == 1:
			crop_overlay.draw_rect(Rect2(crop_slider.value * 210, 0, 270, 270), Color("fff8e5"), false, 3))
	add_child(crop_overlay)
	crop_slider.value_changed.connect(func(_value: float) -> void: crop_overlay.queue_redraw())
	sound = AudioStreamPlayer.new()
	sound.volume_db = -12.0
	add_child(sound)
	queue_redraw()

func advance() -> void:
	if locked: return
	if step == 0:
		title_input.text = title_input.text.strip_edges()
		artist_input.text = artist_input.text.strip_edges()
		if title_input.text.is_empty(): title_input.text = "今天听见的东西"
		if artist_input.text.is_empty(): artist_input.text = "Anonymous"
		title_input.editable = false
		artist_input.editable = false
		note_input.editable = false
		title_input.hide()
		artist_input.hide()
		note_input.hide()
		summary_label.text = "「%s」  /  %s  ·  LOCAL-%04d" % [title_input.text, artist_input.text, serial]
		summary_label.show()
		step = 1
		cover_sources.show()
		crop_overlay.queue_redraw()
		cover_container.show()
		crop_slider.show()
		next_button.text = "暂停并使用当前帧"
	elif step == 1:
		locked = true
		await RenderingServer.frame_post_draw
		var frame: Image = pending_photo if pending_photo != null else cover_viewport.get_texture().get_image()
		var edge := mini(frame.get_width(), frame.get_height())
		cover = frame.get_region(Rect2i(int((frame.get_width() - edge) * crop_slider.value), 0, edge, edge))
		cover.resize(512, 512)
		texture = ImageTexture.create_from_image(cover)
		cover_container.hide()
		photo_preview.hide()
		cover_sources.hide()
		crop_slider.hide()
		crop_overlay.hide()
		locked = false
		step = 2
		next_button.text = "打印封面纸套"
	elif step >= 2 and step <= 10:
		await complete_action()
	elif step == 11:
		room.studio.show()
		room.queue_free()
	if step < 11:
		instructions.text = STEPS[step] + "\n" + HINTS[step]
	queue_redraw()

func complete_action() -> void:
	if locked: return
	locked = true
	progress = 0.0
	play_feedback()
	next_button.disabled = true
	if step < 10:
		var duration := 3.5 if step == 4 else (1.6 if step == 2 else 0.8)
		var motion := create_tween()
		motion.tween_property(self, "progress", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await motion.finished
	if step == 10:
		var payment := randi_range(80, 120)
		var tracks: Dictionary = {}
		var samples: Dictionary = {}
		for clip in model.clips:
			tracks[clip.track] = true
			samples[clip.sample_id] = true
		payment += (tracks.size() - 1) * 5
		if samples.size() >= 4: payment += randi_range(5, 15)
		payment += randi_range(5, 15) + randi_range(-10, 20)
		payment = clampi(payment, 60, 180)
		if saved_record.is_empty():
			saved_record = library.save_record({"title": title_input.text, "artist": artist_input.text,
				"one_line_note": note_input.text, "duration": audio.get_length(), "visual_prompt": model.prompt,
				"visual_profile": profile, "visual_seed": seed_value, "visual_version": 1, "source_sample_count": samples.size(),
				"cover_source": cover_source, "source_photo_id": source_photo_id,
				"payment": payment, "project_path": "user://projects/current.json"}, audio, cover)
		if saved_record.is_empty():
			instructions.text = library.last_error
			locked = false
			return
		instructions.text = "老板：我晚点再听一遍。\n正在把你的唱片放上 LOCAL RECORDINGS……"
		var tween := create_tween()
		tween.tween_property(self, "progress", 1.0, 3.5).set_trans(Tween.TRANS_CUBIC)
		await tween.finished
	step += 1
	locked = false
	next_button.disabled = false
	progress = 0
	stamp_picked = false
	var buttons := {3: "辅助操作：对齐标签", 4: "辅助操作：压下把手", 5: "辅助操作：滑入内袋", 6: "辅助操作：装进外套", 7: "辅助操作：贴下封签", 8: "辅助操作：拿起并盖章", 9: "辅助操作：插入编号卡", 10: "辅助操作：交给老板", 11: "返回 Studio"}
	next_button.text = buttons.get(step, "继续")
	if step == 11:
		instructions.text = "「%s」已上架  +%d / LOCAL RECORDING LICENSE\n游戏内余额：%d · 唱片已本地保存。公共库尚未配置，保持 Local Mode。" % [saved_record.title, saved_record.payment, library.money()]
	else:
		instructions.text = STEPS[step] + "\n" + HINTS[step]
	queue_redraw()

func select_photo_cover() -> void:
	if step != 1 or locked: return
	var album = load("res://scripts/town_sound/PhotoAlbum.gd").new()
	album.selection_mode = true
	album.photo_selected.connect(use_photo_cover)
	add_child(album)

func use_photo_cover(image: Image, metadata: Dictionary) -> void:
	if step != 1: return
	pending_photo = image.duplicate()
	cover_source = "photo"
	source_photo_id = str(metadata.get("photo_id", ""))
	photo_preview.texture = ImageTexture.create_from_image(pending_photo)
	cover_container.hide()
	photo_preview.show()
	next_button.text = "使用这张照片的当前取景"
	instructions.text = "从本地照片制作封面 · 拖动下方滑条调整裁切。"

func _process(delta: float) -> void:
	if holding and step == 4 and not locked:
		hold_seconds += delta
		queue_redraw()
		if hold_seconds >= 1:
			holding = false
			complete_action()
	if step == 1 and not locked:
		cover_time = fposmod(cover_time + delta, audio.get_length())
		preview.time = cover_time
		preview.queue_redraw()
	if locked: queue_redraw()

func play_feedback() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	var frames := 11025 if step != 4 else 77175
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = step + 42
	var filtered := 0.0
	for i in frames:
		var phase := float(i) / 22050
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.07)
		var duration := float(frames) / 22050
		var envelope := minf(1, phase / 0.03) * minf(1, (duration - phase) / 0.1)
		var value := filtered * 0.035 * envelope * (0.6 + sin(phase * 33) * 0.4)
		if step == 4:
			value = (sin(phase * TAU * 72) * 0.025 + sin(phase * TAU * 144) * 0.006) * envelope
		elif step == 8:
			value = (sin(phase * TAU * 130) * 0.09 + filtered * 0.02) * exp(-phase * 45)
		data.encode_s16(i * 2, int(value * 32767))
	wav.data = data
	sound.stream = wav
	sound.play()

func source_rect() -> Rect2:
	match step:
		3: return Rect2(760, 430, 90, 90)
		7: return Rect2(760, 440, 70, 70)
		8: return Rect2(750, 390, 100, 140)
		9: return Rect2(730, 460, 140, 50)
	return Rect2(190, 365, 250, 270)

func target_rect() -> Rect2:
	match step:
		3: return Rect2(270, 440, 95, 95)
		7: return Rect2(380, 370, 85, 70)
		8: return Rect2(340, 530, 115, 90)
		9: return Rect2(325, 570, 150, 60)
	return Rect2(620, 365, 285, 275)

func _gui_input(event: InputEvent) -> void:
	if locked or step < 2 or step > 10: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if step == 2 and event.pressed and Rect2(530, 385, 100, 70).has_point(event.position):
			complete_action()
			return
		if step == 4:
			holding = event.pressed and Rect2(765, 355, 95, 240).has_point(event.position)
			hold_seconds = 0
			queue_redraw()
			return
		if step == 8 and event.pressed:
			if stamp_picked and target_rect().has_point(event.position): complete_action()
			elif source_rect().has_point(event.position): stamp_picked = true
			queue_redraw()
			return
		if event.pressed and source_rect().has_point(event.position):
			dragging = true
			drag_position = event.position
		elif not event.pressed and dragging:
			dragging = false
			if target_rect().has_point(event.position): complete_action()
			queue_redraw()
	elif event is InputEventMouseMotion and (dragging or stamp_picked):
		drag_position = event.position
		queue_redraw()

func caption(at: Vector2, text: String, font_size: int = 16, color: Color = Color("5a4c39")) -> void:
	draw_string(get_theme_default_font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func vinyl(at: Vector2, labeled: bool = true, scale_value: float = 1.0) -> void:
	draw_circle(at + Vector2(6, 9), 112 * scale_value, Color(0, 0, 0, 0.12))
	draw_circle(at, 110 * scale_value, Color("262a28"))
	for radius in range(39, 107, 5): draw_arc(at, radius * scale_value, 0, TAU, 70, Color("454943"), 1, true)
	draw_arc(at, 90 * scale_value, -1.1, 0.1, 30, Color("65675a"), 2, true)
	if labeled: label_disc(at, 31 * scale_value)
	draw_circle(at, 4 * scale_value, Color("d7c8aa"))

func label_disc(at: Vector2, radius: float = 36) -> void:
	draw_circle(at, radius, Color("d7b970"))
	draw_arc(at, radius - 5, 0, TAU, 40, Color("9a793a"), 1, true)
	caption(at + Vector2(-19, -7), "SIDE A", 10)
	caption(at + Vector2(-23, 19), "SOLMERE", 9)
	draw_circle(at, 3, Color("ddd3bb"))

func inner_sleeve(at: Vector2, filled: bool) -> void:
	var rect := Rect2(at - Vector2(118, 120), Vector2(236, 240))
	draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color(0, 0, 0, 0.10))
	draw_rect(rect, Color("f1e7cf"))
	draw_line(rect.position, rect.position + Vector2(236, 0), Color("ad9d7b"), 3)
	if filled:
		draw_circle(at, 56, Color("292d28"))
		label_disc(at, 30)
	else:
		draw_circle(at, 56, Color("cdbb97"))
	draw_line(rect.position + Vector2(10, 20), rect.position + Vector2(10, 230), Color("d4c5a5"), 1)
	caption(at + Vector2(-76, 99), "ACID-FREE INNER SLEEVE", 10)

func outer_sleeve(at: Vector2, decorated: int = 0, scale_value: float = 1.0) -> void:
	var rect := Rect2(at - Vector2(125, 125) * scale_value, Vector2(250, 250) * scale_value)
	draw_rect(Rect2(rect.position + Vector2(6, 9), rect.size), Color(0, 0, 0, 0.14))
	draw_rect(rect, Color("f5ecda"))
	if texture != null: draw_texture_rect(texture, rect.grow(-10 * scale_value), false)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("a6916b"), 3)
	if decorated >= 1:
		draw_circle(at + Vector2(83, -113) * scale_value, 22 * scale_value, Color("a05d43"))
	if decorated >= 2:
		caption(at + Vector2(12, 83) * scale_value, "ARCHIVE COPY", int(11 * scale_value), Color("843f2d"))
		caption(at + Vector2(20, 96) * scale_value, Time.get_date_string_from_system(), int(9 * scale_value), Color("843f2d"))
	if decorated >= 3:
		draw_rect(Rect2(at + Vector2(19, 105) * scale_value, Vector2(116, 27) * scale_value), Color("efe0bd"))
		caption(at + Vector2(24, 124) * scale_value, "LOCAL-%04d" % serial, int(12 * scale_value))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e9dec8"))
	draw_rect(Rect2(28, 324, 1035, 390), Color("c5ad87"))
	for line in 15:
		draw_line(Vector2(32, 334 + line * 26), Vector2(1060, 331 + line * 26), Color(0.3, 0.22, 0.12, 0.07), 1)
	if step < 2: return
	for index in range(2, 11):
		var x := 110.0 + (index - 2) * 105
		if index < 10: draw_line(Vector2(x, 277), Vector2(x + 105, 277), Color("c6b79a"), 2)
		draw_circle(Vector2(x, 277), 15, Color("8b9a70") if index < step else (Color("aa6546") if index == step else Color("d8cbb3")))
		caption(Vector2(x - 4, 282), str(index - 1), 12, Color("faf2df"))
		caption(Vector2(x - 24, 311), ["打印", "标签", "压制", "内袋", "封套", "封签", "盖章", "编号", "上架"][index - 2], 12)
	var left := Vector2(320, 490)
	var right := Vector2(760, 490)
	var moving := drag_position if dragging else source_rect().get_center()
	if locked: moving = source_rect().get_center().lerp(target_rect().get_center(), progress)
	caption(Vector2(50, 700), STEPS[step], 15)
	match step:
		2:
			draw_rect(Rect2(185, 355, 450, 125), Color("697567"))
			draw_rect(Rect2(210, 458, 395, 12), Color("293b30"))
			draw_circle(Vector2(576, 416), 22, Color("b5cc86"))
			caption(Vector2(230, 405), "SOLMERE / PAPER PRESS", 20, Color("ede4d0"))
			if locked:
				var rect := Rect2(250, 471, 250, 190 * progress)
				draw_rect(rect, Color("f4eddf"))
				if texture != null and progress > 0.02: draw_texture_rect(texture, rect.grow(-3), false)
			caption(Vector2(700, 445), "封面纸  /  240 gsm", 18)
			for i in 5: draw_rect(Rect2(700 + i * 2, 480 + i * 3, 180, 100), Color("eee4ca"))
		3:
			vinyl(left, false)
			label_disc(moving)
			caption(Vector2(250, 635), "中心孔 · 松手吸附对齐", 15)
			caption(Vector2(724, 585), "已印好的纸标签", 15)
		4:
			draw_rect(Rect2(310, 357, 450, 280), Color("717c70"))
			draw_rect(Rect2(350, 600, 390, 36), Color("465343"))
			vinyl(Vector2(535, 515), true, 0.75)
			var press_y := 385.0 + (sin(progress * PI) * 106 if locked else 0.0)
			draw_rect(Rect2(405, press_y, 270, 26), Color("bbc0a9"))
			draw_line(Vector2(537, 355), Vector2(537, press_y), Color("b5b9a3"), 20)
			var handle_y := 393.0 + minf(hold_seconds, 1) * 85
			draw_line(Vector2(760, 440), Vector2(812, handle_y), Color("514d3b"), 9)
			draw_circle(Vector2(812, handle_y), 22, Color("a3533b"))
			caption(Vector2(360, 675), "压盘下降 → 压制刻纹 → 冷却 → 抬起", 16)
		5:
			vinyl(moving if dragging or locked else left)
			inner_sleeve(right, locked and progress > 0.8)
			caption(Vector2(650, 345), "从袋口滑入，保护唱片表面", 16)
		6:
			inner_sleeve(moving if dragging or locked else left, true)
			outer_sleeve(right)
			caption(Vector2(650, 345), "印好封面的外纸套", 16)
		7:
			outer_sleeve(left)
			draw_circle(moving, 24, Color("a05d43"))
			caption(moving + Vector2(-17, 4), "LOCAL", 10, Color("f1e6c9"))
			caption(Vector2(645, 600), "沿上沿贴下，轻轻压平", 16)
		8:
			outer_sleeve(left, 2 if locked and progress > 0.65 else 1)
			var at := drag_position if stamp_picked else Vector2(800, 460)
			if locked: at = Vector2(390, 560) + Vector2(0, -sin(progress * PI) * 25)
			draw_rect(Rect2(at - Vector2(43, 10), Vector2(86, 25)), Color("665943"))
			draw_rect(Rect2(at - Vector2(18, 72), Vector2(36, 70)), Color("906643"))
			draw_circle(at - Vector2(0, 75), 25, Color("a47b4d"))
			caption(Vector2(665, 620), "拿起木柄 → 移到纸面 → 落章", 15)
		9:
			outer_sleeve(left, 2)
			draw_rect(Rect2(moving - Vector2(65, 20), Vector2(130, 40)), Color("f1e2be"))
			caption(moving + Vector2(-55, 5), "LOCAL-%04d" % serial, 14)
			caption(Vector2(640, 625), "编号纸卡 → 下沿卡槽", 16)
		10, 11:
			draw_rect(Rect2(610, 370, 360, 300), Color("806c50"))
			for i in 9: draw_rect(Rect2(625 + i * 36, 380, 22, 115), [Color("b2bb96"), Color("c3926f"), Color("d4c397")][i % 3])
			draw_line(Vector2(615, 500), Vector2(967, 500), Color("4b4735"), 8)
			caption(Vector2(650, 535), "LOCAL RECORDINGS", 20, Color("f1e6cd"))
			draw_rect(Rect2(645, 565, 250, 65), Color("bda783"))
			if locked:
				outer_sleeve(left.lerp(Vector2(850, 434), progress), 3, lerpf(1, 0.32, progress))
			elif step == 11: outer_sleeve(Vector2(850, 434), 3, 0.32)
			else: outer_sleeve(moving if dragging else left, 3)
			caption(Vector2(175, 670), "老板：我给它留好位置了。", 18)
