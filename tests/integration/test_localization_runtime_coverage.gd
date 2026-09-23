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
const DYNAMIC_SURFACES := [
	"res://scripts/residency/map_paper.gd",
	"res://scripts/residency/recorder_lite.gd",
	"res://scripts/ui/coastal_fishing_panel.gd",
	"res://scripts/ui/components/confirm_sheet.gd",
	"res://scripts/ui/components/evening_review.gd",
	"res://scripts/ui/components/receipt_view.gd",
	"res://scripts/ui/fish_journal.gd",
	"res://scripts/ui/recipe_book_panel.gd",
	"res://scripts/ui/shop_panel.gd",
	"res://scripts/ui/transport_panel.gd",
]

var failures := 0
var checked_strings := 0
var cjk := RegEx.new()
var capture_dir := ""


func _initialize() -> void:
	cjk.compile("[㐀-鿿]")
	call_deferred("run")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Localization coverage test requires -- --isolated-save")
		quit(1)
		return
	# UI coverage must not inherit old journals, recordings or world state from
	# whichever manual save happens to exist on the machine running the test.
	root.get_node("ChapterSystem").start_new_game()
	capture_dir = OS.get_environment("LOCALIZATION_CAPTURE_DIR")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var settings = root.get_node("SettingsSystem")
	var original_values: Dictionary = settings.values.duplicate(true)
	settings.values = settings.DEFAULTS.duplicate(true)
	settings.values["language"] = "en"
	# Capture settled layouts instead of sampling the first frame of entrance
	# tweens, which can make otherwise valid text look faded or displaced.
	settings.values["reduced_motion"] = true
	settings.apply_settings()

	for scene_index in SCENES.size():
		var scene_path: String = SCENES[scene_index]
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail(scene_path, "scene did not load")
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		_scan_node(scene, scene_path)
		await _capture("%02d-scene-%s" % [scene_index + 1, scene_path.get_file().get_basename()])
		scene.queue_free()
		await process_frame

	for surface_index in DYNAMIC_SURFACES.size():
		var script_path: String = DYNAMIC_SURFACES[surface_index]
		var script := load(script_path) as Script
		if script == null:
			_fail(script_path, "script did not load")
			continue
		var surface = script.new()
		if script_path.ends_with("receipt_view.gd"):
			surface.receipt = {
				"day": 1, "minute": 650, "kind": "purchase", "help_minutes": 0,
				"total": 15, "balance": 185,
				"line_items": [{"name": "海盐豆罐头", "quantity": 1, "total": 15}],
			}
		elif script_path.ends_with("confirm_sheet.gd"):
			surface.heading = "制作并交付唱片"
			surface.description = "封面与压片交付会用去 60 分钟。\n工程已保留；取消不会结算这段时间。"
			surface.confirm_text = "开始制作"
		root.add_child(surface)
		await process_frame
		await process_frame
		_scan_node(surface, script_path)
		await _capture("%02d-surface-%s" % [surface_index + 1, script_path.get_file().get_basename()])
		surface.queue_free()
		await process_frame

	settings.values = original_values
	settings.apply_settings()
	if failures == 0:
		print("LOCALIZATION RUNTIME COVERAGE: PASS scenes=%d dynamic=%d source_strings_checked=%d" % [SCENES.size(), DYNAMIC_SURFACES.size(), checked_strings])
	quit(failures)


func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(capture_dir.path_join(name + ".png")) != OK:
		_fail(name, "screenshot could not be saved")


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
