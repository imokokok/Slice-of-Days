class_name EndingEchoResolver
extends RefCounted


func resolve(ending_data: Dictionary, requested_limit := -1) -> Array[Dictionary]:
	GameState.commit_active_role_state()
	var matched: Array[Dictionary] = []
	var source_index := 0
	for raw_echo in ending_data.get("echoes", []):
		var echo: Dictionary = raw_echo
		var context := _matching_context(echo)
		if bool(context.get("matched", false)):
			var resolved := echo.duplicate(true)
			resolved["text"] = _resolve_text(str(echo.get("text", "")), context)
			resolved["source_index"] = source_index
			matched.append(resolved)
		source_index += 1
	matched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return int(a.get("source_index", 0)) < int(b.get("source_index", 0))
		return a_priority > b_priority
	)
	var limit := requested_limit if requested_limit >= 0 else int(ending_data.get("max_echoes", 5))
	var result: Array[Dictionary] = []
	var seen_categories: Array[String] = []
	for echo in matched:
		if result.size() >= limit:
			break
		var category := str(echo.get("category", ""))
		if bool(ending_data.get("one_per_category", false)) and not category.is_empty() and seen_categories.has(category):
			continue
		result.append(echo)
		if not category.is_empty():
			seen_categories.append(category)
	return result


func display_text(ending_data: Dictionary, requested_limit := -1) -> String:
	var pieces: Array[String] = []
	for echo in resolve(ending_data, requested_limit):
		pieces.append("— %s" % str(echo.get("text", "")))
	if pieces.is_empty():
		return str(ending_data.get("fallback_echo", "结果只记录发生过的事，不替她们总结这七天。"))
	return "\n".join(pieces)


func _matching_context(echo: Dictionary) -> Dictionary:
	var requested_role := str(echo.get("role", ""))
	var roles: Array[String] = []
	if requested_role.is_empty():
		roles.assign(["A", "B"])
	else:
		roles.append(requested_role)
	for role in roles:
		var state: Dictionary = GameState.role_states.get(role, {})
		var context := {"matched": true, "role": role}
		var choice_key := str(echo.get("choice_key", ""))
		if not choice_key.is_empty():
			var choice := _choice_in_state(state, choice_key)
			if choice.is_empty():
				continue
			context["choice"] = choice
		var journal_id := str(echo.get("journal_id", ""))
		var journal_kind := str(echo.get("journal_kind", ""))
		if not journal_id.is_empty() or not journal_kind.is_empty():
			var journal := _journal_in_state(state, journal_id, journal_kind)
			if journal.is_empty():
				continue
			context["journal"] = journal
		var artifact_id := str(echo.get("artifact_id", ""))
		if not artifact_id.is_empty():
			var artifact := _artifact_in_state_or_world(state, artifact_id)
			if artifact.is_empty():
				continue
			context["artifact"] = artifact
		var module_id := str(echo.get("module_id", ""))
		if not module_id.is_empty():
			var outcome := _latest_module_outcome(state, module_id)
			if outcome.is_empty():
				continue
			var module_choice_id := str(echo.get("module_choice_id", ""))
			if not module_choice_id.is_empty() and str(outcome.get("choice_id", "")) != module_choice_id:
				continue
			context["module_outcome"] = outcome
		return context
	return {"matched": false}


func _choice_in_state(state: Dictionary, choice_key: String) -> Dictionary:
	for raw_choice in state.get("choice_history", []):
		var choice: Dictionary = raw_choice
		if str(choice.get("key", "")) == choice_key:
			return choice
	return {}


func _journal_in_state(state: Dictionary, journal_id: String, journal_kind: String) -> Dictionary:
	for raw_entry in state.get("journal_entries", []):
		var entry: Dictionary = raw_entry
		if not journal_id.is_empty() and str(entry.get("id", "")) != journal_id:
			continue
		if not journal_kind.is_empty() and str(entry.get("kind", "")) != journal_kind:
			continue
		return entry
	return {}


func _artifact_in_state_or_world(state: Dictionary, artifact_id: String) -> Dictionary:
	var artifact := _artifact_in_collections(state.get("artifacts", {}), artifact_id)
	if not artifact.is_empty():
		return artifact
	return _artifact_in_collections(GameState.shared_state.get("world_artifacts", {}), artifact_id)


func _artifact_in_collections(collections: Dictionary, artifact_id: String) -> Dictionary:
	for collection_id in collections:
		for raw_artifact in collections[collection_id]:
			var artifact: Dictionary = raw_artifact
			if str(artifact.get("id", "")) == artifact_id:
				return artifact
	return {}


func _latest_module_outcome(state: Dictionary, module_id: String) -> Dictionary:
	var module_state: Dictionary = state.get("module_states", {}).get(module_id, {})
	var outcomes: Array = module_state.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	return outcomes[-1]


func _resolve_text(template: String, context: Dictionary) -> String:
	var text := template.replace("{role}", str(context.get("role", "")))
	var choice: Dictionary = context.get("choice", {})
	text = text.replace("{choice_label}", str(choice.get("label", "")))
	var journal: Dictionary = context.get("journal", {})
	text = text.replace("{journal_text}", str(journal.get("text", "")))
	var artifact: Dictionary = context.get("artifact", {})
	text = text.replace("{artifact_title}", str(artifact.get("title", "")))
	var outcome: Dictionary = context.get("module_outcome", {})
	text = text.replace("{module_choice}", str(outcome.get("label", outcome.get("choice_id", ""))))
	var interaction: Dictionary = outcome.get("interaction", {})
	var labels: Array = interaction.get("selected_labels", [])
	text = text.replace("{selected_joined}", "、".join(labels))
	for index in labels.size():
		text = text.replace("{selected_%d}" % (index + 1), str(labels[index]))
	return text
