extends RefCounted

static var data: Dictionary = {}

static func database() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/question-bank.json"))
	return data

static func key(raw: String) -> String:
	var value := raw.strip_edges().replace(" ", "").replace("　", "")
	for prefix in ["塔罗师，", "老师，", "请问", "我想问一下", "我想问"]:
		value = value.trim_prefix(prefix)
	while value.ends_with("？") or value.ends_with("?") or value.ends_with("。"):
		value = value.left(-1)
	return value

static func lookup(case_id: String, raw: String, card_id: String = "") -> Dictionary:
	var text := key(raw)
	var db := database()
	for group in db.facts:
		if group.case != case_id: continue
		for example in group.aliases:
			if key(example) == text:
				return {"status": "bank_fact", "id": group.id, "negative": group.get("negative", false), "raw": raw}
	for group in db.responses:
		if group.case != "*" and group.case != case_id: continue
		for example in group.aliases:
			if key(example) == text:
				return {"status": group.status, "message": group.message, "raw": raw}
	# A drawing question is free interpretation, never a factual YES/NO answer.
	for group in db.visuals:
		if group.card != card_id: continue
		for example in group.aliases:
			if key(example) == text:
				return {"status": "guidance", "message": "如果你问的是牌面：" + group.reply + "\n" + group[case_id], "raw": raw}
	return {}

static func guide(case_id: String, card_id: String) -> Dictionary:
	for row in database().visuals:
		if row.card == card_id: return row
	return {}

static func statistics() -> Dictionary:
	var totals := {"fact_phrasings": 0, "response_phrasings": 0, "visual_phrasings": 0, "cards": database().visuals.size()}
	for row in database().facts: totals.fact_phrasings += row.aliases.size()
	for row in database().responses: totals.response_phrasings += row.aliases.size()
	for row in database().visuals: totals.visual_phrasings += row.aliases.size()
	return totals
