class_name SampleStore
extends RefCounted
## Per-sample metadata is the commit marker. Incomplete writes stay invisible.

const MAX_SAMPLES := 20
var root_path := "user://samples"
var last_error := ""

func _init(path: String = "user://samples") -> void:
	root_path = path

func list_samples() -> Array[Dictionary]:
	last_error = ""
	var results: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root_path):
		return results
	var directory := DirAccess.open(root_path)
	if directory == null:
		last_error = "无法读取录音目录。"
		return results
	for filename in directory.get_files():
		if not filename.ends_with(".json"):
			continue
		var parser := JSON.new()
		var parse_error := parser.parse(FileAccess.get_file_as_string(root_path.path_join(filename)))
		var value = parser.data if parse_error == OK else null
		if not value is Dictionary:
			last_error = "部分录音信息损坏，已跳过；原始文件保留。"
			continue
		if not value.has_all(["id", "name", "duration", "created_at"]):
			last_error = "部分录音信息不完整，已跳过。"
			continue
		if str(value.id) + ".json" != filename:
			continue
		var state := _game_state()
		if state!=null and not str(state.shared_state.get("journey_id","")).is_empty():
			if str(value.get("role",""))!=state.current_role or str(value.get("journey_id",""))!=str(state.shared_state.journey_id): continue
			if not state.artifacts.get("recorded_sample_ids",[]).has(str(value.id)): continue
		value.file_path = root_path.path_join(filename.get_basename() + ".wav")
		value.missing = not FileAccess.file_exists(value.file_path)
		results.append(value)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.created_at) < str(b.created_at))
	return results

func save_sample(wav: AudioStreamWAV, sample_name: String, context: Dictionary = {}) -> Dictionary:
	context=context.duplicate(true)
	var state := _game_state()
	if state!=null:
		context["role"]=state.current_role
		context["journey_id"]=str(state.shared_state.get("journey_id",""))
	last_error = ""
	if wav == null or wav.data.is_empty():
		last_error = "没有可保存的录音。"
		return {}
	if list_samples().size() >= MAX_SAMPLES:
		last_error = "录音库已满（20 段），请先删除不需要的录音。"
		return {}
	if FileAccess.file_exists(root_path) or FileAccess.file_exists(root_path.get_base_dir()):
		last_error = "保存目录被同名文件占用。"
		return {}
	var error := DirAccess.make_dir_recursive_absolute(root_path)
	if error != OK:
		last_error = "不能创建保存目录：" + error_string(error)
		return {}
	var id := "sample_" + Crypto.new().generate_random_bytes(12).hex_encode()
	var final_path := root_path.path_join(id + ".wav")
	var temporary_path := root_path.path_join(id + ".pending.wav")
	error = wav.save_to_wav(temporary_path)
	if error != OK:
		last_error = "音频保存失败：" + error_string(error)
		return {}
	error = DirAccess.rename_absolute(temporary_path, final_path)
	if error != OK:
		last_error = "无法完成音频保存：" + error_string(error)
		return {}
	var clean_name := sample_name.strip_edges().left(60)
	var metadata := {
		"id": id, "name": clean_name if not clean_name.is_empty() else "未命名的声音",
		"duration": wav.get_length(), "created_at": Time.get_datetime_string_from_system(true),
		"file_path": final_path, "sample_rate": wav.mix_rate, "channels": 2 if wav.stereo else 1,
		"source_mode": str(context.get("source_mode", "unknown")),
		"role": str(context.get("role", "")),
		"journey_id":str(context.get("journey_id","")),
		"game_day": int(context.get("game_day", 0)),
		"game_minute": int(context.get("game_minute", 0)),
		"location": str(context.get("location", "")),
		"nearby_npcs": context.get("nearby_npcs", []).duplicate(),
		"event_tag": str(context.get("event_tag", "")),
		"usage_scope": str(context.get("usage_scope", "local_only")),
		"markers": context.get("markers", []).duplicate(),
		"consent_status": str(context.get("consent_status", "unknown")),
	}
	if not _write_json(root_path.path_join(id + ".json"), metadata):
		DirAccess.remove_absolute(final_path)
		return {}
	if state!=null:
		state.artifacts.get_or_add("recorded_sample_ids",[]).append(id)
		state.commit_active_role_state()
	return metadata

func rename_sample(id: String, new_name: String) -> bool:
	var clean_name := new_name.strip_edges().left(60)
	if clean_name.is_empty():
		last_error = "名称不能为空。"
		return false
	for item in list_samples():
		if item.id == id:
			item.name = clean_name
			item.erase("missing")
			return _write_json(root_path.path_join(id + ".json"), item)
	last_error = "找不到这段录音。"
	return false

func delete_sample(id: String) -> bool:
	if root_path == "user://samples" and _sample_is_used_by_project(id):
		last_error = "这段录音正被声音工程使用，请先移除相关片段并保存工程。"
		return false
	for item in list_samples():
		if item.id != id:
			continue
		# Move to a local trash folder, so deletion can be recovered outside the UI.
		var trash := root_path.path_join("trash")
		if DirAccess.make_dir_recursive_absolute(trash) != OK:
			last_error = "无法创建回收目录。"
			return false
		var source_json := root_path.path_join(id + ".json")
		var trash_json := trash.path_join(id + ".json")
		if DirAccess.rename_absolute(source_json, trash_json) != OK:
			last_error = "无法移除录音信息。"
			return false
		if not item.missing and DirAccess.rename_absolute(item.file_path, trash.path_join(id + ".wav")) != OK:
			DirAccess.rename_absolute(trash_json, source_json)
			last_error = "音频移除失败，录音仍在库中。"
			return false
		return true
	last_error = "找不到这段录音。"
	return false


func _sample_is_used_by_project(sample_id: String) -> bool:
	var state := _game_state()
	if state!=null:
		state.commit_active_role_state()
		for role_state in state.role_states.values():
			for clip in role_state.get("artifacts",{}).get("minigame_drafts",{}).get("sound_sampling",{}).get("clips",[]):
				if str(clip.get("sample_id",""))==sample_id: return true
	var paths: Array[String] = ["user://projects/current.json", "user://projects/a_current.json", "user://projects/b_current.json"]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			# A damaged project is treated conservatively so its source audio is not lost.
			return true
		if parser.data is Dictionary:
			for clip in parser.data.get("clips", []):
				if clip is Dictionary and str(clip.get("sample_id", "")) == sample_id:
					return true
	return false

func _game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") if tree!=null and root_path=="user://samples" else null

func load_audio(item: Dictionary) -> AudioStreamWAV:
	var path := root_path.path_join(str(item.get("id", "")) + ".wav")
	if not FileAccess.file_exists(path):
		last_error = "音频文件已丢失；录音信息仍保留。"
		return null
	var audio := AudioStreamWAV.load_from_file(path)
	if audio == null:
		last_error = "音频文件损坏或格式不支持。"
	return audio

func _write_json(path: String, value: Dictionary) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "存档写入失败：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "存档写入不完整：" + error_string(error)
		return false
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		last_error = "无法完成存档：" + error_string(error)
		return false
	return true
