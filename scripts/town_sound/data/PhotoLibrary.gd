class_name PhotoLibrary
extends RefCounted
var root_path := "user://photos"
var last_error := ""

func list_photos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root_path)
	if directory == null: return result
	for id in directory.get_directories():
		var path := root_path.path_join(id).path_join("photo.json")
		if not FileAccess.file_exists(path): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: continue
		var item: Dictionary = parser.data
		if item.get("photo_id", "") != id: continue
		if not FileAccess.file_exists(root_path.path_join(id).path_join("photo.png")): continue
		result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	return result

func save_photo(image: Image, context: Dictionary) -> Dictionary:
	last_error = ""
	if image == null or image.is_empty():
		last_error = "没有可保存的画面。"
		return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update((str(image.get_width()) + ":" + str(image.get_height()) + ":" + str(image.get_format())).to_utf8_buffer())
	var state = Engine.get_main_loop().root.get_node("GameState")
	var role := str(context.get("role", state.current_role))
	if role.is_empty(): role = str(state.current_role)
	hash.update(role.to_utf8_buffer())
	if not str(context.get("capture_id","" )).is_empty(): hash.update(str(context.capture_id).to_utf8_buffer())
	hash.update(image.get_data())
	var id := "photo_" + hash.finish().hex_encode()
	for item in list_photos():
		if item.photo_id == id: return item
	if list_photos().size() >= 2048:
		last_error = "本地相册已满（2048 张）。底片仍保留在胶卷里。"
		return {}
	var path := root_path.path_join(id)
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		last_error = "无法创建本地相册目录。"
		return {}
	if image.save_png(path.path_join("photo.pending.png")) != OK or DirAccess.rename_absolute(path.path_join("photo.pending.png"), path.path_join("photo.png")) != OK:
		last_error = "照片保存失败，请重试。"
		return {}
	var item := {"photo_id": id, "created_at": Time.get_datetime_string_from_system(true), "location": str(context.get("location", "")),
		"title": str(context.get("title", "小镇的一刻")), "day": int(context.get("day", state.current_day)), "role": role, "game_minute": int(context.get("game_minute", state.current_minute)), "width": image.get_width(), "height": image.get_height()}
	for key in ["capture_id","roll_id","film_type","protagonist","location_id","minute","capture_path","notes","used_in_collage","shown_to_npcs","submitted_to_dossier","library_root"]:
		if context.has(key): item[key]=context[key]
	for key in ["subject_id", "subject_name", "subject_category", "subject_note", "subject_word"]:
		if not str(context.get(key, "")).is_empty():
			item[key] = str(context.get(key, ""))
	var file := FileAccess.open(path.path_join("photo.json.tmp"), FileAccess.WRITE)
	if file == null:
		last_error = "无法保存照片信息。"
		return {}
	file.store_string(JSON.stringify(item, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(path.path_join("photo.json.tmp"), path.path_join("photo.json")) != OK:
		last_error = "照片信息写入失败。"
		return {}
	return item

func update_metadata(id: String, values: Dictionary) -> bool:
	last_error=""
	for item in list_photos():
		if str(item.photo_id)!=id: continue
		item.merge(values,true)
		var path:=root_path.path_join(id).path_join("photo.json")
		var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
		if file==null: last_error="无法写入照片信息，请重试。"; return false
		file.store_string(JSON.stringify(item,"\t"))
		file.flush()
		var result := file.get_error()
		file.close()
		if result!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:
			last_error="照片信息写入失败，请重试。"
			return false
		return true
	last_error="照片不存在或已损坏。"
	return false

func load_photo(id: String) -> Image:
	# Only identifiers returned by the committed album can be opened.
	for item in list_photos():
		if item.photo_id == id:
			return Image.load_from_file(root_path.path_join(id).path_join("photo.png"))
	last_error = "照片不存在或已损坏。"
	return null
