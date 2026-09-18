extends SceneTree

var failures := 0
var loaded := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_scan("res://scripts")
	_scan("res://extensions")
	if failures == 0:
		print("LOCALIZATION SCRIPT LOADS: PASS scripts=", loaded)
	quit(failures)


func _scan(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures += 1
		push_error("Cannot scan %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			if entry not in [".", "..", "tests"]:
				_scan(path)
		elif entry.ends_with(".gd") and not entry.ends_with("_test.gd"):
			var resource = load(path)
			if resource is Script:
				loaded += 1
			else:
				failures += 1
				push_error("Failed to load %s" % path)
		entry = directory.get_next()
	directory.list_dir_end()
