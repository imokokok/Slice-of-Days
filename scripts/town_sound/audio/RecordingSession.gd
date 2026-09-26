extends Node
## One recorder for the whole journey. Views may disappear; audio and retryable
## local drafts belong here, never to a scene or a popup.
signal changed
signal sample_saved(item: Dictionary)
var recorder: FieldRecorder
var playback: AudioStreamPlayer
var levels: Array[float]=[]
var marks: Array=[]
var mv_events: Array=[]
var context: Dictionary={}
var pending_wav: AudioStreamWAV
var pending_sample: Dictionary={}
var last_sample: Dictionary={}
var saved:=false
var message:="按圆键，留下此刻的游戏声音。收进口袋后也能继续录。"
var store_path:="user://samples"
var warning:=""
var checkpoint_age:=0.0
var observed_scope:=""
var event_kind:="wind"
var event_until:=0.0
const Atlas=preload("res://scripts/town_sound/data/SoundAtlas.gd")

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	recorder=FieldRecorder.new(); add_child(recorder)
	playback=AudioStreamPlayer.new(); playback.bus="Music"; add_child(playback)
	playback.finished.connect(func(): changed.emit())
	recorder.meter_changed.connect(func(peak:float,_seconds:float):
		levels.append(peak)
		if levels.size()>95: levels.pop_front())
	recorder.completed.connect(_completed)
	recorder.failed.connect(func(reason:String): message=reason; changed.emit())
	WorldSound.sound_occurred.connect(_sound_event)

func start(mode:="game") -> bool:
	if not CharacterSystem.owns_pocket_item("recorder"): return false
	if recorder.capturing or pending_wav!=null: return false
	if mode not in ["game","microphone"]: return false
	if SampleStore.new(store_path).list_samples().size()>=SampleStore.MAX_SAMPLES:
		message="声音收藏已满，请先整理不用的录音。"; changed.emit(); return false
	playback.stop(); levels.clear(); marks.clear(); mv_events.clear()
	saved=false; pending_sample={}; warning=""; checkpoint_age=0; event_until=0
	context={"role":GameState.current_role,"journey_id":str(GameState.shared_state.get("journey_id","")),"game_day":GameState.current_day,"game_minute":GameState.current_minute,"location":GameState.current_location,"source_mode":mode,"consent_status":"user_voice" if mode=="microphone" else "game_audio","usage_scope":"local_game","sound_kind":"voice" if mode=="microphone" else ambient_kind(),"mv_seed":randi_range(1,999999),"mv_version":4,"locations":[GameState.current_location]}
	observed_scope=_scope()
	context["recording_id"]="sample_"+Crypto.new().generate_random_bytes(12).hex_encode()
	if not recorder.start(SoundSettings.input_device,mode): return false
	append_event(str(context.sound_kind))
	message="正在录真实游戏声景。收进口袋，可继续走动、进屋和做事。" if mode=="game" else "正在录麦克风人声。再按圆键停止并保存。"
	WorldSound.play_ui("record_start"); changed.emit(); return true

func toggle(mode:="game") -> void:
	if pending_wav!=null: save_pending()
	elif recorder.capturing: stop()
	else: start(mode)

func stop() -> void:
	if not recorder.capturing: return
	recorder.stop(); WorldSound.play_ui("record_stop")

func _completed(wav:AudioStreamWAV,notice:String) -> void:
	pending_wav=wav; warning=notice; playback.stream=wav
	context["signal_peak"]=recorder.largest_peak
	context["markers"]=marks.duplicate(); context["mv_events"]=mv_events.duplicate(true)
	_checkpoint(wav)
	save_pending()

func save_pending() -> bool:
	if pending_wav==null: return true
	# Ownership is fixed at recording start, including when walking across rooms.
	if str(context.get("journey_id",""))!=str(GameState.shared_state.get("journey_id","")) or str(context.get("role",""))!=GameState.current_role:
		message="这段录音属于另一个旅程或视角，草稿已保留。"; changed.emit(); return false
	var before:=GameState.to_save_data().duplicate(true)
	var store:=SampleStore.new(store_path)
	if pending_sample.is_empty():
		var minute:=int(context.get("game_minute",0))
		var title:="%s · %02d:%02d"%[TravelSystem.location_name(str(context.get("location",""))),minute/60,minute%60]
		pending_sample=store.save_sample(pending_wav,title,context)
	if pending_sample.is_empty():
		GameState.load_save_data(before); message=store.last_error+" 声音仍在，点圆键重试。"; changed.emit(); return false
	var id:=str(pending_sample.id)
	var ids: Array=GameState.artifacts.get_or_add("recorded_sample_ids",[])
	if not ids.has(id): ids.append(id)
	GameState.add_artifact("samples",{"id":id,"title":str(pending_sample.name),"kind":"recording","duration":float(pending_sample.duration),"day":int(context.game_day),"location":str(context.location),"markers":marks.duplicate()})
	_carry_audio_to_rollback()
	if not ResidencySystem.persist():
		GameState.load_save_data(before); _checkpoint(pending_wav)
		message="声音已留在本机，存档暂时写不进去。点圆键重试；不会重复生成。"; changed.emit(); return false
	last_sample=pending_sample.duplicate(true); pending_sample={}; pending_wav=null; saved=true
	_remove_checkpoint()
	message="已保存「%s」。可以试听、改名，再带去唱片店。"%str(last_sample.name)
	if not warning.is_empty(): message+="\n"+warning
	changed.emit(); sample_saved.emit(last_sample); return true

func finish_for_exit() -> bool:
	if recorder.capturing: stop()
	if pending_wav!=null: return save_pending()
	playback.stop(); return true

func play_last() -> void:
	if recorder.capturing or playback.stream==null: return
	if playback.playing: playback.stop()
	else: playback.play()
	changed.emit()

func rename_sample(item:Dictionary,title:String) -> bool:
	var store:=SampleStore.new(store_path)
	var before:=GameState.to_save_data().duplicate(true)
	if not store.rename_sample(str(item.id),title): message=store.last_error; return false
	for artifact in GameState.artifacts.get("samples",[]):
		if str(artifact.get("id",""))==str(item.id): artifact.title=title.strip_edges().left(60)
	ResidencySystem._sync_sources()
	_carry_audio_to_rollback()
	if not ResidencySystem.persist():
		store.rename_sample(str(item.id),str(item.name)); GameState.load_save_data(before)
		message="名称暂时没能写入存档，请重试。"; return false
	if str(last_sample.get("id",""))==str(item.id): last_sample.name=title.strip_edges().left(60)
	changed.emit(); return true

func delete_sample(item:Dictionary) -> bool:
	if CoreLoopSystem.material_in_use(str(item.id)):
		message="这段声音已经用于分享或申请，请保留原始录音。"; return false
	for page in ResidencySystem.state().get("free_pages",{}).values():
		if page.any(func(piece:Dictionary): return str(piece.get("material",""))==str(item.id)):
			message="这段录音还在手账里使用，请先移除相关贴片。"; return false
	var store:=SampleStore.new(store_path)
	var before:=GameState.to_save_data().duplicate(true)
	if not store.delete_sample(str(item.id)): message=store.last_error; return false
	GameState.artifacts.samples=GameState.artifacts.get("samples",[]).filter(func(row:Dictionary): return str(row.get("id",""))!=str(item.id))
	GameState.artifacts.get_or_add("recorded_sample_ids",[]).erase(str(item.id))
	ResidencySystem.state().materials.erase(str(item.id))
	_carry_audio_to_rollback()
	if not ResidencySystem.persist():
		store.restore_sample(str(item.id)); GameState.load_save_data(before)
		message="存档暂时没能写入，录音已放回收藏。"; return false
	if str(last_sample.get("id",""))==str(item.id): last_sample={}; playback.stop(); playback.stream=null; saved=false
	changed.emit(); return true

func mark() -> void:
	if recorder.capturing: marks.append(snappedf(float(recorder.frame_count)/recorder.sample_rate,.01))

func _carry_audio_to_rollback() -> void:
	# Cancelling cooking/cards rolls back activity costs, not recordings the
	# player independently collected during that activity.
	var snapshot:Dictionary=GameState.shared_state.get("pending_module",{}).get("rollback_snapshot",{})
	if snapshot.is_empty() or str(snapshot.get("current_role",""))!=GameState.current_role: return
	var artifacts:Dictionary=snapshot.role_states[GameState.current_role].get_or_add("artifacts",{})
	for key in ["samples","recorded_sample_ids"]:
		artifacts[key]=GameState.artifacts.get(key,[]).duplicate(true)
	var materials:Dictionary=artifacts.get("residency",{}).get("materials",{})
	for id in materials.keys():
		if str(id).begins_with("sample_"): materials.erase(id)
	for id in ResidencySystem.state().materials:
		if str(id).begins_with("sample_"): materials[id]=ResidencySystem.state().materials[id].duplicate(true)

func ambient_kind() -> String:
	if WorldSound.weather=="rain" and not WorldSound.indoors: return "rain"
	if GameState.current_location in ["port","park","town_entrance"] and not WorldSound.indoors: return "water"
	return "pulse" if WorldSound.indoors else "wind"

func _sound_event(kind:String) -> void:
	if not recorder.capturing or recorder.source_mode!="game": return
	event_kind=kind; event_until=recorder.elapsed+1.7; append_event(kind)

func append_event(kind:String) -> void:
	if not mv_events.is_empty() and str(mv_events.back().kind)==kind: return
	mv_events.append({"time":float(recorder.frame_count)/recorder.sample_rate,"kind":kind,"location":GameState.current_location})

func current_mv_kind() -> String:
	var at:=float(recorder.frame_count)/recorder.sample_rate if recorder.capturing else playback.get_playback_position()
	var kind:=str(context.get("sound_kind",ambient_kind()))
	for event in mv_events:
		if float(event.time)<=at: kind=str(event.kind)
	return kind

func current_mv_seed() -> int: return int(context.get("mv_seed",23817))

func _scope() -> String:
	return str(GameState.shared_state.get("journey_id",""))+"/"+GameState.current_role

func _process(delta:float) -> void:
	if observed_scope!=_scope():
		if recorder.capturing:
			_checkpoint(recorder.snapshot()); recorder._cancel()
		playback.stop(); pending_wav=null; pending_sample={}; last_sample={}; saved=false; context={}; levels.clear(); mv_events.clear()
		observed_scope=_scope(); store_path="user://samples"; recover_pending(); changed.emit()
	if not recorder.capturing: return
	if recorder.source_mode=="game":
		if not context.locations.has(GameState.current_location): context.locations.append(GameState.current_location)
		if recorder.elapsed>=event_until: append_event(ambient_kind())
	checkpoint_age+=delta
	if checkpoint_age>=5:
		checkpoint_age=0; _checkpoint(recorder.snapshot())

func _draft_base(owner_context:Dictionary={}) -> String:
	var key:=str(owner_context.get("journey_id",""))+"/"+str(owner_context.get("role","")) if not owner_context.is_empty() else _scope()
	return "user://recording_drafts/"+key.sha256_text().left(24)

func _checkpoint(wav:AudioStreamWAV) -> void:
	if wav==null or wav.data.is_empty(): return
	if DirAccess.make_dir_recursive_absolute("user://recording_drafts")!=OK: return
	var base:=_draft_base(context)
	if wav.save_to_wav(base+".pending.wav")!=OK: return
	if DirAccess.rename_absolute(base+".pending.wav",base+".wav")!=OK: return
	var draft_context:=context.duplicate(true); draft_context.mv_events=mv_events.duplicate(true); draft_context.markers=marks.duplicate()
	if recorder.capturing: draft_context["signal_peak"]=recorder.largest_peak
	var file:=FileAccess.open(base+".pending.json",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"context":draft_context,"sample":pending_sample,"store_path":store_path})); file.close()
	DirAccess.rename_absolute(base+".pending.json",base+".json")

func recover_pending() -> bool:
	if recorder.capturing or pending_wav!=null: return false
	var base:=_draft_base()
	if not FileAccess.file_exists(base+".json") or not FileAccess.file_exists(base+".wav"): return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(base+".json"))
	if not data is Dictionary or not data.get("context") is Dictionary: return false
	var restored:Dictionary=data.context
	if str(restored.get("journey_id",""))!=str(GameState.shared_state.get("journey_id","")) or str(restored.get("role",""))!=GameState.current_role: return false
	var wav:=AudioStreamWAV.load_from_file(base+".wav")
	if wav==null or wav.get_length()>FieldRecorder.MAX_SECONDS+.5: return false
	var id:=str(restored.get("recording_id",""))
	if not id.is_empty() and GameState.artifacts.get("recorded_sample_ids",[]).has(id):
		_remove_checkpoint(); return false
	context=restored; mv_events=context.get("mv_events",[]); marks=context.get("markers",[])
	# Reconstruct by the stable recording ID. Never trust a stale draft's file path.
	pending_wav=wav; playback.stream=wav; pending_sample={}
	observed_scope=_scope()
	message="找回了上次未保存的声音。先试听，点圆键把它收好。"; changed.emit(); return true

func _remove_checkpoint() -> void:
	for suffix in [".json",".wav"]:
		var path:String=_draft_base()+str(suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
