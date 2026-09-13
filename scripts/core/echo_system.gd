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
	var rows: Array = GameState.shared_state.get("visible_echoes",[])
	var title := str(outcome.get("label", "一件作品"))
	rows.append({"day":GameState.current_day,"role":GameState.current_role,"location":"night_market" if module == "cooking" else "handcraft_shop" if module == "ghostwriting" else "record_store", "text":("黑板上留下了一道菜：" if module == "cooking" else "桌边留着：") + title})
	GameState.shared_state["visible_echoes"] = rows
func at_location(location: String) -> Array:
	var result: Array = []
	for row in GameState.shared_state.get("visible_echoes",[]):
		if str(row.location) == location: result.append(row)
	return result
