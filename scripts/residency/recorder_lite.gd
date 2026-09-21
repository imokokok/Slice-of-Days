extends Control
var recorder: FieldRecorder
var status: Label
var marks: Array = []
var levels: Array[float] = []
var close_after := false
var pending_wav: AudioStreamWAV
var saved := false
var store_path := "user://samples"
var record_button: Button
var mark_button: Button

func _ready() -> void:
	add_to_group("world_tool")
	add_to_group("mobile_recorder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var card := Panel.new()
	card.position = Vector2(1130,564)
	card.size = Vector2(430,286)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("204762",0.96)
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel",style)
	add_child(card)
	status = Label.new()
	status.position = Vector2(24,20)
	status.size = Vector2(382,96)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",Color("fffaf1"))
	status.add_theme_font_size_override("font_size",18)
	card.add_child(status)
	status.text = "录音机\n记录此刻听见的声音"
	for i in 3:
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.variant="camera"; b.text=["● 开始录音","标记","收起"][i]; b.position=Vector2(18 if i==0 else 224+(i-1)*92,214); b.size=Vector2(196 if i==0 else 86,48); card.add_child(b)
		if i==0: record_button=b
		elif i==1: mark_button=b; mark_button.disabled=true
		b.pressed.connect([toggle_recording,mark_recording,finish_for_exit][i])
	recorder = FieldRecorder.new()
	add_child(recorder)
	recorder.meter_changed.connect(func(peak: float, seconds: float) -> void:
		levels.append(peak)
		if levels.size()>95: levels.pop_front()
		status.text = LocalizationSystem.text("●  录音  %02d:%02d\n%s · %d 个标记" % [int(seconds)/60,int(seconds)%60,TravelSystem.location_name(GameState.current_location),marks.size()])
		record_button.text="■ 停止并保存"; mark_button.disabled=false
		queue_redraw())
	recorder.failed.connect(func(message: String) -> void: status.text = LocalizationSystem.text(message); close_after = false)
	recorder.completed.connect(_complete)

func _draw() -> void:
	for i in levels.size():
		var height := clampf(levels[i]*110,2,28)
		draw_line(Vector2(1155+i*3.9,719-height),Vector2(1155+i*3.9,719+height),Color("e9d98b"),2)

func _complete(wav: AudioStreamWAV, warning: String) -> void:
	pending_wav = wav
	saved = false
	_save(warning)

func _save(warning := "") -> void:
	if pending_wav == null: return
	var store := SampleStore.new(store_path)
	var item := store.save_sample(pending_wav,TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text(),{"role":GameState.current_role,"game_day":GameState.current_day,"game_minute":GameState.current_minute,"location":GameState.current_location,"source_mode":"game","consent_status":"game_audio","usage_scope":"local_game","markers":marks})
	if item.is_empty(): status.text = LocalizationSystem.text(store.last_error+"\n"+SettingsSystem.binding_text("open_recorder")+" 重试保存"); record_button.text="重试保存"; mark_button.disabled=true; close_after = false; return
	GameState.add_artifact("samples",{"id":str(item.id),"title":str(item.name),"duration":float(item.duration),"day":GameState.current_day,"location":GameState.current_location,"markers":marks.duplicate()})
	ResidencySystem.persist()
	pending_wav = null
	saved = true
	record_button.text="● 再录一段"; mark_button.disabled=true
	status.text = LocalizationSystem.text("已保存到录音机\n"+warning)
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
