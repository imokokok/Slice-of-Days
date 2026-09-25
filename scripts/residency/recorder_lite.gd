extends Control
## One shared physical recorder view; the session survives this node.
var recorder: FieldRecorder:
	get: return RecordingSession.recorder
var playback: AudioStreamPlayer:
	get: return RecordingSession.playback
var levels: Array[float]:
	get: return RecordingSession.levels
var marks: Array:
	get: return RecordingSession.marks
var saved: bool:
	get: return RecordingSession.saved
var pending_wav: AudioStreamWAV:
	get: return RecordingSession.pending_wav
var pending_sample: Dictionary:
	get: return RecordingSession.pending_sample
var store_path: String:
	get: return RecordingSession.store_path
	set(value): RecordingSession.store_path=value
var status: Label
var face: Control
var source_picker: OptionButton
var record_button: Button
var play_button: Button
var live_screen: Control
var mark_button: Button
var focus_active:=true
var meter: ProgressBar
var elapsed_label: Label
var place_label: Label
var name_input: LineEdit
var rename_button: Button
var compact_button: Button

func _ready() -> void:
	if not CharacterSystem.owns_pocket_item("recorder"):
		set_process_input(false); queue_free(); return
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	add_to_group("world_tool"); add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_IGNORE
	face=Control.new(); face.size=Vector2(1200,720); face.mouse_filter=MOUSE_FILTER_STOP; add_child(face)
	resized.connect(_fit_face); _fit_face()
	var shell:=Panel.new(); shell.size=face.size; shell.mouse_filter=MOUSE_FILTER_IGNORE
	var paper:=StyleBoxFlat.new(); paper.bg_color=Color("f4e6ca"); paper.set_corner_radius_all(32); paper.set_border_width_all(3); paper.border_color=Color("aa9275"); paper.shadow_size=12
	shell.add_theme_stylebox_override("panel",paper); face.add_child(shell)
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(face,"今天，听见了什么？",Vector2(42,27),850,32)
	p.words(face,"随身录音机  /  走到哪里，就把哪里的声音留下来",Vector2(44,79),1000,19)
	_button("收进口袋",Vector2(995,29),Vector2(161,44),put_away)
	place_label=p.words(face,"",Vector2(44,142),680,21)
	live_screen=preload("res://scripts/ui/components/live_sound_window.gd").new()
	live_screen.source=self; live_screen.position=Vector2(44,193); live_screen.size=Vector2(670,377); live_screen.name="LiveRecordingPicture"; face.add_child(live_screen)
	meter=ProgressBar.new(); meter.position=Vector2(44,580); meter.size=Vector2(670,8); meter.max_value=1; meter.show_percentage=false; face.add_child(meter)
	p.words(face,"现场声音 → 实时画面  ·  不需要挑选或播放素材",Vector2(48,603),690,18)
	source_picker=OptionButton.new(); source_picker.position=Vector2(758,138); source_picker.size=Vector2(398,45)
	source_picker.add_icon_item(preload("res://scripts/town_sound/SoundIcons.gd").get_icon("audio-lines"),"游戏声音 · 环境与互动"); source_picker.add_icon_item(preload("res://scripts/town_sound/SoundIcons.gd").get_icon("mic"),"人声补录 · 麦克风"); source_picker.add_theme_constant_override("icon_max_width",24); face.add_child(source_picker)
	source_picker.select(1 if recorder.capturing and recorder.source_mode=="microphone" else 0)
	p.words(face,"按圆键开始，再按一次保存。\n收起来，可以继续走动和做事。\n剪辑与制作，回唱片店再继续。",Vector2(759,211),397,20)
	record_button=preload("res://scripts/town_sound/studio/RecordKey.gd").new()
	record_button.position=Vector2(866,329); record_button.size=Vector2(136,136); record_button.name="RecordToggle"; record_button.accessibility_name="开始 / 停止并保存录音"; face.add_child(record_button); record_button.pressed.connect(toggle_recording)
	elapsed_label=p.words(face,"00:00 / 01:00",Vector2(859,479),280,22)
	play_button=_button("▶ 听听刚才",Vector2(760,529),Vector2(186,46),RecordingSession.play_last)
	compact_button=_button("边走边录",Vector2(962,529),Vector2(190,46),put_away)
	_button("我的声音收藏",Vector2(760,590),Vector2(392,44),_open_library)
	status=p.words(face,"",Vector2(46,651),1100,18); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	name_input=LineEdit.new(); name_input.placeholder_text="给刚才的声音起个名字"; name_input.max_length=60; name_input.position=Vector2(44,134); name_input.size=Vector2(554,43); face.add_child(name_input)
	rename_button=_button("记下",Vector2(613,134),Vector2(100,43),_rename_last)
	mark_button=Button.new(); mark_button.hide(); add_child(mark_button)
	RecordingSession.changed.connect(_refresh); _refresh()
	preload("res://scripts/ui/solmere_motion.gd").paper_open(face,SettingsSystem.reduced_motion())

func _fit_face() -> void:
	if face==null: return
	var factor:=maxf(.1,minf(1,minf((size.x-48)/1200.0,(size.y-48)/720.0)))
	face.scale=Vector2.ONE*factor; face.position=(size-Vector2(1200,720)*factor)*.5

func _button(words:String,at:Vector2,extent:Vector2,action:Callable) -> Button:
	var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=words; b.variant="outlined"; b.position=at; b.size=extent; b.pressed.connect(action); face.add_child(b); return b

func _refresh() -> void:
	status.text=RecordingSession.message
	source_picker.disabled=recorder.capturing or pending_wav!=null
	record_button.text="■ 停止并保存" if recorder.capturing else "重试保存" if pending_wav!=null else "● 再录一段" if saved else "● 开始录音"
	play_button.disabled=recorder.capturing or playback.stream==null
	play_button.text="■ 停止试听" if playback.playing else "▶ 听听刚才"
	var named:=saved and not RecordingSession.last_sample.is_empty() and not recorder.capturing
	name_input.visible=named; rename_button.visible=named; place_label.visible=not named
	if named: name_input.text=str(RecordingSession.last_sample.name)
	compact_button.text="收进口袋继续录" if recorder.capturing else "收进口袋"

func _process(_delta:float) -> void:
	var seconds:=float(recorder.frame_count)/recorder.sample_rate if recorder.capturing else (playback.get_playback_position() if playback.playing else 0.0)
	elapsed_label.text=("● " if recorder.capturing else "")+"%02d:%02d / 01:00"%[int(seconds)/60,int(seconds)%60]
	place_label.text=TravelSystem.location_name(GameState.current_location)+" · "+preload("res://scripts/town_sound/data/SoundAtlas.gd").label(current_mv_kind())
	meter.value=float(levels.back())*4 if recorder.capturing and not levels.is_empty() else 0

func toggle_recording() -> void: RecordingSession.toggle("game" if source_picker.selected==0 else "microphone")
func mark_recording() -> void: RecordingSession.mark()
func _play_last() -> void: RecordingSession.play_last()
func current_mv_kind() -> String: return RecordingSession.current_mv_kind()
func current_mv_seed() -> int: return RecordingSession.current_mv_seed()
func _toggle_compact() -> void: put_away()
func put_away() -> void:
	get_viewport().gui_release_focus(); queue_free()
func finish_for_exit() -> bool:
	if not RecordingSession.finish_for_exit(): return false
	queue_free(); return true
func _open_library() -> void:
	if not RecordingSession.finish_for_exit(): return
	put_away(); GlobalRecorder.open_library.call_deferred()
func _rename_last() -> void:
	if RecordingSession.last_sample.is_empty(): return
	if RecordingSession.rename_sample(RecordingSession.last_sample,name_input.text):
		RecordingSession.last_sample.name=name_input.text.strip_edges().left(60)
		status.text="名字记好了。回唱片店时也会用这个名字。"
	else: status.text=RecordingSession.message
func _input(event:InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.is_action_pressed("open_recorder"): toggle_recording()
	elif event.is_action_pressed("record_mark"): mark_recording()
	elif event.is_action_pressed("ui_cancel"): put_away()
	else: return
	get_viewport().set_input_as_handled()
