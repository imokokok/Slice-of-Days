extends Control

const Recorder = preload("res://scripts/audio/AudioRecorder.gd")
const Store = preload("res://scripts/data/SampleStore.gd")
const Waveform = preload("res://scripts/audio/WaveformView.gd")
var recorder: FieldRecorder
var store := Store.new()
var player: AudioStreamPlayer
var draft: AudioStreamWAV
var devices: OptionButton
var record_button: Button
var stop_button: Button
var save_button: Button
var preview_button: Button
var discard_button: Button
var refresh_button: Button
var name_input: LineEdit
var timer_label: Label
var status_label: Label
var count_label: Label
var meter: ProgressBar
var waveform: WaveformView
var library: VBoxContainer
var tutorial_label: Label
var delete_dialog: ConfirmationDialog
var quit_dialog: ConfirmationDialog
var pending_delete := ""
var row_buttons: Array[Button] = []
var sample_peaks: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_theme()
	recorder = Recorder.new()
	add_child(recorder)
	player = AudioStreamPlayer.new()
	add_child(player)
	_build_ui()
	get_node("/root/SoundSettings").input_changed.connect(func(_device: String) -> void: _refresh_devices())
	load("res://scripts/record_shop/PresetRecords.gd").ensure_presets()
	recorder.meter_changed.connect(func(peak: float, seconds: float) -> void:
		meter.value = clampf((linear_to_db(maxf(peak, 0.00001)) + 60.0) / 60.0, 0.0, 1.0)
		timer_label.text = "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)])
	recorder.completed.connect(_on_recorded)
	recorder.failed.connect(func(message: String) -> void:
		status_label.text = message
		meter.value = 0
		_refresh_controls())
	player.finished.connect(func() -> void:
		status_label.text = "试听结束。把今天听见的东西留下来。"
		_refresh_controls())
	_refresh_devices()
	_refresh_library()
	_refresh_controls()

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = 17
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC"])
	skin.default_font = font
	skin.set_color("font_color", "Label", Color("303932"))
	skin.set_color("font_color", "Button", Color("303932"))
	skin.set_color("font_color", "LineEdit", Color("303932"))
	skin.set_color("font_placeholder_color", "LineEdit", Color("7b8076"))
	skin.set_color("font_disabled_color", "Button", Color("9b9d92"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e3e5d9") if state != "hover" else Color("e9cc7a")
		if state == "pressed":
			style.bg_color = Color("b9c8b7")
		if state == "disabled":
			style.bg_color = Color("e7e5dc")
		style.set_corner_radius_all(8)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("ab633e")
			style.set_border_width_all(2)
		skin.set_stylebox(state, "Button", style)
		if state in ["normal", "focus"]:
			skin.set_stylebox(state, "LineEdit", style)
	theme = skin

func _label(text: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _build_ui() -> void:
	var page_scroll := ScrollContainer.new()
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	page_scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("TOWN SOUND / 城市采样", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("♪ 声音设置 / 测试音", func() -> void:
		if recorder.capturing:
			status_label.text = "请先停止录音，再切换声音设备。"
			return
		get_node("/root/SoundSettings").show_dialog()))
	heading.add_child(_label("FIELD NOTES   /   01", 15))
	column.add_child(_label("把今天听见的东西留下来。", 18))
	tutorial_label = _label("")
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tutorial_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 440
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	left.add_child(_label("01  /  TOWN RECORDER", 21))
	var device_row := HBoxContainer.new()
	left.add_child(device_row)
	devices = OptionButton.new()
	devices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	devices.clip_text = true
	devices.item_selected.connect(func(index: int) -> void:
		get_node("/root/SoundSettings").select_input(devices.get_item_text(index)))
	device_row.add_child(devices)
	refresh_button = _button("刷新 / 重试", _refresh_devices)
	device_row.add_child(refresh_button)
	left.add_child(_label("INPUT · 仅在录制时使用麦克风", 14))
	meter = ProgressBar.new()
	meter.max_value = 1.0
	meter.show_percentage = false
	meter.custom_minimum_size.y = 12
	left.add_child(meter)
	timer_label = _label("00:00.00", 48)
	left.add_child(timer_label)
	var transport := HBoxContainer.new()
	left.add_child(transport)
	record_button = _button("●  REC / 录制", _start_recording)
	record_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport.add_child(record_button)
	stop_button = _button("■  STOP / 停止", _stop)
	transport.add_child(stop_button)
	waveform = Waveform.new()
	waveform.custom_minimum_size.y = 74
	left.add_child(waveform)
	left.add_child(_label("NAME THIS SOUND", 14))
	name_input = LineEdit.new()
	name_input.max_length = 60
	name_input.placeholder_text = "例如：下午五点的钥匙"
	left.add_child(name_input)
	var actions := HBoxContainer.new()
	left.add_child(actions)
	preview_button = _button("▶ 试听", _preview_draft)
	actions.add_child(preview_button)
	save_button = _button("保存录音", _save_draft)
	actions.add_child(save_button)
	discard_button = _button("放弃本段", _discard_draft)
	actions.add_child(discard_button)
	left.add_child(_label("每段最长 60 秒 · 本机保存 · 不上传", 14))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	count_label = _label("02  /  RECORDED SOUNDS", 21)
	right.add_child(count_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	library = VBoxContainer.new()
	library.add_theme_constant_override("separation", 10)
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(library)
	status_label = _label("准备好了。选择麦克风，按 REC 开始采样。", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 48
	column.add_child(status_label)
	column.add_child(_button("进入 STUDIO / 编排声音", func() -> void:
		if recorder.capturing or draft != null:
			status_label.text = "请先停止并保存，或放弃当前录音。"
			return
		player.stop()
		var studio = load("res://scripts/studio/StudioScreen.gd").new()
		studio.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(studio)
		margin.hide()
		studio.tree_exited.connect(func() -> void: margin.show())))
	column.add_child(_button("LOCAL RECORDINGS / 唱片店", func() -> void:
		if recorder.capturing or draft != null:
			status_label.text = "请先保存或放弃当前录音。"
			return
		player.stop()
		var shelf = load("res://scripts/record_shop/RecordShelf.gd").new()
		shelf.host = self
		add_child(shelf)
		margin.hide()
		shelf.tree_exited.connect(func() -> void: margin.show())))
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "删除这段录音？"
	delete_dialog.dialog_text = "将从录音库移除，文件会移到本地 samples/trash 回收目录。"
	delete_dialog.confirmed.connect(func() -> void:
		player.stop()
		if store.delete_sample(pending_delete):
			status_label.text = "录音已移到本地回收目录。"
		else:
			status_label.text = store.last_error
		_refresh_library()
		_refresh_controls())
	add_child(delete_dialog)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "还有未保存的录音"
	quit_dialog.dialog_text = "退出会丢弃当前未保存的录音。已保存的录音不会受影响。"
	quit_dialog.ok_button_text = "放弃并退出"
	quit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	add_child(quit_dialog)

func _refresh_devices() -> void:
	devices.clear()
	for device in AudioServer.get_input_device_list():
		devices.add_item(device)
	var selected_device: String = get_node("/root/SoundSettings").input_device
	for index in devices.item_count:
		if devices.get_item_text(index) == selected_device: devices.select(index)
	if devices.item_count == 0:
		status_label.text = "MICROPHONE NOT AVAILABLE · 未找到麦克风，连接设备后点重试。"
	else:
		status_label.text = "录音设备：" + selected_device + "。按 REC 开始采集。"
	_refresh_controls()

func _start_recording() -> void:
	player.stop()
	if draft != null or devices.selected < 0:
		return
	waveform.set_audio(null)
	timer_label.text = "00:00.00"
	if recorder.start(devices.get_item_text(devices.selected)):
		status_label.text = "正在录制 · 录完请按 STOP，最长 60 秒。"
	_refresh_controls()

func _stop() -> void:
	if recorder.capturing:
		recorder.stop()
	else:
		player.stop()
		status_label.text = "已停止试听。"
	_refresh_controls()

func _on_recorded(wav: AudioStreamWAV, warning: String) -> void:
	draft = wav
	waveform.set_audio(wav)
	name_input.text = ""
	status_label.text = warning if not warning.is_empty() else "录好了。听一听，给这段声音起个名字，再保存。"
	meter.value = 0
	_refresh_controls()

func _preview_draft() -> void:
	if draft == null:
		return
	player.stream = draft
	player.play()
	status_label.text = "正在试听未保存的录音。" if audio_peak(draft) > 0.0001 else "这段录音为静音，播放不会出声。请选择麦克风并对着它说话后重录。"
	_refresh_controls()

func _save_draft() -> void:
	var metadata := store.save_sample(draft, name_input.text)
	if metadata.is_empty():
		status_label.text = store.last_error + " 当前录音仍在，可重试。"
		return
	status_label.text = "已保存：「%s」 · %.2f 秒" % [metadata.name, metadata.duration]
	draft = null
	name_input.text = ""
	_refresh_library()
	_refresh_controls()

func _discard_draft() -> void:
	player.stop()
	draft = null
	waveform.set_audio(null)
	name_input.text = ""
	timer_label.text = "00:00.00"
	status_label.text = "已放弃未保存的录音，可以重新录制。"
	_refresh_controls()

func _refresh_library() -> void:
	for child in library.get_children():
		library.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	var items := store.list_samples()
	count_label.text = "02  /  RECORDED SOUNDS  %02d / 20" % items.size()
	var prompts := ["短促的声音：拍手、敲杯子", "持续的声音：水声、风扇", "人的声音：说话、哼唱", "一个你喜欢的奇怪声音"]
	tutorial_label.text = "MAKE A SONG FROM WHERE YOU ARE\n"
	for i in range(4):
		tutorial_label.text += ("✓ " if items.size() > i else "○ ") + str(i + 1) + ". " + prompts[i] + ("    " if i % 2 == 0 else "\n")
	if items.is_empty():
		library.add_child(_label("这里还很安静。\n录下第一种声音，它就会留在这里。", 18))
	for item in items:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		library.add_child(card)
		var label := _label("%s   /   %.2f s%s" % [item.name, item.duration, " · 文件丢失" if item.missing else ""], 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		var row := HBoxContainer.new()
		card.add_child(row)
		var listen := _button("▶", func() -> void: _play_sample(item))
		listen.tooltip_text = "试听这段录音"
		listen.set_meta("missing", item.missing)
		row.add_child(listen)
		row_buttons.append(listen)
		var rename := LineEdit.new()
		rename.text = str(item.name)
		rename.max_length = 60
		rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rename)
		var rename_button := _button("改名", func() -> void:
			if store.rename_sample(item.id, rename.text):
				status_label.text = "名称已保存。"
				_refresh_library()
			else:
				status_label.text = store.last_error
			_refresh_controls())
		row.add_child(rename_button)
		row_buttons.append(rename_button)
		var remove := _button("删除", func() -> void:
			pending_delete = item.id
			delete_dialog.popup_centered())
		row.add_child(remove)
		row_buttons.append(remove)
	if not store.last_error.is_empty():
		status_label.text = store.last_error

func _play_sample(item: Dictionary) -> void:
	var wav := store.load_audio(item)
	if wav == null:
		status_label.text = store.last_error
		return
	waveform.set_audio(wav)
	player.stream = wav
	player.play()
	status_label.text = "正在试听：「%s」" % item.name if audio_peak(wav) > 0.0001 else "「%s」没有声音数据。旧录音无法恢复，请选择实际麦克风后重录。" % item.name
	_refresh_controls()

func audio_peak(wav: AudioStreamWAV) -> float:
	var data := wav.data
	var peak := 0.0
	for frame in data.size() / 2:
		peak = maxf(peak, absf(float(data.decode_s16(frame * 2)) / 32768))
	return peak

func _refresh_controls() -> void:
	if record_button == null:
		return
	var active := recorder.capturing
	record_button.disabled = active or draft != null or devices.item_count == 0 or store.list_samples().size() >= Store.MAX_SAMPLES
	stop_button.disabled = not active and not player.playing
	save_button.disabled = draft == null or active
	preview_button.disabled = draft == null or active
	discard_button.disabled = draft == null or active
	devices.disabled = active
	refresh_button.disabled = active
	name_input.editable = draft != null and not active
	for button in row_buttons:
		button.disabled = active or bool(button.get_meta("missing", false))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if recorder.capturing or draft != null:
			quit_dialog.popup_centered()
		else:
			get_tree().quit()
