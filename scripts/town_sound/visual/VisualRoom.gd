extends Control
var studio: Control
var model: Arrangement
var audio: AudioStreamWAV
var player: AudioStreamPlayer
var canvas: VisualCanvas
var viewport: SubViewport
var column: VBoxContainer
var status: Label
var prompt_input: LineEdit
var pressing: Control
var submitting := false
var listening_controls: Array[BaseButton] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(studio.label("MUSIC VISUAL / 声音的形状", 26))
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(960, 540)
	column.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	canvas = VisualCanvas.new()
	canvas.size = Vector2(960, 540)
	canvas.model = model
	canvas.configure(audio, model.prompt, model.seed_value)
	viewport.add_child(canvas)
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = audio
	add_child(player)
	prompt_input = LineEdit.new()
	prompt_input.text = model.prompt
	prompt_input.max_length = 160
	column.add_child(prompt_input)
	var modes := HBoxContainer.new(); column.add_child(modes)
	modes.add_child(studio.label("MV 表现",17))
	var selector := OptionButton.new()
	selector.add_item("像素 · 跟随声音来源")
	selector.add_item("康定斯基式 · 几何构图")
	selector.item_selected.connect(func(index:int):
		canvas.pixel_mode=index==0; canvas.profile["mode"]="pixel" if index==0 else "geometry"; canvas.queue_redraw())
	modes.add_child(selector)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	controls.add_child(studio.button("生成画面", generate))
	controls.add_child(studio.button("换一个种子", func() -> void:
		model.seed_value = randi() % 2147483647
		generate()))
	controls.add_child(studio.button("▶ 播放", func() -> void:
		if player.stream_paused: player.stream_paused = false
		else: player.play()))
	controls.add_child(studio.button("Ⅱ 暂停", func() -> void: player.stream_paused = true))
	controls.add_child(studio.button("交给老板试听", submit))
	controls.add_child(studio.button("返回 Studio", func() -> void:
		model.prompt = prompt_input.text
		if not model.save_project():
			status.text = LocalizationSystem.text(model.error)
			return
		studio.show()
		queue_free()))
	for child in controls.get_children():
		if child is BaseButton and child.text != "返回 Studio": listening_controls.append(child)
	status = studio.label("像素影像跟随已录声源、剪辑位置与真实音频能量。切换几何模式可制作另一种封面。", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)

func generate() -> bool:
	model.prompt = prompt_input.text
	var mode := str(canvas.profile.get("mode","pixel"))
	canvas.configure(audio, model.prompt, model.seed_value)
	canvas.profile["mode"]=mode
	if not model.save_project():
		status.text = LocalizationSystem.text(model.error)
		return false
	status.text = LocalizationSystem.text("本地生成完成 · Seed %d" % model.seed_value)
	return true

func _process(_delta: float) -> void:
	if player.playing and not player.stream_paused:
		canvas.time = player.get_playback_position()
		canvas.queue_redraw()

func submit() -> void:
	if preload("res://scripts/town_sound/data/SoundAtlas.gd").audible_kinds(model).is_empty():
		status.text="作品没有可听见的声音，请取消轨道静音或重新采样。"
		return
	var unique: Dictionary = {}
	for clip in model.clips: unique[clip.sample_id] = true
	if unique.size() < 2 or model.clips.size() < 2 or model.length() < 8.0:
		status.text = LocalizationSystem.text("老板：这个还像个草稿。再弄一点，我给你留着位置。\n需要至少 2 种录音、2 个片段、8 秒作品。")
		return
	if pressing != null or submitting: return
	if not generate(): return
	status.text = LocalizationSystem.text("老板：新做的？行，放吧。\n正在试听作品（8 秒）……")
	player.stream_paused = false
	player.play()
	# Submission is locked during listening; returning frees this node and cancels the continuation.
	submitting = true
	for button in listening_controls: button.disabled = true
	prompt_input.editable = false
	await get_tree().create_timer(8.0).timeout
	player.stop()
	pressing = load("res://scripts/town_sound/record_shop/PressingTable.gd").new()
	pressing.room = self
	pressing.model = model
	pressing.audio = audio
	pressing.profile = canvas.profile
	pressing.seed_value = model.seed_value
	add_child(pressing)
	column.hide()
