extends Control
var recorder: FieldRecorder
var status: Label
var marks: Array = []
var levels: Array[float] = []
var close_after := false
var pending_wav: AudioStreamWAV
var pending_sample: Dictionary = {}
var saved := false
var store_path := "user://samples"
var record_button: Button
var mark_button: Button
var face: Control
var compact_button: Button
var play_button: Button
var playback: AudioStreamPlayer
var focus_active := true
var live_screen: Control
const Atlas = preload("res://scripts/town_sound/data/SoundAtlas.gd")
var sound_kind := "wind"
var mv_seed := 23817
var mv_events: Array = []
var sound_picker: OptionButton
var source_picker: OptionButton
var source_player: AudioStreamPlayer
var source_stop: Timer
var record_context: Dictionary = {}

func _ready() -> void:
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	add_to_group("world_tool")
	add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_IGNORE
	recorder=FieldRecorder.new(); add_child(recorder)
	recorder.input_gain=float(GameState.artifacts.get("recorder_gain",1.0))
	source_player=AudioStreamPlayer.new(); source_player.bus="TownWorldSoundEffects"; add_child(source_player)
	source_stop=Timer.new(); source_stop.one_shot=true; source_stop.wait_time=8; source_stop.timeout.connect(source_player.stop); add_child(source_stop)
	playback=AudioStreamPlayer.new(); playback.bus="Music"; add_child(playback)
	playback.finished.connect(func(): play_button.text=LocalizationSystem.text("试听"))
	# Copy the actual scene before the recorder body draws. The view below
	# reads this frame, so it cannot recursively photograph its own screen.
	var world_frame := BackBufferCopy.new(); world_frame.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	world_frame.name="LiveWorldFrame"; add_child(world_frame)
	face=Control.new(); face.position=Vector2(300,140); face.size=Vector2(1000,600); face.mouse_filter=MOUSE_FILTER_IGNORE; add_child(face)
	var shell := NinePatchRect.new(); shell.texture=preload("res://art/town_sound_cc0/panel.png")
	shell.patch_margin_left=6; shell.patch_margin_right=6; shell.patch_margin_top=6; shell.patch_margin_bottom=6
	shell.size=Vector2(1000,490); shell.position=Vector2(0,110); shell.mouse_filter=MOUSE_FILTER_IGNORE
	shell.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; face.add_child(shell)
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(face,"FIELD NOTES / 随身录音机",Vector2(75,155),650,26)
	sound_picker=OptionButton.new(); sound_picker.position=Vector2(75,108); sound_picker.size=Vector2(458,40); face.add_child(sound_picker)
	for kind in Atlas.at(GameState.current_location):
		sound_picker.add_item(Atlas.label(kind)); sound_picker.set_item_metadata(sound_picker.item_count-1,kind)
	sound_kind=str(sound_picker.get_item_metadata(0))
	sound_picker.item_selected.connect(func(i:int): sound_kind=str(sound_picker.get_item_metadata(i)))
	source_picker=OptionButton.new(); source_picker.position=Vector2(580,215); source_picker.size=Vector2(338,40)
	source_picker.add_item("小镇声源（默认）"); source_picker.add_item("真实人声 · 麦克风")
	face.add_child(source_picker)
	_button("触发声源",Vector2(580,485),Vector2(210,38),trigger_source)
	p.words(face,"选择声源 → 录制 → 停止自动保存 → 唱片店编曲",Vector2(75,68),900,18)
	status=p.words(face,"留下此刻听见的声音",Vector2(110,523),608,19)
	var screen = preload("res://scripts/ui/components/live_sound_window.gd").new(); screen.source=self; screen.position=Vector2(75,241); screen.size=Vector2(458,260)
	screen.name="LiveRecordingPicture"; live_screen=screen
	var style := StyleBoxFlat.new(); style.bg_color=Color("e6e7d8"); style.set_corner_radius_all(5); style.set_border_width_all(2); style.border_color=Color("8b8264")
	screen.add_theme_stylebox_override("panel",style); screen.mouse_filter=MOUSE_FILTER_IGNORE; face.add_child(screen)
	var window_words := p.words(face,"实时画面 · 随声音变化",Vector2(95,215),414,16)
	window_words.add_theme_color_override("font_color",p.MUTED)
	record_button=_button("● 开始录音",Vector2(580,338),Vector2(210,65),toggle_recording)
	record_button.name="RecordToggle"
	mark_button=_button("留下标记",Vector2(580,435),Vector2(210,43),mark_recording); mark_button.disabled=true
	_button("收起",Vector2(795,151),Vector2(126,38),finish_for_exit)
	_button("录音收藏",Vector2(750,525),Vector2(160,39),_open_library)
	play_button=_button("试听",Vector2(580,269),Vector2(100,40),_play_last)
	play_button.disabled=true
	_button("边走边录",Vector2(703,269),Vector2(155,40),_toggle_compact)
	var knob=preload("res://scripts/ui/components/recorder_knob.gd").new()
	knob.position=Vector2(831,343); knob.size=Vector2(84,84); knob.name="RecordingGain"; face.add_child(knob)
	knob.value=recorder.input_gain; knob.accessibility_name=LocalizationSystem.text("录音增益")
	var gain_caption=p.words(face,"增益 × %.2f"%knob.value,Vector2(811,431),145,17)
	knob.value_changed.connect(func(v: float):
		recorder.input_gain=v; GameState.artifacts.recorder_gain=v; gain_caption.text=LocalizationSystem.text("增益 × %.2f"%v))
	compact_button=preload("res://scripts/ui/components/solmere_button.gd").new()
	compact_button.text="录音机 · 展开"; compact_button.variant="paper"; compact_button.position=Vector2(1300,775); compact_button.size=Vector2(258,68); compact_button.hide(); add_child(compact_button)
	compact_button.pressed.connect(_toggle_compact)
	recorder.meter_changed.connect(func(peak: float, seconds: float):
		levels.append(peak)
		if levels.size()>95: levels.pop_front()
		status.text=LocalizationSystem.text("● %02d:%02d   %s · %d 个标记" % [int(seconds)/60,int(seconds)%60,TravelSystem.location_name(GameState.current_location),marks.size()])
		compact_button.text=LocalizationSystem.text("● %02d:%02d · 展开录音机"%[int(seconds)/60,int(seconds)%60])
		record_button.text=LocalizationSystem.text("■ 停止并保存"); mark_button.disabled=false
		queue_redraw())
	recorder.completed.connect(_complete)
	recorder.failed.connect(func(message: String):
		source_player.stop(); source_stop.stop(); source_picker.disabled=false
		status.text=LocalizationSystem.text(message); close_after=false
		record_button.text="● 重新录音"; mark_button.disabled=true
		play_button.disabled=playback.stream==null)
	preload("res://scripts/ui/solmere_motion.gd").paper_open(face,SettingsSystem.reduced_motion())

func _button(words: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=words; b.position=at; b.size=extent; b.variant="outlined"; face.add_child(b); b.pressed.connect(action); return b

func _toggle_compact() -> void:
	face.visible=not face.visible; compact_button.visible=not face.visible
	focus_active=face.visible
	if face.visible: preload("res://scripts/ui/solmere_motion.gd").paper_open(face,SettingsSystem.reduced_motion())
	if not face.visible: get_viewport().gui_release_focus()
	queue_redraw()

func _open_library() -> void:
	get_parent().show_recording_library()

func _play_last() -> void:
	if playback.stream==null: return
	if playback.playing: playback.stop(); play_button.text="试听"
	else: playback.play(); play_button.text="停止试听"

func _complete(wav: AudioStreamWAV, warning: String) -> void:
	source_player.stop(); source_stop.stop(); source_picker.disabled=false
	playback.stream=wav; play_button.disabled=false
	pending_wav = wav
	saved = false
	_save(warning)

func _save(warning := "") -> void:
	if pending_wav == null: return
	var store := SampleStore.new(store_path)
	var item := pending_sample
	if item.is_empty(): item=store.save_sample(pending_wav,TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text(),record_context.merged({"markers":marks,"mv_events":mv_events},true))
	if item.is_empty(): status.text = LocalizationSystem.text(store.last_error+"\n"+SettingsSystem.binding_text("open_recorder")+" 重试保存"); record_button.text="重试保存"; mark_button.disabled=true; close_after = false; return
	pending_sample=item
	var before := GameState.to_save_data().duplicate(true)
	GameState.add_artifact("samples",{"id":str(item.id),"title":str(item.name),"duration":float(item.duration),"day":GameState.current_day,"location":GameState.current_location,"markers":marks.duplicate()})
	if not ResidencySystem.persist():
		GameState.load_save_data(before); status.text="声音文件已保留，但存档未写入。请重试保存。"; record_button.text="重试保存"; close_after=false; return
	pending_wav = null
	pending_sample={}
	saved = true
	record_button.text=LocalizationSystem.text("● 再录一段"); mark_button.disabled=true
	status.text = LocalizationSystem.text("已保存到录音机\n"+warning)
	if close_after: queue_free()
	else: status.text=LocalizationSystem.text("已保存到录音机，可以继续录制。")

func _dismiss_saved() -> void:
	await get_tree().create_timer(0.8).timeout
	if saved and pending_wav == null and not recorder.capturing: queue_free()

func finish_for_exit() -> bool:
	# Preserve unsaved audio if storage failed. The R retry stays available.
	if pending_wav != null: return false
	if recorder.capturing:
		close_after = true
		recorder.stop()
		if pending_wav != null: return false
	if not ResidencySystem.persist(): return false
	queue_free()
	return true

func toggle_recording() -> void:
	WorldSound.play_ui("record_stop" if recorder.capturing else "record_start")
	if pending_wav!=null: _save()
	elif recorder.capturing: recorder.stop()
	else:
		playback.stop(); play_button.text="试听"; saved=false; marks.clear(); levels.clear()
		mv_seed=randi_range(1,999999)
		var mode:="game" if source_picker.selected==0 else "microphone"
		record_context={"role":GameState.current_role,"game_day":GameState.current_day,"game_minute":GameState.current_minute,"location":GameState.current_location,"source_mode":mode,"consent_status":"game_audio" if mode=="game" else "user_voice","usage_scope":"local_game","sound_kind":sound_kind if mode=="game" else "voice","mv_seed":mv_seed,"mv_version":3}
		mv_events=[{"time":0.0,"kind":record_context.sound_kind}]
		if recorder.start(SoundSettings.input_device,mode):
			source_picker.disabled=true
			play_button.disabled=true
			if mode=="game": trigger_source()
func mark_recording() -> void:
	if recorder.capturing: marks.append(snappedf(recorder.elapsed,.01))
func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("open_recorder"): toggle_recording()
	elif event.is_action_pressed("record_mark"): mark_recording()
	elif event.is_action_pressed("ui_cancel"): finish_for_exit()
	else: return
	get_viewport().set_input_as_handled()

func trigger_source() -> void:
	if source_picker.selected!=0: status.text="麦克风模式，请对着设备说话。"; return
	source_player.stream=Atlas.stream(sound_kind)
	source_player.volume_db=-8
	if source_player.stream!=null and AudioServer.get_driver_name()!="Dummy": source_player.play()
	source_stop.start()
	if recorder.capturing: mv_events.append({"time":float(recorder.frame_count)/recorder.sample_rate,"kind":sound_kind})
	status.text="正在听："+Atlas.label(sound_kind)+" · 录制后自动保存声音和同步影像。"

func current_mv_kind() -> String:
	var kind:=str(record_context.get("sound_kind",sound_kind))
	var at:=float(recorder.frame_count)/recorder.sample_rate if recorder.capturing else playback.get_playback_position()
	for event in mv_events:
		if float(event.time)<=at: kind=str(event.kind)
	return kind
