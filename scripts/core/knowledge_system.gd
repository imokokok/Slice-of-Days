extends Node
func facts() -> Array:
	var rows: Array = GameState.shared_state.get("knowledge_"+GameState.current_role,[]).duplicate(true)
	for item in rows:
		var stale := str(item.get("predicate", "")) == "schedule" and int(item.get("learned_day", 0)) != GameState.current_day
		item["status"] = "Outdated" if stale else "Heard" if float(item.get("confidence", 1.0)) < 0.8 else "Confirmed"
	return rows
func learn(fact: Dictionary) -> void:
	var rows := facts().duplicate(true)
	var item := fact.duplicate(true)
	item["learned_day"] = GameState.current_day
	item["learned_time"] = GameState.current_minute
	var replaced := false
	for index in rows.size():
		if str(rows[index].get("id","")) == str(item.get("id","")):
			var history: Array = rows[index].get("revisions", []).duplicate(true)
			if str(rows[index].get("text", "")) != str(item.get("text", "")):
				history.append({"text":rows[index].get("text", ""), "day":rows[index].get("learned_day",1), "source":rows[index].get("source_npc_id", "")})
			item["revisions"] = history
			rows[index] = item
			replaced = true
	if not replaced: rows.append(item)
	GameState.shared_state["knowledge_"+GameState.current_role] = rows
	SaveManager.save_or_report("知识记录保存失败")
func text() -> String:
	var lines: Array[String] = []
	for item in facts():
		var stale := str(item.get("predicate","")) == "schedule" and int(item.get("learned_day",0)) != GameState.current_day
		var source: Dictionary = ScheduleSystem.residents.get(str(item.get("source_npc_id","")),{})
		lines.append("%s%s\n来源：%s · 第%d天" % [str(item.get("text","")) + ("（旧日时间，待确认）" if stale else ""), " ?" if float(item.get("confidence",1.0)) < 0.8 else "",str(source.get("display_name","便签")),int(item.get("learned_day",1))])
	return "\n\n".join(lines) if not lines.is_empty() else "还没有问到新的消息。"
