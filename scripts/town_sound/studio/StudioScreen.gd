extends Control
const Model = preload("res://scripts/town_sound/studio/Arrangement.gd")
const Timeline = preload("res://scripts/town_sound/studio/Timeline.gd")
const DragButton = preload("res://scripts/town_sound/studio/SampleDragButton.gd")
var model := Model.new()
var timeline: SoundTimeline
var player: AudioStreamPlayer
var status: Label
var inspector: VBoxContainer
var clock_label: Label
var selected := -1
var dirty := true
var mixdown: AudioStreamWAV
var paused_at := 0.0
var root_column: VBoxContainer
var region_start := -1.0
var region_end := -1.0
var region_track := 0
var mute_controls: Array[CheckButton] = []
var gain_controls: Array[HSlider] = []

var monitor_locked := false

func _ready() -> void:
	if has_node("/root/WorldSound"):
		get_node("/root/WorldSound").lock_monitor(true)
		monitor_locked = true
	if has_node("/root/GameState") and get_node("/root/GameState").current_location != "record_store":
		set_process(false)
		queue_free()
		return
	model.load_project()
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(func() -> void: paused_at = 0.0)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(margin)
	root_column = VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 12)
	margin.add_child(root_column)
	var header := HBoxContainer.new()
	root_column.add_child(header)
	header.add_child(label("TOWN SOUND / STUDIO", 26))
	header.add_child(button("♪ 声音设置", func() -> void: get_node("/root/SoundSettings").show_dialog()))
	header.add_child(button("返回录音", func() -> void:
		if model.save_project():
			player.stop()
			get_parent().show()
			queue_free()
		else:
			status.text = model.error))
	var transport := HBoxContainer.new()
	root_column.add_child(transport)
	transport.add_child(button("▶ 播放", play))
	transport.add_child(button("Ⅱ 暂停", pause))
	transport.add_child(button("■ 停止", stop))
	transport.add_child(button("保存工程", func() -> void: status.text = "工程已保存。" if model.save_project() else model.error))
	transport.add_child(button("重载工程", func() -> void:
		stop()
		if model.load_project():
			selected = -1
			changed()
			status.text = "工程已恢复。"
		else:
			status.text = model.error))
	transport.add_child(button("Visual / 唱片店", open_visual))
	clock_label = label("00:00 / 00:00")
	transport.add_child(clock_label)
	var edit_tools := HBoxContainer.new()
	root_column.add_child(edit_tools)
	var mode_group := ButtonGroup.new()
	var move_tool := button("↔ 移动片段", func() -> void:
		timeline.selection_mode = false
		status.text = "移动模式：拖片段中间移动，拖橙色边缘裁剪。")
	move_tool.toggle_mode = true
	move_tool.button_group = mode_group
	move_tool.button_pressed = true
	edit_tools.add_child(move_tool)
	var range_tool := button("▧ 拖选区域", func() -> void:
		timeline.selection_mode = true
		status.text = "选区模式：在任意轨道上按住鼠标拖出一段，再点删除选区或只保留选区。")
	range_tool.toggle_mode = true
	range_tool.button_group = mode_group
	edit_tools.add_child(range_tool)
	edit_tools.add_child(button("✂ 删除选区", func() -> void: edit_region(false)))
	edit_tools.add_child(button("只保留选区", func() -> void: edit_region(true)))
	edit_tools.add_child(label("缩放", 13))
	var zoom := HSlider.new()
	zoom.min_value = 15
	zoom.max_value = 100
	zoom.value = 30
	zoom.custom_minimum_size.x = 110
	zoom.value_changed.connect(func(value: float) -> void:
		timeline.custom_minimum_size.x = value * 60
		timeline.queue_redraw())
	edit_tools.add_child(zoom)
	var samples := HBoxContainer.new()
	root_column.add_child(samples)
	samples.add_child(label("素材：拖入轨道\n或点击放到游标", 14))
	var sample_scroll := ScrollContainer.new()
	sample_scroll.custom_minimum_size.y = 66
	sample_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	samples.add_child(sample_scroll)
	var sample_row := HBoxContainer.new()
	sample_scroll.add_child(sample_row)
	for item in SampleStore.new().list_samples():
		var drag := DragButton.new()
		drag.sample = item
		drag.text = str(item.name).left(12)
		drag.tooltip_text = "%s · %.2f 秒" % [item.name, item.duration]
		drag.disabled = item.missing
		drag.pressed.connect(func() -> void:
			selected = model.add_sample(item, 0, minf(paused_at, 59.8))
			timeline.selected = selected
			changed())
		sample_row.add_child(drag)
	var track_row := HBoxContainer.new()
	root_column.add_child(track_row)
	var track_controls := VBoxContainer.new()
	track_controls.custom_minimum_size.x = 115
	track_row.add_child(track_controls)
	track_controls.add_child(label("TRACKS", 13))
	for i in 4:
		var control := VBoxContainer.new()
		control.custom_minimum_size.y = 66
		track_controls.add_child(control)
		var mute := CheckButton.new()
		mute.text = "T%d 静音" % (i + 1)
		mute.button_pressed = bool(model.muted[i])
		mute.toggled.connect(func(value: bool) -> void:
			model.muted[i] = value
			changed())
		control.add_child(mute)
		mute_controls.append(mute)
		var gain := HSlider.new()
		gain.max_value = 1.5
		gain.step = 0.05
		gain.value = model.gains[i]
		gain.tooltip_text = "轨道音量 0–150%"
		gain.value_changed.connect(func(value: float) -> void:
			model.gains[i] = value
			changed())
		control.add_child(gain)
		gain_controls.append(gain)
	timeline = Timeline.new()
	timeline.arrangement = model
	timeline.size_flags_horizontal = SIZE_EXPAND_FILL
	timeline.selected_changed.connect(func(index: int) -> void:
		selected = index
		build_inspector())
	timeline.edited.connect(changed)
	timeline.seek_requested.connect(func(seconds: float) -> void:
		paused_at = seconds
		if player.playing:
			player.seek(minf(seconds, model.length()))
		timeline.playhead = seconds
		timeline.queue_redraw())
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.custom_minimum_size = Vector2(650, 330)
	timeline_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_row.add_child(timeline_scroll)
	timeline_scroll.add_child(timeline)
	timeline.region_selected.connect(func(begin: float, end: float, track: int) -> void:
		if begin < 0:
			region_start = -1
			region_end = -1
			return
		region_start = begin
		region_end = end
		region_track = track
		status.text = "已选 T%d：%.2f–%.2f 秒。点击「删除选区」剪掉中间，或「只保留选区」。" % [track + 1, begin, end])
	inspector = VBoxContainer.new()
	root_column.add_child(inspector)
	status = label("四条轨道 · 60 秒 · 拖动片段边缘裁切，拖动中间移动。", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_column.add_child(status)
	build_inspector()

func label(text: String, font_size: int = 16) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(action)
	return node

func field(row: HBoxContainer, title: String, key: String, low: float, high: float, step: float) -> void:
	row.add_child(label(title, 13))
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = float(model.clips[selected][key])
	spin.custom_minimum_size.x = 92
	spin.value_changed.connect(func(value: float) -> void:
		if selected < 0:
			return
		model.clips[selected][key] = value
		dirty = true
		stop()
		if not model.save_project(): status.text = model.error)
	row.add_child(spin)

func build_inspector() -> void:
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if selected < 0 or selected >= model.clips.size():
		inspector.add_child(label("点击片段调整音量、速度、循环和淡入淡出。", 15))
		return
	var row := HBoxContainer.new()
	inspector.add_child(row)
	field(row, "音量", "volume", 0, 1.5, 0.05)
	field(row, "淡入", "fade_in", 0, 2, 0.1)
	field(row, "淡出", "fade_out", 0, 2, 0.1)
	var speed := OptionButton.new()
	var speeds := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
	for value in speeds:
		speed.add_item(str(value) + "x")
	speed.select(speeds.find(float(model.clips[selected].speed)))
	speed.item_selected.connect(func(index: int) -> void:
		var clip := model.clips[selected]
		var old := float(clip.speed)
		clip.speed = speeds[index]
		clip.length = minf(float(clip.length) * old / float(clip.speed), 60.0 - float(clip.start))
		changed())
	row.add_child(speed)
	var loop := CheckButton.new()
	loop.text = "循环"
	loop.button_pressed = model.clips[selected].loop
	loop.toggled.connect(func(value: bool) -> void:
		model.clips[selected].loop = value
		changed())
	row.add_child(loop)
	row.add_child(button("拆分", split_clip))
	row.add_child(button("复制", duplicate_clip))
	row.add_child(button("删除片段", delete_clip))
	var trim_row := HBoxContainer.new()
	inspector.add_child(trim_row)
	trim_row.add_child(label("精确裁剪 · 源音频起点", 13))
	var trim_start := SpinBox.new()
	trim_start.max_value = 60
	trim_start.step = 0.01
	trim_start.value = float(model.clips[selected].source_start) + float(model.clips[selected].get("phase", 0))
	trim_row.add_child(trim_start)
	trim_row.add_child(label("终点", 13))
	var trim_end := SpinBox.new()
	trim_end.max_value = 60
	trim_end.step = 0.01
	trim_end.value = minf(float(model.clips[selected].source_end), trim_start.value + float(model.clips[selected].length) * float(model.clips[selected].speed))
	trim_row.add_child(trim_end)
	trim_row.add_child(button("应用裁剪", func() -> void:
		var clip := model.clips[selected]
		var source := model.load_pcm(clip.sample_id)
		if source.is_empty():
			status.text = model.error
			return
		var duration := float(source.pcm.size()) / float(source.rate)
		if trim_end.value <= trim_start.value or trim_end.value > duration:
			status.text = "终点必须大于起点，且不能超过原始录音 %.2f 秒。" % duration
			return
		clip.source_start = trim_start.value
		clip.source_end = trim_end.value
		clip.phase = 0.0
		clip.length = minf((trim_end.value - trim_start.value) / float(clip.speed), 60.0 - float(clip.start))
		changed()))

func changed() -> void:
	for i in mute_controls.size():
		mute_controls[i].set_pressed_no_signal(bool(model.muted[i]))
		gain_controls[i].set_value_no_signal(float(model.gains[i]))
	dirty = true
	stop()
	timeline.queue_redraw()
	build_inspector()
	if not model.save_project(): status.text = model.error

func prepare_mix() -> bool:
	if dirty or mixdown == null:
		mixdown = model.mix()
		dirty = false
	if mixdown == null:
		status.text = model.error
		return false
	return true

func play() -> void:
	if not prepare_mix():
		return
	player.stream = mixdown
	player.stream_paused = false
	player.play(paused_at if paused_at < model.length() else 0.0)
	status.text = "播放中 · 所有轨道已混合到同一个采样时钟。"

func pause() -> void:
	if player.playing:
		paused_at = player.get_playback_position()
		player.stop()

func stop() -> void:
	player.stop()
	paused_at = 0
	if timeline != null:
		timeline.playhead = 0
		timeline.queue_redraw()

func _process(_delta: float) -> void:
	if player.playing:
		paused_at = maxf(0, player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	timeline.playhead = paused_at
	timeline.queue_redraw()
	clock_label.text = "%.1f / %.1f s" % [paused_at, model.length()]

func split_clip() -> void:
	if model.split(selected, paused_at):
		changed()
	else:
		status.text = "先把播放游标移到片段内部，再拆分。"

func duplicate_clip() -> void:
	selected = model.duplicate_clip(selected)
	timeline.selected = selected
	changed()

func delete_clip() -> void:
	if selected >= 0 and selected < model.clips.size():
		model.clips.remove_at(selected)
		selected = -1
		timeline.selected = -1
		changed()

func edit_region(keep: bool) -> void:
	if region_start < 0 or region_end - region_start < 0.01:
		status.text = "先点「拖选区域」，再在波形上拖选要剪辑的范围。"
		return
	if keep: model.keep_range(region_start, region_end, region_track)
	else: model.remove_range(region_start, region_end, region_track)
	selected = -1
	timeline.selected = -1
	timeline.range_begin = -1
	region_start = -1
	changed()
	status.text = "已保留选区内的声音。" if keep else "选区已剪掉，左右两段保留在原来的位置。"

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and event.is_command_or_control_pressed():
			duplicate_clip()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if timeline.selection_mode and region_start >= 0: edit_region(false)
			else: delete_clip()

func open_visual() -> void:
	if not prepare_mix():
		return
	if not model.save_project():
		status.text = model.error
		return
	stop()
	var visual = load("res://scripts/town_sound/visual/VisualRoom.gd").new()
	visual.studio = self
	visual.model = model
	visual.audio = mixdown
	get_parent().add_child(visual)
	hide()

func _exit_tree() -> void:
	if monitor_locked: get_node("/root/WorldSound").lock_monitor(false)
