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
var drag_offset := Vector2.ZERO
var action_origin := Vector2.ZERO
var dropped := false
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
var photo_album: Control
var library := LocalRecordLibrary.new()
var progress := 0.0
var holding := false
var hold_seconds := 0.0
var stamp_picked := false
var serial := 1
var assisted := false
var helper: Button
var lever_start := Vector2.ZERO
var lever_pull := 0.0
var summary_label: Label
var cover_sources: HBoxContainer
var pending_photo: Image
var photo_preview: TextureRect
var cover_source := "visual"
var source_photo_id := ""
const STEPS := ["01 / 签下唱片信息", "02 / 留下封面画面", "03 / 印刷纸板封套", "04 / 装载中心标签", "05 / 压制、冷却与修边", "06 / 唱片装入纸内袋", "07 / 内袋装入纸板封套", "08 / 封套装入透明保护袋", "09 / 合上外袋翻盖", "10 / 贴上作品编号", "11 / 交给唱片店老板", "LOCAL RECORDINGS"]
const HINTS := ["给作品写下标题、作者和一句话。", "拖动滑条取景，点画面定格封面；也能选自己拍的照片。", "点打印机绿色按钮，印好的封面按出纸进度露出。", "拿起 A 面纸标签，对齐左侧 PVC 料饼的中心；B 面标签已在下方。", "抓住右侧红把手向下拉，再保持半秒。标签与 PVC 一起压制，冷却后修边。", "握住左侧唱片边缘，移到右侧纸袋的上方开口，松手后垂直滑入。", "拿起右侧装好的纸内袋，对准左侧封套的右边开口，水平滑入。", "拿起左侧纸板封套，对准右侧透明保护袋上方开口，向下装入。", "从右侧袋口拿起透明翻盖，向下折合；胶条只贴保护袋，不贴封面。", "将左侧编号标签贴到透明袋右下角。编号不覆盖封面主体。", "把包装好的唱片递到左侧柜台托盘，等待老板收录。", "这段声音已经在店里有了一个位置。"]

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
	instructions = room.studio.label("01 / 给唱片写张小卡\n老板：先起个名字，再给它挑一张封面。", 18)
	column.add_child(instructions)
	title_input = LineEdit.new()
	title_input.placeholder_text = LocalizationSystem.text("TITLE / 唱片标题")
	title_input.max_length = 60
	title_input.position=Vector2(170,456); title_input.size=Vector2(660,48); add_child(title_input)
	artist_input = LineEdit.new()
	artist_input.placeholder_text = LocalizationSystem.text("ARTIST / 作者")
	artist_input.max_length = 40
	artist_input.position=Vector2(170,525); artist_input.size=Vector2(660,48); add_child(artist_input)
	note_input = LineEdit.new()
	note_input.placeholder_text = LocalizationSystem.text("ONE LINE NOTE / 一句话，留空也可以")
	note_input.max_length = 160
	note_input.position=Vector2(170,594); note_input.size=Vector2(660,48); add_child(note_input)
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
		next_button.text = LocalizationSystem.text("暂停并使用当前帧")))
	cover_sources.add_child(room.studio.button("从本地相册选封面", select_photo_cover))
	cover_sources.hide()
	next_button = room.studio.button("写好了，挑封面 →", advance)
	next_button.position=Vector2(170,676); next_button.size=Vector2(350,46); add_child(next_button)
	helper=room.studio.button("需要操作帮助？",func():
		assisted=not assisted; next_button.visible=assisted; helper.text="收起辅助操作" if assisted else "需要操作帮助？")
	helper.position=Vector2(1170,235); helper.size=Vector2(310,46); helper.hide(); add_child(helper)
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
	preview.model=model
	preview.profile=profile.duplicate(true)
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
	crop_slider.tooltip_text = LocalizationSystem.text("封面裁切：左右移动取景")
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
	sound.bus = "SoundEffects"
	sound.volume_db = -12.0
	add_child(sound)
	queue_redraw()

func advance() -> void:
	if locked: return
	if step == 0:
		title_input.text = title_input.text.strip_edges()
		artist_input.text = artist_input.text.strip_edges()
		if title_input.text.is_empty(): title_input.text = LocalizationSystem.text("今天听见的东西")
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
		next_button.position=Vector2(620,584)
		cover_sources.show()
		crop_overlay.queue_redraw()
		cover_container.show()
		crop_slider.show()
		next_button.text = LocalizationSystem.text("暂停并使用当前帧")
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
		next_button.position=Vector2(1170,290); next_button.size=Vector2(310,46)
		next_button.text = LocalizationSystem.text("辅助：打印封面纸套")
		next_button.hide(); helper.show()
	elif step >= 2 and step <= 10:
		await complete_action()
	elif step == 11:
		room.studio.show()
		room.queue_free()
	if step < 11:
		instructions.text = LocalizationSystem.text(STEPS[step]) + "\n" + LocalizationSystem.text(HINTS[step])
	queue_redraw()

func complete_action() -> void:
	if locked: return
	locked = true
	action_origin=drag_position if dropped else source_rect().get_center()
	dropped=false
	instructions.text=STEPS[step]+"\n"+HINTS[step]
	progress = 0.0
	play_feedback()
	next_button.disabled = true
	if step < 10:
		var duration := 4.5 if step == 4 else (2.2 if step in [2,5,6,7] else 1.2)
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
			var role := GameState.current_role if has_node("/root/GameState") else ""
			var day := GameState.current_day if has_node("/root/GameState") else 0
			saved_record = library.save_record({"title": title_input.text, "artist": artist_input.text,
				"one_line_note": note_input.text, "duration": audio.get_length(), "visual_prompt": model.prompt,
				"visual_profile": profile, "mv_clips": model.clips.duplicate(true), "mv_muted":model.muted.duplicate(), "mv_gains":model.gains.duplicate(), "sound_kinds":preload("res://scripts/town_sound/data/SoundAtlas.gd").audible_kinds(model), "visual_seed": seed_value, "visual_version": int(profile.get("visual_version", 2)), "source_sample_count": samples.size(),
				"packaging_version":2, "record_format":"12-inch 33⅓ RPM / 180 g", "packaging_layers":["paper_inner","printed_jacket","resealable_pp_outer"],
				"cover_source": cover_source, "source_photo_id": source_photo_id,
				"payment": payment, "project_path": model.project_path, "created_by": role,
				"game_day": day, "location": "record_store"}, audio, cover)
		if saved_record.is_empty():
			instructions.text = LocalizationSystem.text(library.last_error)
			locked = false
			next_button.disabled = false
			return
		if has_node("/root/GameState"):
			var snapshot := GameState.to_save_data()
			GameState.credit_record_once(
				str(saved_record.get("record_id", saved_record.get("id", ""))),
				int(saved_record.get("payment", payment)),
				saved_record
			)
			if not GameplayModuleSystem.record_studio_delivery(saved_record) or not SaveManager.save_or_report("唱片压制结果保存失败"):
				GameState.load_save_data(snapshot)
				instructions.text=LocalizationSystem.text("唱片文件已经留下，主存档未能保存。请重试交付。")
				locked=false; next_button.disabled=false; return
		instructions.text = LocalizationSystem.text("老板：我晚点再听一遍。\n正在把你的唱片放上 LOCAL RECORDINGS……")
		var tween := create_tween()
		tween.tween_property(self, "progress", 1.0, 3.5).set_trans(Tween.TRANS_CUBIC)
		await tween.finished
	step += 1
	locked = false
	next_button.disabled = false
	progress = 0
	stamp_picked = false
	var buttons := {3: "辅助操作：对齐标签", 4: "辅助操作：压下把手", 5: "辅助操作：滑入内袋", 6: "辅助操作：装进外套", 7: "辅助操作：装入透明外袋", 8: "辅助操作：折合翻盖", 9: "辅助操作：贴上编号", 10: "辅助操作：交给老板", 11: "返回 Studio"}
	next_button.text = LocalizationSystem.text(buttons.get(step, "继续"))
	if step == 11:
		next_button.show(); helper.hide()
		var balance := GameState.money if has_node("/root/GameState") else library.money()
		instructions.text = LocalizationSystem.text("「%s」已上架  +%d / LOCAL RECORDING LICENSE\n游戏内余额：%d · 唱片已本地保存。公共库尚未配置，保持 Local Mode。" % [saved_record.title, saved_record.payment, balance])
	else:
		instructions.text = LocalizationSystem.text(STEPS[step]) + "\n" + LocalizationSystem.text(HINTS[step])
	queue_redraw()

func select_photo_cover() -> void:
	if step != 1 or locked or is_instance_valid(photo_album): return
	var album = load("res://scripts/town_sound/PhotoAlbum.gd").new()
	photo_album = album
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
	next_button.text = LocalizationSystem.text("使用这张照片的当前取景")
	instructions.text = LocalizationSystem.text("从本地照片制作封面 · 拖动下方滑条调整裁切。")

func _process(delta: float) -> void:
	if holding and step == 4 and not locked:
		if lever_pull>=100: hold_seconds += delta
		queue_redraw()
		if lever_pull>=100 and hold_seconds >= .6:
			holding = false
			complete_action()
	if step == 1 and not locked:
		cover_time = fposmod(cover_time + delta, audio.get_length())
		preview.time = cover_time
		preview.queue_redraw()
	if locked: queue_redraw()

func play_feedback() -> void:
	if step in [2,3,5,6,7,8,9]:
		sound.stream=preload("res://scripts/town_sound/data/SoundAtlas.gd").stream("wood" if step==3 else "paper")
		sound.volume_db=-18; sound.play(); return
	sound.volume_db=-19
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
	var r:=_source_rect()
	return Rect2(r.position+Vector2(0,125),r.size)

func _source_rect() -> Rect2:
	match step:
		3: return Rect2(724,469,72,72)
		7: return Rect2(189,374,262,262)
		6,10: return Rect2(627,370,266,270)
		8: return Rect2(625,321,270,34)
		9: return Rect2(261,490,118,30)
	return Rect2(207,392,226,226)

func target_rect() -> Rect2:
	var r:=_target_rect()
	return Rect2(r.position+Vector2(0,125),r.size)

func _target_rect() -> Rect2:
	match step:
		3: return Rect2(296,481,48,48)
		5,7: return Rect2(714,334,92,86)
		6: return Rect2(409,463,86,84)
		8: return Rect2(625,366,270,42)
		9: return Rect2(796,597,48,30)
		10: return Rect2(185,550,290,105)
	return Rect2(620,365,285,275)

func _gui_input(event: InputEvent) -> void:
	if step==1 and not locked and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Rect2(50,350,480,270).has_point(event.position):
		advance(); accept_event(); return
	if locked or step<2 or step>10: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if step==2 and event.pressed and Rect2(550,515,52,52).has_point(event.position):
			complete_action(); accept_event(); return
		if step==4:
			holding=event.pressed and Rect2(765,480,95,240).has_point(event.position)
			lever_start=event.position; lever_pull=0; hold_seconds=0
			queue_redraw(); accept_event(); return
		if event.pressed and source_rect().has_point(event.position):
			# Keep the exact grab offset; grabbing the rim never snaps the disc center to the cursor.
			if step==5:
				var radius: float=event.position.distance_to(source_rect().get_center())
				if radius>113 or (radius>37 and radius<94):
					instructions.text="请握住唱片最外缘或中心标签，避免碰到音槽。"; return
			dragging=true; drag_offset=event.position-source_rect().get_center()
			drag_position=source_rect().get_center(); accept_event()
		elif not event.pressed and dragging:
			drag_position=(event.position-drag_offset).clamp(Vector2(28,324)+source_rect().size/2,Vector2(1063,850)-source_rect().size/2)
			dragging=false
			if target_rect().has_point(drag_position):
				dropped=true; complete_action()
			else: instructions.text="还没有对齐开口，物件已放回原处。\n"+HINTS[step]
			queue_redraw(); accept_event()
	elif event is InputEventMouseMotion and holding and step==4:
		lever_pull=clampf(event.position.y-lever_start.y,0,150)
		if lever_pull<100: hold_seconds=0
		queue_redraw(); accept_event()
	elif event is InputEventMouseMotion and dragging:
		drag_position=(event.position-drag_offset).clamp(Vector2(28,324)+source_rect().size/2,Vector2(1063,850)-source_rect().size/2); queue_redraw(); accept_event()

func _draw() -> void:
	preload("res://scripts/town_sound/record_shop/PackagingArtwork.gd").paint(self)
