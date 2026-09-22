extends RefCounted
## Preserve an untouched backup in the save, while the active cast is exactly 12.

static func apply(game: Node) -> void:
	if int(game.shared_state.get("resident_cast_version", 0)) >= 1: return
	game.shared_state["legacy_resident_archive"] = {
		"role_states": game.role_states.duplicate(true),
		"shared_state": game.shared_state.duplicate(true),
	}
	for role in ["A", "B"]:
		var data: Dictionary = game.role_states.get(role, {})
		for field in ["confirmed_residents", "encountered_residents"]:
			var clean: Array = []
			for old in data.get(field, []):
				var id := ResidentProfileSystem.canonical_id(str(old))
				if not id.is_empty() and not clean.has(id): clean.append(id)
			data[field] = clean
		var relationships: Dictionary = {}
		for old in data.get("relationships", {}):
			var id := ResidentProfileSystem.canonical_id(str(old))
			if id.is_empty(): continue
			var source: Dictionary = data.relationships[old].duplicate(true)
			if not relationships.has(id): relationships[id] = source
			else:
				var target: Dictionary = relationships[id]
				for field in ["flags", "encounter_events"]:
					var values: Array = target.get(field, []).duplicate()
					for value in source.get(field, []):
						if not values.has(value): values.append(value)
					target[field] = values
				target["encounters"] = maxi(int(target.get("encounters", 0)), int(source.get("encounters", 0)))
				if str(source.get("confirmation", "")) == "granted": target["confirmation"] = "granted"
		data.relationships = relationships
		if data.get("artifacts", {}).has("residency"):
			data.artifacts.residency = _recognition_refs(data.artifacts.residency)
		for prefix in ["linear_talk_counts_", "dialogue_history_"]:
			var key: String = prefix + role
			var saved: Variant = game.shared_state.get(key, {} if prefix == "linear_talk_counts_" else [])
			if saved is Dictionary:
				var clean := {}
				for old in saved:
					var id := ResidentProfileSystem.canonical_id(str(old))
					if not id.is_empty(): clean[id] = maxi(int(clean.get(id, 0)), int(saved[old]))
				game.shared_state[key] = clean
			else:
				var clean: Array = []
				for row: Dictionary in saved:
					var id := ResidentProfileSystem.canonical_id(str(row.get("npc", "")))
					if id.is_empty(): continue
					row["npc"] = id
					clean.append(row)
				game.shared_state[key] = clean
		var callback_key: String = "core_loop_" + role
		for callback: Dictionary in game.shared_state.get(callback_key, {}).get("callbacks", {}).values():
			if str(callback.get("npc", "")) == "grocery":
				callback["npc"] = "zhou_xiaoliu"
				callback["location"] = "print_shop"
			for field in ["npc", "origin_npc"]:
				if callback.has(field): callback[field] = ResidentProfileSystem.canonical_id(str(callback[field]))
	game.shared_state["resident_cast_version"] = 1

static func _recognition_refs(value: Variant) -> Variant:
	if value is String:
		if value.begins_with("recognition_"):
			var id := ResidentProfileSystem.canonical_id(value.trim_prefix("recognition_"))
			if not id.is_empty(): return "recognition_" + id
		return value
	if value is Array:
		return value.map(_recognition_refs)
	if not value is Dictionary: return value
	var result := {}
	for key in value: result[_recognition_refs(key)] = _recognition_refs(value[key])
	if str(result.get("material", "")).begins_with("recognition_"):
		var id := ResidentProfileSystem.canonical_id(str(result.material).trim_prefix("recognition_"))
		result["text"] = str(ResidentProfileSystem.profiles[id].display_name) if not id.is_empty() else "旧版纪念纸片"
		if id.is_empty(): result["kind"] = "note"
	if str(result.get("kind", "")) == "recognition" and result.has("resident"):
		var id := ResidentProfileSystem.canonical_id(str(result.get("resident", "")))
		if not id.is_empty():
			var name := str(ResidentProfileSystem.profiles[id].display_name)
			result.merge({"resident":id,"signature":name,"title":name+"的签记","text":"这张签记来自"+name+"。"}, true)
		else:
			# Keep the player's collage and position, but not an extra resident.
			result.merge({"kind":"note","title":"旧版纪念纸片","text":"之前旅程留下的一张纸片。","signature":"","resident":"","source":"legacy_memento"}, true)
	return result
