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
	theme.set_constant("paragraph_spacing","Label",0)
	theme.set_constant("line_spacing","Label",2)
	add_to_group("world_tool")
	add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_IGNORE
	recorder=FieldRecorder.new(); add_child(recorder)
	recorder.input_gain=1.0
	source_player=AudioStreamPlayer.new(); source_player.bus="TownWorldSoundEffects"; add_child(source_player)
	source_stop=Timer.new(); source_stop.one_shot=true; source_stop.wait_time=8; source_stop.timeout.connect(source_player.stop); add_child(source_stop)
	playback=AudioStreamPlayer.new(); playback.bus="Music"; add_child(playback)
	playback.finished.connect(func(): play_button.text=LocalizationSystem.text("试听"))
	face=Control.new(); face.size=Vector2(1200,720); face.mouse_filter=MOUSE_FILTER_STOP; add_child(face)
	resized.connect(_fit_face); _fit_face()
	var shell:=Panel.new(); shell.size=face.size; shell.mouse_filter=MOUSE_FILTER_IGNORE
	var paper:=StyleBoxFlat.new(); paper.bg_color=Color("f4e6ca"); paper.set_corner_radius_all(32)
	paper.set_border_width_all(4); paper.border_color=Color("aa9275"); paper.shadow_color=Color("6f5943",.2); paper.shadow_size=12
	shell.add_theme_stylebox_override("panel",paper); face.add_child(shell)
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(face,"今天，听见了什么？",Vector2(42,26),830,32)
	p.words(face,"声音采集  /  留住一段声音，也留住它的画面",Vector2(44,78),980,19)
	_button("收进口袋",Vector2(992,29),Vector2(165,44),finish_for_exit)
	sound_picker=OptionButton.new(); sound_picker.position=Vector2(44,131); sound_picker.size=Vector2(670,46); face.add_child(sound_picker)
	for kind in Atlas.at(GameState.current_location):
		sound_picker.add_item(Atlas.label(kind)); sound_picker.set_item_metadata(sound_picker.item_count-1,kind)
	sound_kind=str(sound_picker.get_item_metadata(0))
	sound_picker.item_selected.connect(func(i:int): sound_kind=str(sound_picker.get_item_metadata(i)); live_screen.queue_redraw())
	var screen=preload("res://scripts/ui/components/live_sound_window.gd").new()
	screen.source=self; screen.position=Vector2(44,193); screen.size=Vector2(670,377); screen.name="LiveRecordingPicture"
	live_screen=screen; face.add_child(screen)
	p.words(face,"声音明信片 · 录制和试听时一起变化",Vector2(48,582),660,19)
	source_picker=OptionButton.new(); source_picker.position=Vector2(758,135); source_picker.size=Vector2(399,44)
	source_picker.add_item("小镇环境声 · 默认"); source_picker.add_item("我想录人声 · 麦克风"); face.add_child(source_picker)
	p.words(face,"① 挑一种声音\n② 按圆键开始，再按一次保存\n③ 去唱片店，把声音剪贴成唱片",Vector2(759,209),396,21)
	record_button=preload("res://scripts/town_sound/studio/RecordKey.gd").new()
	record_button.position=Vector2(867,326); record_button.size=Vector2(136,136)
	record_button.text="● 开始录音"; record_button.name="RecordToggle"; record_button.accessibility_name="开始 / 停止并保存录音"
	face.add_child(record_button); record_button.pressed.connect(toggle_recording)
	p.words(face,"按下录制 / 再按保存",Vector2(822,475),290,19)
	play_button=_button("▶ 听听刚才",Vector2(760,529),Vector2(186,48),_play_last); play_button.disabled=true
	_button("边走边录",Vector2(962,529),Vector2(190,48),_toggle_compact)
	_button("我的声音收藏",Vector2(760,590),Vector2(392,46),_open_library)
	# Marker metadata remains readable for old recordings; the beginner surface has no marker tool.
	mark_button=Button.new(); mark_button.hide(); mark_button.disabled=true; face.add_child(mark_button)
	status=p.words(face,"准备好就按圆键。录到的声音和画面会一起留在本机。",Vector2(46,642),1100,21)
	compact_button=preload("res://scripts/ui/components/solmere_button.gd").new()
	compact_button.text="录音机 · 展开"; compact_button.variant="paper"; compact_button.position=Vector2(1300,775); compact_button.size=Vector2(258,68); compact_button.hide(); add_child(compact_button)
	compact_button.pressed.connect(_toggle_compact)
	recorder.meter_changed.connect(func(peak: float, seconds: float):
		levels.append(peak)
		if levels.size()>95: levels.pop_front()
		status.text=LocalizationSystem.text("● %02d:%02d  正在留下%s的声音 · 再按圆键停止并保存" % [int(seconds)/60,int(seconds)%60,TravelSystem.location_name(GameState.current_location)])
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

func _fit_face() -> void:
	if face==null: return
	var factor:=minf(1.0,minf((size.x-64)/1200.0,(size.y-64)/720.0))
	face.scale=Vector2.ONE*factor; face.position=(size-Vector2(1200,720)*factor)*.5

func _button(words: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=words; b.position=at; b.size=extent; b.variant="outlined"; face.add_child(b); b.pressed.connect(action); return b

func _toggle_compact() -> void:
	face.visible=not face.visible; compact_button.visible=not face.visible
	focus_active=face.visible
	if face.visible: preload("res://scripts/ui/solmere_motion.gd").paper_open(face,SettingsSystem.reduced_motion())
	if not face.visible: get_viewport().gui_release_focus()
	queue_redraw()

func _open_library() -> void:
	if recorder.capturing or pending_wav!=null: status.text="先停止并保存这一段，再打开收藏。"; return
	if get_parent().has_method("show_recording_library"): get_parent().show_recording_library()

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
	else: status.text=LocalizationSystem.text("✓ 声音和画面已保存。先听听看，再带去唱片店的声音手作桌。")

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

func current_mv_seed() -> int:
	return mv_seed
