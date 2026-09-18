extends SceneTree

const SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/town_day.tscn",
	"res://scenes/town_map.tscn",
	"res://scenes/journal.tscn",
	"res://scenes/tarot_table.tscn",
	"res://scenes/town_sound/Recorder.tscn",
	"res://extensions/elder_board/scenes/main.tscn",
	"res://extensions/hear_you/main.tscn",
	"res://extensions/myriorama_tarot/main.tscn",
	"res://extensions/observatory/scenes/Main.tscn",
]

var failures := 0
var checked_strings := 0
var cjk := RegEx.new()


func _initialize() -> void:
	cjk.compile("[㐀-鿿]")
	call_deferred("run")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Localization coverage test requires -- --isolated-save")
		quit(1)
		return
	var settings = root.get_node("SettingsSystem")
	var original_values: Dictionary = settings.values.duplicate(true)
	settings.values = settings.DEFAULTS.duplicate(true)
	settings.values["language"] = "en"
	settings.apply_settings()

	for scene_path in SCENES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail(scene_path, "scene did not load")
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		_scan_node(scene, scene_path)
		scene.queue_free()
		await process_frame

	settings.values = original_values
	settings.apply_settings()
	if failures == 0:
		print("LOCALIZATION RUNTIME COVERAGE: PASS scenes=%d strings=%d" % [SCENES.size(), checked_strings])
	quit(failures)


func _scan_node(node: Node, scene_path: String) -> void:
	if node is Control:
		_check_value(node.tooltip_text, scene_path, node, "tooltip_text")
	if node is Label or node is RichTextLabel or node is BaseButton:
		_check_value(str(node.text), scene_path, node, "text")
	if node is LineEdit or node is TextEdit:
		_check_value(str(node.placeholder_text), scene_path, node, "placeholder_text")
	if node is OptionButton:
		for index in node.item_count:
			_check_value(node.get_item_text(index), scene_path, node, "item[%d]" % index)
	if node is Window:
		_check_value(node.title, scene_path, node, "title")
	if node is AcceptDialog:
		_check_value(node.dialog_text, scene_path, node, "dialog_text")
		_check_value(node.ok_button_text, scene_path, node, "ok_button_text")
		_check_value(node.cancel_button_text, scene_path, node, "cancel_button_text")
	for child in node.get_children():
		_scan_node(child, scene_path)


func _check_value(value: String, scene_path: String, node: Node, property_name: String) -> void:
	if value.is_empty() or cjk.search(value) == null:
		return
	checked_strings += 1
	var translated := str(TranslationServer.translate(value))
	if cjk.search(translated) != null:
		_fail(scene_path, "%s.%s: %s" % [node.get_path(), property_name, value.replace("\n", "\\n")])


func _fail(scene_path: String, detail: String) -> void:
	failures += 1
	push_error("Untranslated English UI in %s — %s" % [scene_path, detail])
