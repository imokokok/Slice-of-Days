class_name LocalRecordLibrary
extends RecordLibraryBase
var root_path := "user://records"

func list_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root_path)
	if directory == null: return result
	for id in directory.get_directories():
		var path := root_path.path_join(id) + "/record.json"
		if not FileAccess.file_exists(path): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
			var item: Dictionary = parser.data
			if item.has_all(["record_id", "title", "artist", "duration"]):
				item.final_audio_path = root_path.path_join(id) + "/audio.wav"
				item.cover_path = root_path.path_join(id) + "/cover.png"
				result.append(item)
	return result

func save_record(metadata: Dictionary, audio: AudioStreamWAV, cover: Image) -> Dictionary:
	var id := "rec_" + Crypto.new().generate_random_bytes(12).hex_encode()
	var path := root_path.path_join(id)
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		last_error = "不能创建唱片目录。"
		return {}
	if audio.save_to_wav(path + "/audio.wav") != OK or cover.save_png(path + "/cover.png") != OK:
		last_error = "成品文件保存失败。工程仍保留，请重试。"
		return {}
	var record := metadata.duplicate(true)
	record.record_id = id
	record.final_audio_path = path + "/audio.wav"
	record.cover_path = path + "/cover.png"
	record.created_at = Time.get_datetime_string_from_system(true)
	record.visibility = "local"
	record.origin = str(metadata.get("origin", "local"))
	var file := FileAccess.open(path + "/record.json.tmp", FileAccess.WRITE)
	if file == null:
		last_error = "无法保存唱片信息。"
		return {}
	file.store_string(JSON.stringify(record, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + "/record.json.tmp", path + "/record.json") != OK:
		last_error = "唱片信息写入失败，尚未付款。"
		return {}
	return record

func money() -> int:
	# The committed record is the payment ledger: no double-credit on retry/restart.
	var total := 0
	for record in list_records(): total += int(record.get("payment", 0))
	return total
