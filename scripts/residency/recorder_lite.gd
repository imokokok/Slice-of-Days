extends Control
var recorder: FieldRecorder
var status: Label
var marks: Array = []
var levels: Array[float] = []
var close_after := false
var pending_wav: AudioStreamWAV
var saved := false
var store_path := "user://samples"

func _ready() -> void:
	add_to_group("world_tool")
	add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var card := Panel.new()
	card.position = Vector2(1240,155)
	card.size = Vector2(330,295)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7f1e4",0.92)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel",style)
	add_child(card)
	status = Label.new()
	status.position = Vector2(14,8)
	status.size = Vector2(302,130)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",Color("375456"))
	status.add_theme_font_size_override("font_size",18)
	card.add_child(status)
	status.text = "记录身边的声音\n"+SettingsSystem.binding_text("open_recorder")+" 开始 / 停止"
	for i in 3:
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=["开始 / 停止并保存","留下时间标记","保存并收起"][i]; b.position=Vector2(14,151+i*44); b.size=Vector2(302,40); card.add_child(b)
		b.pressed.connect([toggle_recording,mark_recording,finish_for_exit][i])
	recorder = FieldRecorder.new()
	add_child(recorder)
	recorder.meter_changed.connect(func(peak: float, seconds: float) -> void:
		levels.append(peak)
		if levels.size()>95: levels.pop_front()
		status.text = LocalizationSystem.text("●  录音  %02d:%02d\n正在收集小镇声音\n已留 %d 个标记" % [int(seconds)/60,int(seconds)%60,marks.size()])
		queue_redraw())
	recorder.failed.connect(func(message: String) -> void: status.text = LocalizationSystem.text(message); close_after = false)
	recorder.completed.connect(_complete)

func _draw() -> void:
	for i in levels.size():
		var height := clampf(levels[i]*110,2,28)
		draw_line(Vector2(1252+i*3,282-height),Vector2(1252+i*3,282+height),Color("718e91"),2)

func _complete(wav: AudioStreamWAV, warning: String) -> void:
	pending_wav = wav
	saved = false
	_save(warning)

func _save(warning := "") -> void:
	if pending_wav == null: return
	var store := SampleStore.new(store_path)
	var item := store.save_sample(pending_wav,TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text(),{"role":GameState.current_role,"game_day":GameState.current_day,"game_minute":GameState.current_minute,"location":GameState.current_location,"source_mode":"game","consent_status":"game_audio","usage_scope":"local_game","markers":marks})
	if item.is_empty(): status.text = LocalizationSystem.text(store.last_error+"\nR 重试保存 · Esc 保留窗口"); close_after = false; return
	GameState.add_artifact("samples",{"id":str(item.id),"title":str(item.name),"duration":float(item.duration),"day":GameState.current_day,"location":GameState.current_location,"markers":marks.duplicate()})
	ResidencySystem.persist()
	pending_wav = null
	saved = true
	status.text = LocalizationSystem.text("已保存到素材本\n"+warning+"\nB 查看 · 即将收起")
	if close_after: queue_free()
	else: status.text="已保存到录音机，可以继续录制。"

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
	queue_free()
	return true

func toggle_recording() -> void:
	if pending_wav!=null: _save()
	elif recorder.capturing: recorder.stop()
	else: saved=false; marks.clear(); levels.clear(); recorder.start("","game")
func mark_recording() -> void:
	if recorder.capturing: marks.append(snappedf(recorder.elapsed,.01))
func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("open_recorder"): toggle_recording()
	elif event.is_action_pressed("record_mark"): mark_recording()
	elif event.is_action_pressed("ui_cancel"): finish_for_exit()
	else: return
	get_viewport().set_input_as_handled()
