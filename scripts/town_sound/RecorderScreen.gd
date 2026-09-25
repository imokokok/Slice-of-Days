extends Control

const Recorder = preload("res://scripts/town_sound/audio/AudioRecorder.gd")
const Store = preload("res://scripts/town_sound/data/SampleStore.gd")
const Waveform = preload("res://scripts/town_sound/audio/WaveformView.gd")
var recorder: FieldRecorder
var store := Store.new()
var player: AudioStreamPlayer
var playback: AudioStreamPlayer
var levels: Array[float] = []
var live_screen: Control
var workspace: Control
var draft: AudioStreamWAV
var source_picker: OptionButton
var device_row: HBoxContainer
var source_hint: Label
var page_scroll: ScrollContainer
var compact_bar: HBoxContainer
var compact := false
var compact_timer: Label
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
var preview_monitor_locked := false
var shop_mode := false
var closing_to_town := false
var previous_auto_accept_quit := true
var draft_context: Dictionary = {}
const Atlas = preload("res://scripts/town_sound/data/SoundAtlas.gd")
var sound_picker: OptionButton
var sound_kind := "wind"
var mv_seed := 23817
var playback_context: Dictionary = {}
var source_player: AudioStreamPlayer
var source_stop: Timer

func _draw() -> void:
	pass # The scene remains visible around the physical recorder and notes.

func _ready() -> void:
	if not shop_mode and not CharacterSystem.owns_pocket_item("recorder"):
		previous_auto_accept_quit=get_tree().auto_accept_quit
		set_process_input(false); set_process_unhandled_input(false); queue_free(); return
	add_to_group("town_sound_workspace")
	add_to_group("meta_modal")
	preload("res://scripts/town_sound/data/LegacyTownSound.gd").migrate()
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_theme()
	recorder = Recorder.new()
	add_child(recorder)
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	playback=player
	add_child(player)
	source_player = AudioStreamPlayer.new()
	source_player.bus = "TownWorldSoundEffects"
	add_child(source_player)
	source_stop = Timer.new(); source_stop.one_shot = true; source_stop.wait_time = 8
	source_stop.timeout.connect(source_player.stop); add_child(source_stop)
	_build_ui()
	get_node("/root/SoundSettings").input_changed.connect(func(_device: String) -> void: _refresh_devices())
	load("res://scripts/town_sound/record_shop/PresetRecords.gd").ensure_presets()
	recorder.meter_changed.connect(func(peak: float, seconds: float) -> void:
		levels.append(peak)
		if levels.size()>95: levels.pop_front()
		waveform.peaks=PackedFloat32Array(levels); waveform.queue_redraw()
		meter.value = clampf((linear_to_db(maxf(peak, 0.00001)) + 60.0) / 60.0, 0.0, 1.0)
		timer_label.text = "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
		compact_timer.text = "● " + timer_label.text)
	recorder.completed.connect(_on_recorded)
	recorder.failed.connect(func(message: String) -> void:
		set_compact(false)
		status_label.text = LocalizationSystem.text(message)
		meter.value = 0
		_refresh_controls())
	player.finished.connect(func() -> void:
		status_label.text = LocalizationSystem.text("试听结束。把今天听见的东西留下来。")
		_refresh_controls())
	_refresh_devices()
	_refresh_library()
	_refresh_controls()

func _build_theme() -> void:
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()

func _label(text: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="paper"
	button.text = LocalizationSystem.text(text)
	button.pressed.connect(action)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _place(node: Control, at: Vector2, extent: Vector2) -> Control:
	node.position=at; node.size=extent; workspace.add_child(node); return node

func _open_studio() -> void:
	if not can_edit_here(): return
	if recorder.capturing or draft != null:
		status_label.text=LocalizationSystem.text("请先停止并保存，或放弃当前录音。"); return
	player.stop()
	var studio=load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	studio.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(studio); page_scroll.hide()
	studio.tree_exited.connect(func(): page_scroll.show())

func _open_record_shelf() -> void:
	if not can_edit_here(): return
	if recorder.capturing or draft != null:
		status_label.text=LocalizationSystem.text("请先保存或放弃当前录音。"); return
	player.stop()
	var shelf=load("res://scripts/town_sound/record_shop/RecordShelf.gd").new(); shelf.host=self
	add_child(shelf); page_scroll.hide(); shelf.tree_exited.connect(func(): page_scroll.show())

func _build_ui() -> void:
	var copy := BackBufferCopy.new(); copy.name="LiveWorldFrame"; copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT; add_child(copy)
	page_scroll=ScrollContainer.new(); page_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(page_scroll)
	workspace=Control.new(); workspace.name="RecorderWorkspace"; workspace.custom_minimum_size=Vector2(1600,900); page_scroll.add_child(workspace)
	var dim := ColorRect.new(); dim.color=Color("e3cbb0"); _place(dim,Vector2.ZERO,Vector2(1600,900))
	var title := _label("我的声音收藏",36); title.add_theme_color_override("font_color",Color("504d3c")); _place(title,Vector2(65,42),Vector2(720,54))
	var help := _label("R 录制 / 停止 · Ctrl+S 保存 · Esc 返回",20); help.add_theme_color_override("font_color",Color("504d3c")); _place(help,Vector2(65,101),Vector2(900,32))
	_place(_button("收起",request_close),Vector2(1385,55),Vector2(150,48))
	sound_picker=OptionButton.new()
	for kind in Atlas.at(GameState.current_location):
		sound_picker.add_item(Atlas.label(kind)); sound_picker.set_item_metadata(sound_picker.item_count-1,kind)
	sound_kind=str(sound_picker.get_item_metadata(0))
	sound_picker.item_selected.connect(func(i:int):
		sound_kind=str(sound_picker.get_item_metadata(i)))
	_place(sound_picker,Vector2(110,253),Vector2(425,45))
	var field_guide := _label("① 选择身边声源   ② 录制并触发声音   ③ 停止、试听、保存",18)
	field_guide.add_theme_color_override("font_color",Color("504d3c"))
	_place(field_guide,Vector2(74,139),Vector2(1400,36))
	var shell := NinePatchRect.new(); shell.name="RecorderBody"
	shell.texture=preload("res://art/town_sound_cc0/panel.png")
	shell.patch_margin_left=6; shell.patch_margin_right=6; shell.patch_margin_top=6; shell.patch_margin_bottom=6
	shell.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; shell.mouse_filter=MOUSE_FILTER_IGNORE
	_place(shell,Vector2(74,226),Vector2(945,528)); workspace.move_child(shell,1)
	_place(_label("随身录音机",27),Vector2(150,337),Vector2(480,38))
	var screen := preload("res://scripts/ui/components/live_sound_window.gd").new()
	screen.source=self; screen.name="LiveRecordingPicture"; live_screen=screen
	_place(screen,Vector2(101,394),Vector2(430,226))
	var caption := _label("实时声景",17); _place(caption,Vector2(151,369),Vector2(400,26))
	meter=ProgressBar.new(); meter.max_value=1; meter.show_percentage=false
	_place(meter,Vector2(101,628),Vector2(430,8))
	source_picker=OptionButton.new(); source_picker.add_item(LocalizationSystem.text("小镇环境声音")); source_picker.add_item(LocalizationSystem.text("麦克风 · 真实人声"))
	source_picker.item_selected.connect(func(_i:int):_refresh_devices()); _place(source_picker,Vector2(576,369),Vector2(400,44))
	source_hint=_label("",17); source_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _place(source_hint,Vector2(579,425),Vector2(386,51))
	device_row=HBoxContainer.new(); _place(device_row,Vector2(576,480),Vector2(400,40))
	devices=OptionButton.new(); devices.size_flags_horizontal=SIZE_EXPAND_FILL; devices.clip_text=true
	devices.item_selected.connect(func(i:int):get_node("/root/SoundSettings").select_input(str(devices.get_item_metadata(i)))); device_row.add_child(devices)
	refresh_button=_button("重试",_refresh_devices); device_row.add_child(refresh_button)
	timer_label=_label("00:00.00",39); _place(timer_label,Vector2(579,521),Vector2(270,54))
	record_button=_button("● 录制",_start_recording); record_button.variant="primary"; _place(record_button,Vector2(576,585),Vector2(164,52))
	stop_button=_button("■ 停止",_stop); _place(stop_button,Vector2(752,585),Vector2(120,52))
	waveform=Waveform.new(); waveform.mouse_filter=MOUSE_FILTER_IGNORE; _place(waveform,Vector2(102,640),Vector2(430,24))
	name_input=LineEdit.new(); name_input.max_length=60; name_input.placeholder_text=LocalizationSystem.text("给这段声音起个名字")
	_place(name_input,Vector2(101,674),Vector2(430,44))
	preview_button=_button("试听",_preview_draft); _place(preview_button,Vector2(576,674),Vector2(105,44))
	save_button=_button("保存录音",_save_draft); save_button.variant="primary"; _place(save_button,Vector2(694,674),Vector2(160,44))
	discard_button=_button("放弃",_discard_draft); _place(discard_button,Vector2(868,674),Vector2(105,44))
	var note := Panel.new(); note.name="RecordingNotes"; note.add_theme_stylebox_override("panel",preload("res://scripts/ui/production_assets.gd").surface(Color("faf5e8"),24))
	_place(note,Vector2(1084,180),Vector2(450,559))
	count_label=_label("声音收藏",26); _place(count_label,Vector2(1116,209),Vector2(390,42))
	tutorial_label=_label("",19); tutorial_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _place(tutorial_label,Vector2(1116,267),Vector2(382,55))
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll,Vector2(1116,348),Vector2(387,355))
	library=VBoxContainer.new(); library.add_theme_constant_override("separation",22); library.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(library)
	_place(_button("触发所选声源 · 8 秒",_trigger_source),Vector2(74,781),Vector2(250,46))
	_place(_button("边逛边录",func():set_compact(true)),Vector2(346,781),Vector2(194,46))
	if can_edit_here():
		_place(_button("去声音手作桌",_open_studio),Vector2(1084,774),Vector2(265,50))
		_place(_button("唱片店",_open_record_shelf),Vector2(1370,774),Vector2(164,50))
	status_label=_label("准备好了。",20); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color",Color("504d3c")); _place(status_label,Vector2(74,845),Vector2(1450,44))
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = LocalizationSystem.text("删除这段录音？")
	delete_dialog.dialog_text = LocalizationSystem.text("将从录音库移除，文件会移到本地 samples/trash 回收目录。")
	delete_dialog.confirmed.connect(func() -> void:
		player.stop()
		if store.delete_sample(pending_delete):
			status_label.text = LocalizationSystem.text("录音已移到本地回收目录。")
		else:
			status_label.text = LocalizationSystem.text(store.last_error)
		_refresh_library()
		_refresh_controls())
	add_child(delete_dialog)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = LocalizationSystem.text("还有未保存的录音")
	quit_dialog.dialog_text = LocalizationSystem.text("退出会丢弃当前未保存的录音。已保存的录音不会受影响。")
	quit_dialog.ok_button_text = LocalizationSystem.text("放弃并退出")
	quit_dialog.confirmed.connect(func() -> void:
		if closing_to_town: queue_free()
		else: get_tree().quit())
	add_child(quit_dialog)
	compact_bar = HBoxContainer.new()
	compact_bar.position = Vector2(920, 88)
	add_child(compact_bar)
	compact_timer = _label("口袋录音机", 20)
	compact_bar.add_child(compact_timer)
	compact_bar.add_child(_button("停止 / 展开", func() -> void:
		if recorder.capturing: recorder.stop()
		set_compact(false)))
	compact_bar.hide()

func can_edit_here() -> bool:
	return shop_mode and has_node("/root/GameState") and get_node("/root/GameState").current_location == "record_store"

func request_close() -> void:
	if recorder.capturing or draft != null:
		closing_to_town = true
		quit_dialog.dialog_text = LocalizationSystem.text("当前这段录音尚未保存。返回小镇会放弃它，已保存素材不受影响。")
		quit_dialog.popup_centered()
	else:
		queue_free()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = previous_auto_accept_quit
	if preview_monitor_locked: get_node("/root/WorldSound").lock_monitor(false)

func _refresh_devices() -> void:
	devices.clear()
	for device in AudioServer.get_input_device_list():
		devices.add_item(_device_display_name(device))
		devices.set_item_metadata(devices.item_count - 1, device)
	var selected_device: String = get_node("/root/SoundSettings").input_device
	for index in devices.item_count:
		if str(devices.get_item_metadata(index)) == selected_device: devices.select(index)
	device_row.visible = source_picker.selected == 1
	source_hint.text = LocalizationSystem.text("直接录下当前地点的游戏背景声与互动音效，不启用麦克风。" if source_picker.selected == 0 else "仅按下 REC 时启用麦克风。建议戴耳机录制人声。")
	if source_picker.selected == 0:
		status_label.text = LocalizationSystem.text("小镇采样已就绪。按 REC，可收起面板边走边录。")
	elif devices.item_count == 0:
		status_label.text = LocalizationSystem.text("MICROPHONE NOT AVAILABLE · 未找到麦克风，连接设备后点重试。")
	else:
		status_label.text = LocalizationSystem.text_with_values("录音设备：%s。按 REC 开始采集。", [_device_display_name(selected_device)])
	_refresh_controls()

func _start_recording() -> void:
	player.stop()
	if draft != null or (source_picker.selected == 1 and devices.selected < 0):
		return
	waveform.set_audio(null)
	levels.clear()
	timer_label.text = "00:00.00"
	var source_mode := "game" if source_picker.selected == 0 else "microphone"
	draft_context = _capture_context(source_mode)
	mv_seed = randi_range(1,999999)
	draft_context["sound_kind"] = sound_kind if source_mode == "game" else "voice"
	draft_context["mv_seed"] = mv_seed
	draft_context["mv_version"] = 3
	draft_context["mv_events"] = [{"time":0.0,"kind":draft_context.sound_kind}]
	if recorder.start(str(devices.get_item_metadata(devices.selected)) if devices.selected >= 0 else "", source_mode):
		WorldSound.play_ui("record_start")
		if source_mode == "game": _trigger_source()
		status_label.text = LocalizationSystem.text("正在录制 · 录完请按 STOP，最长 60 秒。")
	_refresh_controls()

func _device_display_name(device: String) -> String:
	if not TranslationServer.get_locale().begins_with("en"):
		return device
	return device.replace("麦克风", "Microphone").replace("扬声器", "Speakers").replace("耳机", "Headphones").replace("默认", "Default")

func _stop() -> void:
	if recorder.capturing:
		source_player.stop(); source_stop.stop()
		WorldSound.play_ui("record_stop")
		recorder.stop()
	else:
		player.stop()
		status_label.text = LocalizationSystem.text("已停止试听。")
	_refresh_controls()

func _on_recorded(wav: AudioStreamWAV, warning: String) -> void:
	set_compact(false)
	source_player.stop(); source_stop.stop()
	draft = wav
	waveform.set_audio(wav)
	var place := str(draft_context.get("location", "小镇"))
	if has_node("/root/TravelSystem"):
		place = TravelSystem.location_name(place)
	var minute := int(draft_context.get("game_minute", 0))
	name_input.text = "%s %02d:%02d" % [LocalizationSystem.text(place), minute / 60, minute % 60]
	status_label.text = LocalizationSystem.text(warning if not warning.is_empty() else "录好了。听一听，给这段声音起个名字，再保存。")
	meter.value = 0
	_refresh_controls()

func _preview_draft() -> void:
	if draft == null:
		return
	playback_context = draft_context.duplicate(true)
	player.stream = draft
	player.play()
	status_label.text = LocalizationSystem.text("正在试听未保存的录音。" if audio_peak(draft) > 0.0001 else "这段录音为静音，播放不会出声。请检查所选声源后重录。")
	_refresh_controls()

func _save_draft() -> void:
	var metadata := store.save_sample(draft, name_input.text, draft_context)
	if metadata.is_empty():
		status_label.text = LocalizationSystem.text(store.last_error + " 当前录音仍在，可重试。")
		return
	status_label.text = LocalizationSystem.text("已保存：「%s」 · %.2f 秒" % [metadata.name, metadata.duration])
	if has_node("/root/GameState"):
		GameState.add_artifact("samples", {"id": str(metadata.id), "title": str(metadata.name), "kind": "recording", "duration": float(metadata.duration), "location": str(metadata.get("location", ""))})
		GameState.add_journal_entry({"id": "sample_%s" % str(metadata.id), "kind": "recording", "text": "在%s录下「%s」并保存在本机。" % [TravelSystem.location_name(str(metadata.get("location", GameState.current_location))), str(metadata.name)]})
		SaveManager.save_or_report("录音后保存失败")
	draft = null
	draft_context.clear()
	name_input.text = ""
	_refresh_library()
	_refresh_controls()

func _discard_draft() -> void:
	player.stop()
	draft = null
	draft_context.clear()
	waveform.set_audio(null)
	name_input.text = ""
	timer_label.text = "00:00.00"
	status_label.text = LocalizationSystem.text("已放弃未保存的录音，可以重新录制。")
	_refresh_controls()

func _refresh_library() -> void:
	for child in library.get_children():
		library.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	var items := store.list_samples()
	count_label.text=LocalizationSystem.text("声音收藏  ·  %02d / 20"%items.size())
	tutorial_label.text=LocalizationSystem.text("把听见的片刻留在这里。\n保存后，可以带去唱片店编排。")
	if items.is_empty():
		library.add_child(_label("这里还很安静。\n录下第一种声音，它就会留在这里。", 18))
	for item in items:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		library.add_child(card)
		var memory := _sample_memory_text(item)
		var label := _label("%s   /   %.2f s%s\n%s" % [item.name, item.duration, " · 文件丢失" if item.missing else "", memory], 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		var row := HBoxContainer.new()
		card.add_child(row)
		var listen := _button("▶", func() -> void: _play_sample(item))
		listen.tooltip_text = LocalizationSystem.text("试听这段录音")
		listen.set_meta("missing", item.missing)
		row.add_child(listen)
		row_buttons.append(listen)
		var rename := LineEdit.new()
		rename.text = LocalizationSystem.text(str(item.name))
		rename.max_length = 60
		rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename.custom_minimum_size.x=110
		row.add_child(rename)
		var rename_button := _button("改名", func() -> void:
			if store.rename_sample(item.id, rename.text):
				status_label.text = LocalizationSystem.text("名称已保存。")
				_refresh_library()
			else:
				status_label.text = LocalizationSystem.text(store.last_error)
			_refresh_controls())
		row.add_child(rename_button)
		row_buttons.append(rename_button)
		var remove := _button("删除", func() -> void:
			pending_delete = item.id
			delete_dialog.popup_centered())
		row.add_child(remove)
		row_buttons.append(remove)
	if not store.last_error.is_empty():
		status_label.text = LocalizationSystem.text(store.last_error)


func _capture_context(source_mode: String) -> Dictionary:
	var context := {
		"source_mode": source_mode,
		"usage_scope": "local_only" if source_mode == "microphone" else "game_world",
		"consent_status": "not_required" if source_mode == "game" else "private_capture",
	}
	if not has_node("/root/GameState"):
		return context
	context["role"] = GameState.current_role
	context["game_day"] = GameState.current_day
	context["game_minute"] = GameState.current_minute
	context["location"] = GameState.current_location
	context["nearby_npcs"] = DialogueSystem.people_at(GameState.current_location, SceneRouter.active_space_id)
	if not context["nearby_npcs"].is_empty():
		context["usage_scope"] = "local_only"
		context["consent_status"] = "contains_nearby_residents"
	context["event_tag"] = GameState.completed_events[-1] if not GameState.completed_events.is_empty() else ""
	return context


func _sample_memory_text(item: Dictionary) -> String:
	var role := str(item.get("role", ""))
	var location := str(item.get("location", ""))
	var day := int(item.get("game_day", 0))
	var minute := int(item.get("game_minute", 0))
	var local_only := str(item.get("usage_scope", "local_only")) == "local_only"
	var source := "真实人声 · 仅本地" if str(item.get("source_mode", "")) == "microphone" else "游戏声景"
	if local_only and str(item.get("source_mode", "")) != "microphone":
		source += " · 含在场居民，仅本地"
	if role.is_empty() or day <= 0:
		return source + " · 旧录音未记录小镇来源"
	var place := location
	if has_node("/root/TravelSystem"):
		place = TravelSystem.location_name(location)
	var credit := role+"采集 · " if has_node("/root/CharacterSystem") and CharacterSystem.switch_unlocked() else ""
	return credit+"第%d天 %02d:%02d · %s · %s" % [day, minute / 60, minute % 60, place, source]

func _play_sample(item: Dictionary) -> void:
	var wav := store.load_audio(item)
	if wav == null:
		status_label.text = LocalizationSystem.text(store.last_error)
		return
	playback_context = item
	waveform.set_audio(wav)
	player.stream = wav
	player.play()
	status_label.text = LocalizationSystem.text("正在试听：「%s」" % item.name if audio_peak(wav) > 0.0001 else "「%s」没有声音数据。旧录音无法恢复，请检查所选声源后重录。" % item.name)
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
	if preview_monitor_locked != player.playing:
		preview_monitor_locked = player.playing
		get_node("/root/WorldSound").lock_monitor(preview_monitor_locked)
	var active := recorder.capturing
	record_button.disabled = active or draft != null or (source_picker.selected == 1 and devices.item_count == 0) or store.list_samples().size() >= Store.MAX_SAMPLES
	stop_button.disabled = not active and not player.playing
	save_button.disabled = draft == null or active
	preview_button.disabled = draft == null or active
	discard_button.disabled = draft == null or active
	source_picker.disabled = active or draft != null
	devices.disabled = active
	refresh_button.disabled = active
	name_input.editable = draft != null and not active
	for button in row_buttons:
		button.disabled = active or bool(button.get_meta("missing", false))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		closing_to_town = false
		if recorder.capturing or draft != null:
			quit_dialog.popup_centered()
		else:
			get_tree().quit()

func set_compact(value: bool) -> void:
	compact = value
	page_scroll.visible = not value
	compact_bar.visible = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not page_scroll.visible and not compact: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_command_or_control_pressed() and event.keycode == KEY_S:
		if draft != null and not recorder.capturing:
			_save_draft()
	elif event.is_action_pressed("open_recorder"):
		if recorder.capturing:
			_stop()
		elif draft == null:
			_start_recording()
	elif event.is_action_pressed("ui_cancel"):
		request_close()
	get_viewport().set_input_as_handled()

func _trigger_source() -> void:
	if source_picker.selected != 0:
		status_label.text = "当前是麦克风输入，请说话或哼唱；游戏声源请切换回小镇环境声音。"
		return
	source_player.stream = Atlas.stream(sound_kind)
	if source_player.stream == null:
		status_label.text = "这段声源暂时无法读取，请选择另一种。"
		return
	source_player.volume_db = -8
	if AudioServer.get_driver_name() != "Dummy": source_player.play()
	source_stop.start()
	if recorder.capturing:
		draft_context.mv_events.append({"time":float(recorder.frame_count)/recorder.sample_rate,"kind":sound_kind})
	status_label.text = "正在听：" + Atlas.label(sound_kind) + (" · 录音中，停止后保存。" if recorder.capturing else " · 按录制，把它留进声音收藏。")

func current_mv_kind() -> String:
	var context := draft_context if recorder.capturing or not player.playing else playback_context
	var at := float(recorder.frame_count)/recorder.sample_rate if recorder.capturing else player.get_playback_position()
	var kind := str(context.get("sound_kind", sound_kind))
	for event in context.get("mv_events",[]):
		if float(event.get("time",0)) <= at: kind=str(event.get("kind",kind))
	return kind

func current_mv_seed() -> int:
	var context:=playback_context if player.playing else draft_context
	return int(context.get("mv_seed",mv_seed))
