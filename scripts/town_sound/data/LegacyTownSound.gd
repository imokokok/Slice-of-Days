extends RefCounted
## One-time, copy-only migration from the previously delivered standalone app.
static func migrate() -> bool:
	if FileAccess.file_exists("user://town_sound_migrated.flag"): return true
	var legacy := OS.get_user_data_dir().get_base_dir().path_join("Town Sound")
	if not DirAccess.dir_exists_absolute(legacy): return true
	var success := true
	for folder in ["samples", "projects", "records"]:
		success = copy_tree(legacy.path_join(folder), "user://" + folder) and success
	if success:
		var marker := FileAccess.open("user://town_sound_migrated.flag", FileAccess.WRITE)
		if marker == null: return false
		marker.store_string("Copied existing local recordings, projects and records without overwriting destination files.")
	return success

static func copy_tree(source: String, destination: String) -> bool:
	var directory := DirAccess.open(source)
	if directory == null: return true
	if DirAccess.make_dir_recursive_absolute(destination) != OK: return false
	var success := true
	for file in directory.get_files():
		if file.get_extension().to_lower() not in ["wav", "png", "json"]: continue
		var target := destination.path_join(file)
		if not FileAccess.file_exists(target):
			success = (DirAccess.copy_absolute(source.path_join(file), target) == OK) and success
	for folder in directory.get_directories():
		if folder.begins_with("rec_"):
			success = copy_tree(source.path_join(folder), destination.path_join(folder)) and success
	return success
