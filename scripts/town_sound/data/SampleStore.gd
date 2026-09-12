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
		value.file_path = root_path.path_join(filename.get_basename() + ".wav")
		value.missing = not FileAccess.file_exists(value.file_path)
		results.append(value)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.created_at) < str(b.created_at))
	return results

func save_sample(wav: AudioStreamWAV, sample_name: String) -> Dictionary:
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
		"file_path": final_path, "sample_rate": wav.mix_rate, "channels": 2 if wav.stereo else 1
	}
	if not _write_json(root_path.path_join(id + ".json"), metadata):
		DirAccess.remove_absolute(final_path)
		return {}
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
	if root_path == "user://samples" and FileAccess.file_exists("user://projects/current.json"):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string("user://projects/current.json")) != OK:
			last_error = "工程无法读取，暂不删除原始录音，以免损坏工程。"
			return false
		if parser.data is Dictionary:
			for clip in parser.data.get("clips", []):
				if clip is Dictionary and clip.get("sample_id", "") == id:
					last_error = "这段录音正被 Studio 使用，请先移除相关片段并保存工程。"
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
