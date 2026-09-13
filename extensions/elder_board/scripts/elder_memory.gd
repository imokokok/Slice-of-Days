extends RefCounted
static var directory := "user://elder_memory"
static var role := "A"

static func read() -> Dictionary:
	for suffix in ["/memory.json", "/memory.backup.json"]:
		if not FileAccess.file_exists(directory + suffix): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(directory + suffix))
		if parsed is Dictionary and parsed.get("profiles") is Array and parsed.get("story", 0) is float:
			return parsed
	return {"version": 1, "story": 0, "profiles": [], "draft": {}}

static func write(data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path := directory + "/memory.json"
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, directory + "/memory.backup.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	return file.get_error() == OK

static func save_draft(draft: Dictionary) -> bool:
	var data := read()
	if not data.get("drafts") is Dictionary: data.drafts = {}
	data.drafts[role] = draft
	return write(data)

static func draft() -> Dictionary:
	return read().get("drafts", {}).get(role, {})

static func story_index() -> int:
	return int(read().get("stories", {}).get(role, 0))

static func remember(profile: Dictionary) -> bool:
	var data := read()
	# A new confirmation creates a version, preserving the old rule set.
	data.profiles.append(profile)
	if not data.get("drafts") is Dictionary: data.drafts = {}
	data.drafts[role] = {}
	return write(data)

static func finish_chapter(index: int) -> bool:
	var data := read()
	if not data.get("stories") is Dictionary: data.stories = {}
	data.stories[role] = maxi(int(data.stories.get(role, 0)), index + 1)
	return write(data)
