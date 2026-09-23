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

func _ready() -> void:
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	add_to_group("world_tool")
	add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_IGNORE
	recorder=FieldRecorder.new(); add_child(recorder)
	recorder.input_gain=float(GameState.artifacts.get("recorder_gain",1.0))
	playback=AudioStreamPlayer.new(); playback.bus="Music"; add_child(playback)
	playback.finished.connect(func(): play_button.text=LocalizationSystem.text("试听"))
	# Copy the actual scene before the recorder body draws. The view below
	# reads this frame, so it cannot recursively photograph its own screen.
	var world_frame := BackBufferCopy.new(); world_frame.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	world_frame.name="LiveWorldFrame"; add_child(world_frame)
	face=Control.new(); face.position=Vector2(300,140); face.size=Vector2(1000,600); face.mouse_filter=MOUSE_FILTER_IGNORE; add_child(face)
	var shell := TextureRect.new()
	var region := AtlasTexture.new(); region.atlas=preload("res://art/ui/pocket_doodles/recorder_shell.png"); region.region=Rect2(48,128,1460,730)
	shell.texture=region; shell.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; shell.size=face.size; shell.mouse_filter=MOUSE_FILTER_IGNORE; face.add_child(shell)
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(face,"随身录音机",Vector2(111,187),420,26)
	status=p.words(face,"留下此刻听见的声音",Vector2(110,523),608,19)
	var screen = preload("res://scripts/ui/components/live_sound_window.gd").new(); screen.source=self; screen.position=Vector2(75,241); screen.size=Vector2(458,260)
	screen.name="LiveRecordingPicture"; live_screen=screen
	var style := StyleBoxFlat.new(); style.bg_color=Color("e6e7d8"); style.set_corner_radius_all(5); style.set_border_width_all(2); style.border_color=Color("8b8264")
	screen.add_theme_stylebox_override("panel",style); screen.mouse_filter=MOUSE_FILTER_IGNORE; face.add_child(screen)
	var window_words := p.words(face,"实时画面 · 随声音变化",Vector2(95,215),414,16)
	window_words.add_theme_color_override("font_color",Color("7a785f"))
	record_button=_button("● 开始录音",Vector2(580,338),Vector2(210,65),toggle_recording)
	record_button.name="RecordToggle"
	mark_button=_button("留下标记",Vector2(580,435),Vector2(210,43),mark_recording); mark_button.disabled=true
	_button("收起",Vector2(795,184),Vector2(126,38),finish_for_exit)
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
	recorder.failed.connect(func(message: String): status.text=LocalizationSystem.text(message); close_after=false; record_button.text="● 重新录音"; mark_button.disabled=true)
	recorder.completed.connect(_complete)

func _button(words: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=words; b.position=at; b.size=extent; b.variant="outlined"; face.add_child(b); b.pressed.connect(action); return b

func _toggle_compact() -> void:
	face.visible=not face.visible; compact_button.visible=not face.visible
	focus_active=face.visible
	if not face.visible: get_viewport().gui_release_focus()
	queue_redraw()

func _open_library() -> void:
	get_parent().show_recording_library()

func _play_last() -> void:
	if playback.stream==null: return
	if playback.playing: playback.stop(); play_button.text="试听"
	else: playback.play(); play_button.text="停止试听"

func _complete(wav: AudioStreamWAV, warning: String) -> void:
	playback.stream=wav; play_button.disabled=false
	pending_wav = wav
	saved = false
	_save(warning)

func _save(warning := "") -> void:
	if pending_wav == null: return
	var store := SampleStore.new(store_path)
	var item := pending_sample
	if item.is_empty(): item=store.save_sample(pending_wav,TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text(),{"role":GameState.current_role,"game_day":GameState.current_day,"game_minute":GameState.current_minute,"location":GameState.current_location,"source_mode":"game","consent_status":"game_audio","usage_scope":"local_game","markers":marks})
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
	if pending_wav!=null: _save()
	elif recorder.capturing: recorder.stop()
	else: playback.stop(); play_button.text="试听"; saved=false; marks.clear(); levels.clear(); recorder.start("","game")
func mark_recording() -> void:
	if recorder.capturing: marks.append(snappedf(recorder.elapsed,.01))
func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("open_recorder"): toggle_recording()
	elif event.is_action_pressed("record_mark"): mark_recording()
	elif event.is_action_pressed("ui_cancel"): finish_for_exit()
	else: return
	get_viewport().set_input_as_handled()
