extends Node
## App-only device routing. Does not change Windows sound/privacy settings.
const PATH := "user://audio_settings.cfg"
var input_device := "Default"
var output_device := "Default"
var panel: AcceptDialog
var input_picker: OptionButton
var output_picker: OptionButton
var message: Label
var test_player: AudioStreamPlayer
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var mute_button: Button
signal input_changed(device: String)

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	input_device = choose_device(AudioServer.get_input_device_list(), str(config.get_value("audio", "input", "")))
	output_device = choose_device(AudioServer.get_output_device_list(), str(config.get_value("audio", "output", "")))
	apply_devices()
	test_player = AudioStreamPlayer.new()
	test_player.bus = "SoundEffects"
	add_child(test_player)
	SettingsSystem.audio_settings_changed.connect(_on_audio_settings_changed)

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

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "input", input_device)
	config.set_value("audio", "output", output_device)
	config.save(PATH)

func select_input(device: String) -> void:
	input_device = device
	AudioServer.input_device = device
	save_settings()
	input_changed.emit(device)

func show_dialog() -> void:
	if panel == null: build_dialog()
	_sync_volume_controls()
	fill_picker(input_picker, AudioServer.get_input_device_list(), input_device)
	fill_picker(output_picker, AudioServer.get_output_device_list(), output_device)
	message.text = LocalizationSystem.text("先点测试音确认输出，再选择麦克风重新录一段。\n全静音的旧录音无法恢复声音，需要重新录制。")
	panel.popup_centered(Vector2i(650, 470))

func fill_picker(picker: OptionButton, devices: PackedStringArray, current: String) -> void:
	picker.clear()
	for device in devices:
		picker.add_item(device_display_name(device))
		picker.set_item_metadata(picker.item_count - 1, device)
		if device == current: picker.select(picker.item_count - 1)

func build_dialog() -> void:
	panel = AcceptDialog.new()
	panel.title = LocalizationSystem.text("Town Sound · 声音设置")
	panel.ok_button_text = LocalizationSystem.text("完成")
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var output_label := Label.new()
	output_label.text = LocalizationSystem.text("播放设备 / 扬声器或耳机")
	column.add_child(output_label)
	output_picker = OptionButton.new()
	output_picker.item_selected.connect(func(index: int) -> void:
		output_device = str(output_picker.get_item_metadata(index))
		AudioServer.output_device = output_device
		save_settings()
		message.text = LocalizationSystem.text_with_values("已选择：%s。点击测试音。", [device_display_name(output_device)]))
	column.add_child(output_picker)
	var test := Button.new()
	test.text = LocalizationSystem.text("♪ 播放测试音（两声）")
	test.pressed.connect(play_test_tone)
	column.add_child(test)
	_add_volume_control(column, "master", "主音量", SettingsSystem.master_volume(), SettingsSystem.set_master_volume)
	_add_volume_control(column, "music", "音乐音量", SettingsSystem.music_volume(), SettingsSystem.set_music_volume)
	_add_volume_control(column, "sound_effects", "音效音量", SettingsSystem.sound_effects_volume(), SettingsSystem.set_sound_effects_volume)
	mute_button = Button.new()
	mute_button.pressed.connect(func() -> void: SettingsSystem.set_audio_muted(not SettingsSystem.is_audio_muted()))
	column.add_child(mute_button)
	var input_label := Label.new()
	input_label.text = LocalizationSystem.text("录音设备 / 麦克风")
	column.add_child(input_label)
	input_picker = OptionButton.new()
	input_picker.item_selected.connect(func(index: int) -> void: select_input(str(input_picker.get_item_metadata(index))))
	column.add_child(input_picker)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	_sync_volume_controls()


func device_display_name(device: String) -> String:
	if not TranslationServer.get_locale().begins_with("en"):
		return device
	return device.replace("麦克风", "Microphone").replace("扬声器", "Speakers").replace("耳机", "Headphones").replace("默认", "Default")


func _add_volume_control(parent: VBoxContainer, key: String, title: String, value: int, setter: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title_label := Label.new()
	title_label.text = LocalizationSystem.text(title)
	title_label.custom_minimum_size.x = 120
	row.add_child(title_label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.tooltip_text = LocalizationSystem.text("%s，0 到 100" % title)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % value
	row.add_child(value_label)
	volume_sliders[key] = slider
	volume_labels[key] = value_label
	slider.value_changed.connect(func(changed_value: float) -> void:
		setter.call(changed_value)
		value_label.text = "%d%%" % int(round(changed_value)))


func _on_audio_settings_changed(_master: int, _music: int, _sound_effects: int, _muted: bool) -> void:
	_sync_volume_controls()


func _sync_volume_controls() -> void:
	if volume_sliders.is_empty():
		return
	var current := {
		"master": SettingsSystem.master_volume(),
		"music": SettingsSystem.music_volume(),
		"sound_effects": SettingsSystem.sound_effects_volume(),
	}
	for key in current:
		var slider := volume_sliders.get(key) as HSlider
		var value_label := volume_labels.get(key) as Label
		if slider != null:
			slider.set_value_no_signal(float(current[key]))
		if value_label != null:
			value_label.text = "%d%%" % int(current[key])
	if mute_button != null:
		mute_button.text = LocalizationSystem.text("取消静音" if SettingsSystem.is_audio_muted() else "全部静音")

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
		message.text = LocalizationSystem.text_with_values("测试音输出到：%s\n若仍听不到，换一个输出设备，并检查系统音量。", [device_display_name(output_device)]) if AudioServer.get_driver_name() != "Dummy" else LocalizationSystem.text("当前没有可用的音频输出驱动。")
