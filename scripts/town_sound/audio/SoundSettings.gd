extends Node
## App-only device routing. Does not change Windows sound/privacy settings.
const PATH := "user://audio_settings.cfg"
var input_device := "Default"
var output_device := "Default"
var volume := 0.8
var panel: AcceptDialog
var input_picker: OptionButton
var output_picker: OptionButton
var message: Label
var test_player: AudioStreamPlayer
signal input_changed(device: String)

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	input_device = choose_device(AudioServer.get_input_device_list(), str(config.get_value("audio", "input", "")))
	output_device = choose_device(AudioServer.get_output_device_list(), str(config.get_value("audio", "output", "")))
	volume = clampf(float(config.get_value("audio", "volume", 0.8)), 0, 1)
	if has_node("/root/SettingsSystem"):
		volume = float(get_node("/root/SettingsSystem").master_volume()) / 100
	apply_devices()
	test_player = AudioStreamPlayer.new()
	add_child(test_player)

static func choose_device(available: PackedStringArray, saved: String) -> String:
	if not saved.is_empty() and available.has(saved): return saved
	# Prefer a named hardware endpoint on first launch over an ambiguous default
	# or remote desktop loopback endpoint. The player can explicitly choose any.
	for candidate in available:
		var name_lower := candidate.to_lower()
		if candidate != "Default" and not name_lower.contains("virtual") and not name_lower.contains("todesk"):
			return candidate
	return "Default"

func apply_devices() -> void:
	AudioServer.input_device = input_device
	AudioServer.output_device = output_device
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.00001)))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "input", input_device)
	config.set_value("audio", "output", output_device)
	config.set_value("audio", "volume", volume)
	config.save(PATH)

func select_input(device: String) -> void:
	input_device = device
	AudioServer.input_device = device
	save_settings()
	input_changed.emit(device)

func show_dialog() -> void:
	if panel == null: build_dialog()
	fill_picker(input_picker, AudioServer.get_input_device_list(), input_device)
	fill_picker(output_picker, AudioServer.get_output_device_list(), output_device)
	message.text = "先点测试音确认输出，再选择麦克风重新录一段。\n全静音的旧录音无法恢复声音，需要重新录制。"
	panel.popup_centered(Vector2i(650, 340))

func fill_picker(picker: OptionButton, devices: PackedStringArray, current: String) -> void:
	picker.clear()
	for device in devices:
		picker.add_item(device)
		if device == current: picker.select(picker.item_count - 1)

func build_dialog() -> void:
	panel = AcceptDialog.new()
	panel.title = "Town Sound · 声音设置"
	panel.ok_button_text = "完成"
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var output_label := Label.new()
	output_label.text = "播放设备 / 扬声器或耳机"
	column.add_child(output_label)
	output_picker = OptionButton.new()
	output_picker.item_selected.connect(func(index: int) -> void:
		output_device = output_picker.get_item_text(index)
		AudioServer.output_device = output_device
		save_settings()
		message.text = "已选择：" + output_device + "。点击测试音。")
	column.add_child(output_picker)
	var test := Button.new()
	test.text = "♪ 播放测试音（两声）"
	test.pressed.connect(play_test_tone)
	column.add_child(test)
	var volume_row := HBoxContainer.new()
	column.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "游戏音量 %d%%" % int(volume * 100)
	volume_row.add_child(volume_label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.max_value = 1
	slider.step = 0.01
	slider.value = volume
	slider.value_changed.connect(func(value: float) -> void:
		volume = value
		if has_node("/root/SettingsSystem"):
			get_node("/root/SettingsSystem").set_master_volume(value * 100)
		AudioServer.set_bus_mute(0, volume <= 0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.00001)))
		volume_label.text = "游戏音量 %d%%" % int(volume * 100)
		save_settings())
	volume_row.add_child(slider)
	var input_label := Label.new()
	input_label.text = "录音设备 / 麦克风"
	column.add_child(input_label)
	input_picker = OptionButton.new()
	input_picker.item_selected.connect(func(index: int) -> void: select_input(input_picker.get_item_text(index)))
	column.add_child(input_picker)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)

func play_test_tone() -> void:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 44100
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var data := PackedByteArray()
	data.resize(44100 * 2)
	for i in 44100:
		var time := float(i) / 44100
		var start := 0.0 if time < 0.5 else 0.5
		var local_time := time - start
		var envelope := 0.0
		if local_time < 0.3:
			envelope = minf(local_time / 0.02, 1) * minf((0.3 - local_time) / 0.04, 1)
		var frequency := 440.0 if time < 0.5 else 660.0
		data.encode_s16(i * 2, int(sin(time * TAU * frequency) * envelope * 0.2 * 32767))
	wav.data = data
	test_player.stream = wav
	if AudioServer.get_driver_name() != "Dummy":
		test_player.play()
	if message != null:
		message.text = "测试音输出到：" + output_device + "\n若仍听不到，换一个输出设备，并检查系统音量。" if AudioServer.get_driver_name() != "Dummy" else "当前没有可用的音频输出驱动。"
