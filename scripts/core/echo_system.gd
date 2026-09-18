extends Node
func close_day() -> void:
	var offscreen := "B" if GameState.current_role == "A" else "A"
	var traces: Array = GameState.shared_state.get("offscreen_"+offscreen,[])
	var token := "trace_%d_%s" % [GameState.current_day,offscreen]
	if traces.any(func(t: Dictionary) -> bool: return str(t.id) == token): return
	traces.append({"id":token,"day":GameState.current_day,"text":"口袋里多了一张海边收据，背面画着半只海鸥。" if offscreen == "A" else "日程本夹着一张公交票：昨天经过公共区域，没有作新的承诺。"})
	GameState.shared_state["offscreen_"+offscreen] = traces
func begin_day() -> void:
	if GameState.current_day == 6:
		GameState.add_journal_entry({"kind":"application","text":"明晚仍有一整天生活。今晚记得检查永居申请需要的居民确认。"})
func record_module(module: String, outcome: Dictionary) -> void:
	if module not in ["cooking","ghostwriting","sound_sampling"]: return
	# Creation remains personal until a real delivery, serving, archive or display accepts it.
	var rows: Array = GameState.artifacts.get("created_work_notes",[])
	var index := maxi(0,int(GameState.module_states.get(module,{}).get("outcomes",[]).size())-1)
	var id := "created_%s_%d" % [module,index]
	if rows.any(func(row: Dictionary) -> bool: return str(row.get("id","")) == id): return
	rows.append({"id":id,"day":GameState.current_day,"role":GameState.current_role,"title":str(outcome.get("label","一件作品")),"module":module})
	GameState.artifacts["created_work_notes"] = rows
func at_location(location: String) -> Array:
	var result: Array = []
	for row in GameState.shared_state.get("visible_echoes",[]):
		if str(row.location) == location:
			var visible: Dictionary = row.duplicate(true)
			if GameState.current_day > int(row.get("day",GameState.current_day)) and not str(row.get("response","")).is_empty(): visible.text = str(row.response)+"\n「"+str(row.text)+"」"
			result.append(visible)
	for row in GameState.shared_state.get("ambient_traces",[]):
		if str(row.location) == location: result.append(row)
	return result

func resume_ambient(now: float = -1.0) -> bool:
	if not MetaExperience.enabled("living_town"): return false
	if now < 0: now = Time.get_unix_time_from_system()
	var checkpoint: Dictionary = GameState.shared_state.get("meta_checkpoint",{})
	if checkpoint.is_empty(): return false
	var previous := maxf(float(checkpoint.get("timestamp",now)),float(GameState.shared_state.get("ambient_applied_at",0)))
	var elapsed := clampf(now-previous,0,float(MetaExperience.catalog.timing.offline_cap_seconds))
	var steps := mini(3,int(elapsed/float(MetaExperience.catalog.timing.offline_step_seconds)))
	if steps == 0: return false
	var rows: Array = GameState.shared_state.get("ambient_traces",[]).duplicate(true)
	var applied := 0
	for event in MetaExperience.catalog.ambient_events:
		if applied >= steps: break
		if GameState.current_day < int(event.after_day): continue
		if rows.any(func(row: Dictionary) -> bool: return str(row.get("id","")) == "ambient_"+str(event.id)): continue
		rows.append({"id":"ambient_"+str(event.id),"location":event.location,"text":event.text,"day":GameState.current_day})
		applied += 1
	GameState.shared_state["ambient_traces"] = rows
	GameState.shared_state["ambient_applied_at"] = now
	return true

func update_presence() -> void:
	if not MetaExperience.enabled("living_town"): return
	var rows: Array = GameState.shared_state.get("ambient_traces",[])
	for event in MetaExperience.catalog.presence_events:
		if GameState.current_day < int(event.day): continue
		if GameState.current_day == int(event.day) and GameState.current_minute < int(event.minute): continue
		var id := "presence_"+str(event.id)
		if rows.any(func(row: Dictionary) -> bool: return str(row.get("id","")) == id): continue
		rows.append({"id":id,"location":event.location,"text":event.text,"day":GameState.current_day,"witnessed":GameState.current_location == str(event.location)})
	GameState.shared_state["ambient_traces"] = rows
