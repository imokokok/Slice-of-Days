extends Control
var host: Control
var player: AudioStreamPlayer
var visual: VisualCanvas
var note: Label
var library := LocalRecordLibrary.new()

var monitor_locked := false

func _ready() -> void:
	if has_node("/root/WorldSound"):
		get_node("/root/WorldSound").lock_monitor(true)
		monitor_locked = true
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	player = AudioStreamPlayer.new()
	add_child(player)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(host._label("LOCAL RECORDINGS / 本地唱片架", 28))
	column.add_child(host._button("♪ 声音设置 / 测试音", func() -> void: get_node("/root/SoundSettings").show_dialog()))
	column.add_child(host._button("返回录音", func() -> void: queue_free()))
	column.add_child(host._label("游戏内余额：%d   /   LOCAL MODE" % library.money(), 18))
	note = host._label("居民唱片与自己的成品，随时回来听。", 16)
	column.add_child(note)
	column.add_child(host._button("公共唱片库状态", func() -> void:
		var online := OnlineRecordLibrary.new()
		online.list_records()
		note.text = online.last_error))
	for record in library.list_records():
		var row := HBoxContainer.new()
		column.add_child(row)
		if FileAccess.file_exists(record.cover_path):
			var image := Image.load_from_file(record.cover_path)
			if image != null:
				var cover := TextureRect.new()
				cover.texture = ImageTexture.create_from_image(image)
				cover.custom_minimum_size = Vector2(68, 68)
				cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				row.add_child(cover)
		row.add_child(host._label("%s / %s / %.1f s\n%s" % [record.title, record.artist, record.duration, record.get("one_line_note", "")], 15))
		row.add_child(host._button("▶ 试听", func() -> void: listen(record)))
	column.add_child(host._button("■ 停止试听", func() -> void: player.stop()))
	visual = VisualCanvas.new()
	visual.custom_minimum_size = Vector2(960, 540)
	column.add_child(visual)

func listen(record: Dictionary) -> void:
	if not FileAccess.file_exists(record.final_audio_path):
		note.text = "成品音频丢失，其他唱片仍可正常试听。"
		return
	var wav := AudioStreamWAV.load_from_file(record.final_audio_path)
	if wav == null:
		note.text = "成品音频无法读取。"
		return
	visual.configure(wav, str(record.get("visual_prompt", "warm")), int(record.get("visual_seed", 23817)))
	if record.get("visual_profile") is Dictionary and not record.visual_profile.is_empty():
		visual.profile = record.visual_profile
	player.stream = wav
	player.play()
	note.text = "正在试听：「%s」" % record.title

func _process(_delta: float) -> void:
	if player.playing:
		visual.time = player.get_playback_position()
		visual.queue_redraw()

func _exit_tree() -> void:
	if monitor_locked: get_node("/root/WorldSound").lock_monitor(false)
