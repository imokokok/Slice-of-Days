extends Node

signal save_failed(message: String)

const SAVE_PATH := "user://solmere_five_day.json"
const LEGACY_SAVE_PATH := "user://vertical_slice_save.json"
const PREVIOUS_PROJECT_DIR := "100game"
const SLOT_COUNT := 3

var active_slot := 1
var last_error := ""


func path_for_slot(slot: int) -> String:
	var safe_slot := clampi(slot, 1, SLOT_COUNT)
	if OS.get_cmdline_user_args().has("--isolated-save"):
		return "user://walking_test_%d.json" % safe_slot
	return SAVE_PATH if safe_slot == 1 else "user://solmere_five_day_%d.json" % safe_slot


func set_active_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, SLOT_COUNT)


func has_slot(slot: int) -> bool:
	return has_save(path_for_slot(slot))


func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_slot(slot):
			return true
	return false


func has_save(path := "") -> bool:
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	if FileAccess.file_exists(target_path):
		return true
	if target_path != SAVE_PATH:
		return false
	for candidate in _legacy_candidates():
		if FileAccess.file_exists(candidate):
			return true
	return false


func save_game(path := "") -> bool:
	last_error = ""
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	var temporary_path := target_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _save_error("无法创建临时存档：%s" % error_string(FileAccess.get_open_error()))
	GameState.shared_state["meta_checkpoint"] = {"version":1,"timestamp":Time.get_unix_time_from_system()}
	var payload := JSON.stringify(GameState.to_save_data(), "\t")
	file.store_string(payload)
	file.flush()
	file = null
	# Never replace a good save with a truncated or otherwise invalid payload.
	var written = JSON.parse_string(FileAccess.get_file_as_string(temporary_path))
	if typeof(written) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return _save_error("无法校验临时存档。")
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var rename_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return _save_error("无法安全替换存档：%s" % error_string(rename_error))
	return true


func save_or_report(context := "") -> bool:
	if save_game():
		return true
	if not str(context).is_empty():
		push_error("%s：%s" % [context, last_error])
	return false


func _save_error(message: String) -> bool:
	last_error = message
	push_error(message)
	save_failed.emit(message)
	return false


func load_game(path := "") -> bool:
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	var source_path: String = target_path
	if target_path == SAVE_PATH and not FileAccess.file_exists(target_path):
		for candidate in _legacy_candidates():
			if FileAccess.file_exists(candidate):
				source_path = candidate
				break
	if not FileAccess.file_exists(source_path):
		return false
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return _save_error("无法读取存档：%s" % error_string(FileAccess.get_open_error()))
	var parsed = JSON.parse_string(file.get_as_text())
	# Release the Windows read handle before ambient updates replace this file.
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if not GameState.compatible_save(parsed):
		return _save_error("此存档属于旧七日流程或数据不完整，不能继续五日旅程。请从主菜单开始新游戏；旧存档会保留。")
	GameState.load_save_data(parsed)
	if EchoSystem.resume_ambient():
		if not save_game(target_path):
			GameState.load_save_data(parsed)
			return false
	if source_path != SAVE_PATH:
		if target_path == SAVE_PATH:
			save_game(SAVE_PATH)
	return true


func load_slot(slot: int) -> bool:
	set_active_slot(slot)
	return load_game()


func slot_summary(slot: int) -> Dictionary:
	var path := path_for_slot(slot)
	if not FileAccess.file_exists(path):
		if slot == 1 and not OS.get_cmdline_user_args().has("--isolated-save"):
			for candidate in _legacy_candidates():
				if FileAccess.file_exists(candidate):
					path = candidate
					break
	if not FileAccess.file_exists(path):
		return {"slot": slot, "exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"slot": slot, "exists": false}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"slot": slot, "exists": false, "invalid": true}
	var current_role := str(parsed.get("current_role", "A"))
	var role_states: Dictionary = parsed.get("role_states", {})
	var active_state: Dictionary = role_states.get(current_role, parsed)
	var a_state: Dictionary = role_states.get("A", {})
	var b_state: Dictionary = role_states.get("B", {})
	return {
		"slot": slot,
		"exists": true,
		"compatible": GameState.compatible_save(parsed),
		"role": current_role,
		"day": int(active_state.get("day", parsed.get("current_day", 1))),
		"minute": int(active_state.get("minute", parsed.get("current_minute", 540))),
		"location": str(active_state.get("location",parsed.get("current_location","bus_stop"))),
		"thumbnail": path+".png" if FileAccess.file_exists(path+".png") else "",
		"a_confirmed": (a_state.get("confirmed_residents", []) as Array).size(),
		"b_confirmed": (b_state.get("confirmed_residents", []) as Array).size(),
		"modified": int(FileAccess.get_modified_time(path)),
	}


func _legacy_candidates() -> Array[String]:
	var current_user_dir := ProjectSettings.globalize_path(SAVE_PATH).get_base_dir()
	var app_userdata_dir := current_user_dir.get_base_dir()
	var previous_dir := app_userdata_dir.path_join(PREVIOUS_PROJECT_DIR)
	return [
		"user://solmere_save.json",
		LEGACY_SAVE_PATH,
		previous_dir.path_join("solmere_save.json"),
		previous_dir.path_join("vertical_slice_save.json"),
	]

func prepare_new_journey() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if not FileAccess.file_exists(path_for_slot(slot)):
			set_active_slot(slot)
			return true
	# All three legacy slots occupied: archive the oldest before reusing it.
	var oldest := 1
	for slot in range(2, SLOT_COUNT + 1):
		if int(slot_summary(slot).get("modified", 0)) < int(slot_summary(oldest).get("modified", 0)):
			oldest = slot
	var source := path_for_slot(oldest)
	var archive := "user://journey_archive_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(archive)) != OK:
		push_error("Could not archive the previous journey")
		return false
	if FileAccess.file_exists(source+".png"):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(source+".png"),ProjectSettings.globalize_path(archive+".png"))!=OK: return false
		DirAccess.remove_absolute(ProjectSettings.globalize_path(source+".png"))
	set_active_slot(oldest)
	return true

func load_latest() -> bool:
	var slots: Array[int] = [1, 2, 3]
	slots.sort_custom(func(a: int, b: int) -> bool:
		return int(slot_summary(a).get("modified", 0)) > int(slot_summary(b).get("modified", 0)))
	for slot in slots:
		if has_slot(slot) and load_slot(slot): return true
	return false

func save_thumbnail(image: Image) -> bool:
	if image==null or image.is_empty(): return false
	var copy := image.duplicate() as Image
	copy.resize(480,270,Image.INTERPOLATE_LANCZOS)
	return copy.save_png(path_for_slot(active_slot)+".png")==OK

func delete_slot(slot: int) -> bool:
	if slot<1 or slot>SLOT_COUNT: return false
	var path := path_for_slot(slot)
	if not FileAccess.file_exists(path): return false
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if result!=OK: return _save_error("无法删除这份存档。")
	if FileAccess.file_exists(path+".png"): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".png"))
	return true
